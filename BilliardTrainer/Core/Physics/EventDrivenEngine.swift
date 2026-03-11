//
//  EventDrivenEngine.swift
//  BilliardTrainer
//
//  Event-driven physics engine implementing P3.1-P3.4
//

import Foundation
import SceneKit

// MARK: - Event Types

/// Type of physics event
enum PhysicsEventType {
    case ballBall(ballA: String, ballB: String)
    case ballCushion(ball: String, cushionIndex: Int, normal: SCNVector3)
    case transition(ball: String, fromState: BallMotionState, toState: BallMotionState)
    case pocket(ball: String, pocketId: String)
}

/// Physics event with time and priority for ordering
struct PhysicsEvent: Comparable {
    let type: PhysicsEventType
    let time: Float
    let priority: Int  // Lower number = higher priority
    // Keep tie epsilon very small. A large epsilon (e.g. 1e-4) causes near-simultaneous
    // events to be treated as equal and reordered by priority, which can let a transition
    // run before an almost-earlier collision and produce post-evolve overlaps.
    private static let tieEpsilon: Float = 1e-7
    
    static func < (lhs: PhysicsEvent, rhs: PhysicsEvent) -> Bool {
        if abs(lhs.time - rhs.time) < tieEpsilon {
            return lhs.priority < rhs.priority
        }
        return lhs.time < rhs.time
    }
    
    static func == (lhs: PhysicsEvent, rhs: PhysicsEvent) -> Bool {
        return abs(lhs.time - rhs.time) < tieEpsilon && lhs.priority == rhs.priority
    }
}

// MARK: - Ball State

/// State of a ball in the event-driven engine
struct BallState {
    var position: SCNVector3
    var velocity: SCNVector3
    var angularVelocity: SCNVector3
    var state: BallMotionState
    let name: String
    
    var isPocketed: Bool {
        return state == .pocketed
    }
    
    var isStationary: Bool {
        return state == .stationary
    }
}

// MARK: - Event Cache

/// Cache for computed events to avoid redundant calculations
/// Key 用整数编码（ballId × 2^N + cushionIdx），避免字符串 split/alloc，减少 invalidate 开销
class EventCache {
    private struct CachedEvent {
        let event: PhysicsEvent
        let timeStamp: Float
    }

    private struct NoCollisionEntry {
        let stamp: Float
        let stateA: BallMotionState
        let stateB: BallMotionState
    }

    // 球名称 → 整数 ID（first-seen 时分配，不变）
    private var ballNameToId: [String: Int32] = [:]
    private var nextBallId: Int32 = 0

    // ball-ball: key = min(idA,idB) << 16 | max(idA,idB)  (各球 id ≤ 31，满足 16bit)
    private var ballBallCache: [Int64: CachedEvent] = [:]
    private var ballBallNoCollisionCache: [Int64: NoCollisionEntry] = [:]

    // ball-cushion: key = ballId << 8 | cushionIndex  (cushionIndex ≤ 25)
    private var ballCushionCache: [Int64: CachedEvent] = [:]
    private var ballCushionNoCollisionCache: [Int64: Float] = [:]

    // transition: key = ballId << 4 | transitionTypeId
    private var transitionCache: [Int64: CachedEvent] = [:]

    private static let transitionTypeIds: [String: Int64] = [
        "slideToRoll": 0,
        "rollToSpin": 1,
        "spinToStationary": 2
    ]

    /// Invalidate cache entries for affected balls
    func invalidate(affectedBalls: Set<String>) {
        let affectedIds: Set<Int32> = Set(affectedBalls.compactMap { ballNameToId[$0] })
        guard !affectedIds.isEmpty else { return }

        ballBallCache = ballBallCache.filter { key, _ in
            let idA = Int32(key >> 16)
            let idB = Int32(key & 0xFFFF)
            return !affectedIds.contains(idA) && !affectedIds.contains(idB)
        }
        ballBallNoCollisionCache = ballBallNoCollisionCache.filter { key, _ in
            let idA = Int32(key >> 16)
            let idB = Int32(key & 0xFFFF)
            return !affectedIds.contains(idA) && !affectedIds.contains(idB)
        }
        ballCushionCache = ballCushionCache.filter { key, _ in
            let ballId = Int32(key >> 8)
            return !affectedIds.contains(ballId)
        }
        ballCushionNoCollisionCache = ballCushionNoCollisionCache.filter { key, _ in
            let ballId = Int32(key >> 8)
            return !affectedIds.contains(ballId)
        }
        transitionCache = transitionCache.filter { key, _ in
            let ballId = Int32(key >> 4)
            return !affectedIds.contains(ballId)
        }
    }

    // MARK: - Ball-Ball

    /// Invalidate both the positive and negative cache entries for a specific ball pair.
    /// Called by separateOverlappingBalls so the next findNextEvent re-solves the quartic
    /// instead of trusting a stale "no collision" entry from before the separation.
    func invalidateBallPair(ballA: String, ballB: String) {
        let key = makeBallBallKey(ballA: ballA, ballB: ballB)
        ballBallCache.removeValue(forKey: key)
        ballBallNoCollisionCache.removeValue(forKey: key)
    }

    func getBallBall(ballA: String, ballB: String, currentTime: Float) -> PhysicsEvent? {
        let key = makeBallBallKey(ballA: ballA, ballB: ballB)
        guard let cached = ballBallCache[key] else { return nil }
        let remaining = cached.event.time - (currentTime - cached.timeStamp)
        if remaining <= 0 { ballBallCache[key] = nil; return nil }
        return PhysicsEvent(type: cached.event.type, time: remaining, priority: cached.event.priority)
    }

    func setBallBall(ballA: String, ballB: String, event: PhysicsEvent, currentTime: Float) {
        let key = makeBallBallKey(ballA: ballA, ballB: ballB)
        ballBallCache[key] = CachedEvent(event: event, timeStamp: currentTime)
        ballBallNoCollisionCache.removeValue(forKey: key)
    }

    /// TTL for no-collision cache entries: re-check pairs after this many simulation seconds.
    /// Only applies when both balls are non-translating (stationary/spinning); active balls
    /// always bypass the no-collision cache (see isBallBallNoCollision).
    static let noCollisionTTL: Float = 0.5

    /// Returns true only when both balls recorded as non-colliding are still in the same
    /// motion state AND the entry is within TTL. Active (sliding/rolling) balls are never
    /// considered cached because their trajectories change rapidly.
    func isBallBallNoCollision(ballA: String, ballB: String,
                               stateA: BallMotionState, stateB: BallMotionState,
                               currentTime: Float) -> Bool {
        guard let entry = ballBallNoCollisionCache[makeBallBallKey(ballA: ballA, ballB: ballB)] else { return false }
        // If either ball is now in a different motion state, the cached result is stale.
        guard entry.stateA == stateA && entry.stateB == stateB else { return false }
        // For non-translating pairs (stationary/spinning) we use a generous TTL because
        // they won't drift. For any pair containing an active ball we skip caching entirely.
        let isStatic = (stateA == .stationary || stateA == .spinning)
                    && (stateB == .stationary || stateB == .spinning)
        if !isStatic { return false }
        return (currentTime - entry.stamp) < EventCache.noCollisionTTL
    }

    func setBallBallNoCollision(ballA: String, ballB: String,
                                stateA: BallMotionState, stateB: BallMotionState,
                                currentTime: Float) {
        let entry = NoCollisionEntry(stamp: currentTime, stateA: stateA, stateB: stateB)
        ballBallNoCollisionCache[makeBallBallKey(ballA: ballA, ballB: ballB)] = entry
    }

    // MARK: - Ball-Cushion

    func getBallCushion(ball: String, cushionIndex: Int, currentTime: Float) -> PhysicsEvent? {
        let key = makeBallCushionKey(ball: ball, cushionIndex: cushionIndex)
        guard let cached = ballCushionCache[key] else { return nil }
        let remaining = cached.event.time - (currentTime - cached.timeStamp)
        if remaining <= 0 { ballCushionCache[key] = nil; return nil }
        return PhysicsEvent(type: cached.event.type, time: remaining, priority: cached.event.priority)
    }

    func setBallCushion(ball: String, cushionIndex: Int, event: PhysicsEvent, currentTime: Float) {
        let key = makeBallCushionKey(ball: ball, cushionIndex: cushionIndex)
        ballCushionCache[key] = CachedEvent(event: event, timeStamp: currentTime)
        ballCushionNoCollisionCache.removeValue(forKey: key)
    }

    func isBallCushionNoCollision(ball: String, cushionIndex: Int) -> Bool {
        return ballCushionNoCollisionCache[makeBallCushionKey(ball: ball, cushionIndex: cushionIndex)] != nil
    }

    func setBallCushionNoCollision(ball: String, cushionIndex: Int, currentTime: Float) {
        ballCushionNoCollisionCache[makeBallCushionKey(ball: ball, cushionIndex: cushionIndex)] = currentTime
    }

    // MARK: - Transition

    func getTransition(ball: String, transitionType: String, currentTime: Float) -> PhysicsEvent? {
        let key = makeTransitionKey(ball: ball, transitionType: transitionType)
        guard let cached = transitionCache[key] else { return nil }
        let remaining = cached.event.time - (currentTime - cached.timeStamp)
        if remaining <= 0 { transitionCache[key] = nil; return nil }
        return PhysicsEvent(type: cached.event.type, time: remaining, priority: cached.event.priority)
    }

    func setTransition(ball: String, transitionType: String, event: PhysicsEvent, currentTime: Float) {
        transitionCache[makeTransitionKey(ball: ball, transitionType: transitionType)] = CachedEvent(event: event, timeStamp: currentTime)
    }

    // MARK: - Lifecycle

    func clear() {
        ballBallCache.removeAll()
        ballBallNoCollisionCache.removeAll()
        ballCushionCache.removeAll()
        ballCushionNoCollisionCache.removeAll()
        transitionCache.removeAll()
    }

    // MARK: - Key Helpers

    @inline(__always)
    private func ballId(_ name: String) -> Int64 {
        if let id = ballNameToId[name] { return Int64(id) }
        let id = nextBallId
        nextBallId += 1
        ballNameToId[name] = id
        return Int64(id)
    }

    @inline(__always)
    private func makeBallBallKey(ballA: String, ballB: String) -> Int64 {
        let a = ballId(ballA), b = ballId(ballB)
        return (min(a, b) << 16) | max(a, b)
    }

    @inline(__always)
    private func makeBallCushionKey(ball: String, cushionIndex: Int) -> Int64 {
        return (ballId(ball) << 8) | Int64(cushionIndex)
    }

    @inline(__always)
    private func makeTransitionKey(ball: String, transitionType: String) -> Int64 {
        let typeId = EventCache.transitionTypeIds[transitionType] ?? Int64(abs(transitionType.hashValue) & 0xF)
        return (ballId(ball) << 4) | typeId
    }
}
// MARK: - Event-Driven Engine

/// Event-driven physics engine for billiard simulation
class EventDrivenEngine {
    // Ball states indexed by name
    private var balls: [String: BallState] = [:]
    
    // Current simulation time
    private(set) var currentTime: Float = 0
    
    // Table geometry bounds
    private let tableBounds: (minX: Float, maxX: Float, minZ: Float, maxZ: Float)
    
    // Event cache
    private let eventCache = EventCache()
    
    // Trajectory recorder
    private let trajectoryRecorder = TrajectoryRecorder()
    
    // Table geometry for collision detection
    private let tableGeometry: TableGeometry
    
    // Resolved events history (for game rules and audio)
    private(set) var resolvedEvents: [PhysicsEventType] = []

    /// 每个 resolvedEvent 对应的绝对模拟时间（与 resolvedEvents 等长，下标一一对应）
    private(set) var resolvedEventTimes: [Float] = []

    /// 首次球-球碰撞的模拟时间（用于相机延迟切换观察视角）
    private(set) var firstBallBallCollisionTime: Float?

    // MARK: - Anomaly diagnostics (reset each simulate() call)
    /// Number of times makeBallBallKiss triggered a position correction (dist < 2R+spacer).
    private var kissCountBallBall: Int = 0
    /// Number of times makeBallBallKiss used the fallback (symmetric push) path.
    private var kissCountBallBallFallback: Int = 0
    /// Maximum ball-ball interpenetration depth observed (m) before make_kiss correction.
    private var maxBallBallPenetration: Float = 0
    /// Number of times makeBallCushionKiss triggered a position correction.
    private var kissCountCushion: Int = 0
    /// Maximum ball-cushion interpenetration depth observed (m) before make_kiss correction.
    private var maxCushionPenetration: Float = 0
    /// Number of times separateOverlappingBalls found at least one overlapping pair.
    private var separateOverlapTriggerCount: Int = 0
    /// Total number of overlapping pairs corrected across all separateOverlappingBalls calls.
    private var separateOverlapPairCount: Int = 0
    /// Maximum overlap depth observed by separateOverlappingBalls (m).
    private var maxSeparateOverlap: Float = 0
    /// Number of times the zero-time-event nudge was applied.
    private var nudgeCount: Int = 0
    
    /// Initialize engine with table geometry
    init(tableGeometry: TableGeometry) {
        self.tableGeometry = tableGeometry
        
        // Calculate table bounds from inner dimensions
        let halfLength = TablePhysics.innerLength / 2
        let halfWidth = TablePhysics.innerWidth / 2
        
        tableBounds = (
            minX: -halfLength,
            maxX: halfLength,
            minZ: -halfWidth,
            maxZ: halfWidth
        )
    }
    
    /// Add or update a ball state
    func setBall(_ ball: BallState) {
        balls[ball.name] = ball
    }
    
    /// Get ball state by name
    func getBall(_ name: String) -> BallState? {
        return balls[name]
    }
    
    /// Get all ball states
    func getAllBalls() -> [BallState] {
        return Array(balls.values)
    }
    
    /// Run simulation until maxEvents or maxTime is reached
    func simulate(maxEvents: Int = 1000, maxTime: Float = 10.0) {
        // Reset per-shot anomaly counters.
        kissCountBallBall = 0
        kissCountBallBallFallback = 0
        maxBallBallPenetration = 0
        kissCountCushion = 0
        maxCushionPenetration = 0
        separateOverlapTriggerCount = 0
        separateOverlapPairCount = 0
        maxSeparateOverlap = 0
        nudgeCount = 0

        PerformanceProfiler.begin(ProfilerLabel.simulate)
        defer {
            let ms = PerformanceProfiler.end(ProfilerLabel.simulate)
            let eventCount0 = resolvedEvents.count
            var bbCount = 0, bcCount = 0, trCount = 0, pkCount = 0
            var zeroTimeCount = 0
            for (evt, t) in zip(resolvedEvents, resolvedEventTimes) {
                switch evt {
                case .ballBall: bbCount += 1
                case .ballCushion: bcCount += 1
                case .transition: trCount += 1
                case .pocket: pkCount += 1
                }
                if t < 0.001 { zeroTimeCount += 1 }
            }
            print("[Perf] simulate() 完成 — 耗时: \(String(format: "%.2f", ms))ms, 总事件: \(eventCount0), 模拟时长: \(String(format: "%.3f", currentTime))s")
            print("[Perf]   球-球: \(bbCount), 球-库: \(bcCount), 状态转换: \(trCount), 进袋: \(pkCount), 零时刻事件: \(zeroTimeCount)")

            // Anomaly summary — always printed so every shot is traceable.
            print("[PhysicsAnomaly] === 本次击球异常统计 ===")
            print("[PhysicsAnomaly] ball-ball make_kiss 触发: \(kissCountBallBall) 次（其中 fallback: \(kissCountBallBallFallback)），最大穿透深度: \(String(format: "%.4f", maxBallBallPenetration * 1000)) mm")
            print("[PhysicsAnomaly] ball-cushion make_kiss 触发: \(kissCountCushion) 次，最大穿透深度: \(String(format: "%.4f", maxCushionPenetration * 1000)) mm")
            print("[PhysicsAnomaly] separateOverlappingBalls 触发: \(separateOverlapTriggerCount) 次，修正球对数: \(separateOverlapPairCount)，最大重叠: \(String(format: "%.4f", maxSeparateOverlap * 1000)) mm")
            print("[PhysicsAnomaly] 零时刻 nudge 触发: \(nudgeCount) 次")
            let hasAnomaly = kissCountBallBall > 0 || kissCountCushion > 0 || separateOverlapTriggerCount > 0 || nudgeCount > 0
            if hasAnomaly {
                print("[PhysicsAnomaly] ⚠️  本次击球存在数值异常，请结合上方详细日志排查")
            } else {
                print("[PhysicsAnomaly] ✓  本次击球无数值异常")
            }
        }

        // Diagnose initial ball positions for overlaps before any separation.
        // Overlap at t=0 means the ball layout passed to the engine already has interpenetrations
        // (e.g. from node.position vs visualCenter mismatch, or insufficient sanitizeBallLayout).
        var initialMaxOverlap: Float = 0
        var initialOverlapCount = 0
        let initNames = Array(balls.keys)
        let twoRInit = 2 * BallPhysics.radius
        for i in 0..<initNames.count {
            for j in (i+1)..<initNames.count {
                guard let a = balls[initNames[i]], let b = balls[initNames[j]] else { continue }
                guard !a.isPocketed && !b.isPocketed else { continue }
                let dx = b.position.x - a.position.x
                let dz = b.position.z - a.position.z
                let d2 = dx*dx + dz*dz
                if d2 < twoRInit * twoRInit {
                    let dist = sqrtf(max(d2, 1e-12))
                    let ov = twoRInit - dist
                    if ov > initialMaxOverlap { initialMaxOverlap = ov }
                    initialOverlapCount += 1
                    if ov > 0.1 {
                        print("[PhysicsAnomaly] initialOverlap: \(initNames[i])↔\(initNames[j]) overlap=\(String(format:"%.3f",ov*1000))mm dist=\(String(format:"%.3f",dist*1000))mm")
                    }
                }
            }
        }
        if initialOverlapCount > 0 {
            print("[PhysicsAnomaly] ⚠️ 初始球位存在 \(initialOverlapCount) 对重叠，最大 \(String(format:"%.3f",initialMaxOverlap*1000))mm，请检查 sanitizeBallLayout 或 visualCenter 传入逻辑")
        }

        // Run a more thorough initial separation before the first event search.
        // A single pass of 6 iterations is not enough for a densely packed rack where
        // ball positions may carry up to ~16 mm of initial overlap. 50 iterations with
        // a convergence check handles even the worst-case rack layouts.
        separateOverlappingBalls(maxIterations: 50)
        recordSnapshot()
        var eventCount = 0
        var zeroTimeEventStreak = 0
        
        while eventCount < maxEvents && currentTime < maxTime {
            // Find next event
            PerformanceProfiler.begin(ProfilerLabel.findNextEvent)
            let nextEvent = findNextEvent(maxTimeRemaining: maxTime - currentTime)
            PerformanceProfiler.end(ProfilerLabel.findNextEvent)

            guard let nextEvent else {
                // No more events, advance to maxTime
                let dt = maxTime - currentTime
                evolveAllBalls(dt: dt)
                recordSnapshot()
                currentTime = maxTime
                break
            }
            
            // Advance all balls to event time (relative time)
            let dt = nextEvent.time
            guard dt > 0 else {
                // Event at current time or in past, resolve immediately
                zeroTimeEventStreak += 1
                resolveEvent(nextEvent)
                invalidateCache(for: nextEvent)
                recordSnapshot()
                eventCount += 1
                
                // 保护：避免连续零时刻事件导致主线程长时间卡死
                if zeroTimeEventStreak > 80 {
                    let nudge = min(0.0005, maxTime - currentTime)
                    if nudge > 0 {
                        evolveAllBalls(dt: nudge)
                        separateOverlappingBalls()
                        currentTime += nudge
                        recordSnapshot()
                    }
                    nudgeCount += 1
                    print("[PhysicsAnomaly] 零时刻 nudge #\(nudgeCount): t=\(String(format: "%.4f", currentTime))s, event=\(nextEvent.type), streak=81+")
                    zeroTimeEventStreak = 0
                }
                continue
            }
            zeroTimeEventStreak = 0
            
            PerformanceProfiler.begin(ProfilerLabel.evolveAllBalls)
            evolveAllBalls(dt: dt)
            PerformanceProfiler.end(ProfilerLabel.evolveAllBalls)

            // Diagnostic: scan for overlapping pairs BEFORE separateOverlappingBalls to
            // detect which ball pairs the quartic solver missed. Log their states so we
            // can identify which cull tier (spatial / kinematic / tier3 / cache) blocked
            // the quartic solve.
            debugLogPostEvolveOverlaps(afterEvent: nextEvent)

            separateOverlappingBalls()
            currentTime += dt
            
            // Resolve event
            PerformanceProfiler.begin(ProfilerLabel.resolveEvent)
            resolveEvent(nextEvent)
            PerformanceProfiler.end(ProfilerLabel.resolveEvent)
            
            // Invalidate cache for affected balls
            invalidateCache(for: nextEvent)
            
            // Record snapshot
            recordSnapshot()
            
            eventCount += 1
            
            // 提前终止检查（Ref: pooltool event.time == np.inf → done）：
            // 每 8 步检查一次是否所有活动球已 stationary，以避免不必要的碰撞扫描。
            // 这是最主要的加速手段：开球后若球已全部静止，无需继续跑满 15s。
            if eventCount % 8 == 0 {
                let allAtRest = balls.values.allSatisfy { b in
                    b.isPocketed || b.state == .stationary
                }
                if allAtRest {
                    break
                }
            }
        }
    }
    
    /// Get trajectory recorder
    func getTrajectoryRecorder() -> TrajectoryRecorder {
        return trajectoryRecorder
    }
    
    // MARK: - Private Methods
    
    /// Find the next event to occur
    private func findNextEvent(maxTimeRemaining: Float) -> PhysicsEvent? {
        var candidates: [PhysicsEvent] = []
        
        // Align with pooltool: event detection always uses the remaining simulation horizon.
        // Do not shrink the search window heuristically; aggressive truncation can miss valid
        // later collisions and lead to overlap/penetration artifacts.
        let detectionMaxTime = maxTimeRemaining
        
        // Find next transition events
        for (name, ball) in balls {
            guard !ball.isPocketed else { continue }
            
            // Check slide-to-roll transition
            if ball.state == .sliding {
                let transitionType = "slideToRoll"
                if let cached = eventCache.getTransition(ball: name, transitionType: transitionType, currentTime: currentTime) {
                    if cached.time > 0 && cached.time <= detectionMaxTime {
                        candidates.append(cached)
                    }
                } else {
                    let transitionTime = AnalyticalMotion.slideToRollTime(
                        velocity: ball.velocity,
                        angularVelocity: ball.angularVelocity
                    )
                    if transitionTime > 0 && transitionTime <= detectionMaxTime {
                        let event = PhysicsEvent(
                            type: .transition(ball: name, fromState: .sliding, toState: .rolling),
                            time: transitionTime,
                            priority: 2
                        )
                        eventCache.setTransition(ball: name, transitionType: transitionType, event: event, currentTime: currentTime)
                        candidates.append(event)
                    }
                }
            }
            
            // Check roll-to-spin transition
            if ball.state == .rolling {
                let transitionType = "rollToSpin"
                if let cached = eventCache.getTransition(ball: name, transitionType: transitionType, currentTime: currentTime) {
                    if cached.time > 0 && cached.time <= detectionMaxTime {
                        candidates.append(cached)
                    }
                } else {
                    let transitionTime = AnalyticalMotion.rollToSpinTime(velocity: ball.velocity)
                    if transitionTime > 0 && transitionTime <= detectionMaxTime {
                        let event = PhysicsEvent(
                            type: .transition(ball: name, fromState: .rolling, toState: .spinning),
                            time: transitionTime,
                            priority: 2
                        )
                        eventCache.setTransition(ball: name, transitionType: transitionType, event: event, currentTime: currentTime)
                        candidates.append(event)
                    }
                }
            }
            
            // Check spin-to-stationary transition
            if ball.state == .spinning {
                let transitionType = "spinToStationary"
                if let cached = eventCache.getTransition(ball: name, transitionType: transitionType, currentTime: currentTime) {
                    if cached.time > 0 && cached.time <= detectionMaxTime {
                        candidates.append(cached)
                    }
                } else {
                    let transitionTime = AnalyticalMotion.spinToStationaryTime(angularVelocity: ball.angularVelocity)
                    if transitionTime > 0 && transitionTime <= detectionMaxTime {
                        let event = PhysicsEvent(
                            type: .transition(ball: name, fromState: .spinning, toState: .stationary),
                            time: transitionTime,
                            priority: 2
                        )
                        eventCache.setTransition(ball: name, transitionType: transitionType, event: event, currentTime: currentTime)
                        candidates.append(event)
                    }
                }
            }
        }
        
        // Find ball-ball collisions
        PerformanceProfiler.begin(ProfilerLabel.ballBallDetect)
        let ballNames = Array(balls.keys)
        for i in 0..<ballNames.count {
            for j in (i+1)..<ballNames.count {
                let nameA = ballNames[i]
                let nameB = ballNames[j]
                
                guard let ballA = balls[nameA], let ballB = balls[nameB] else { continue }
                guard !ballA.isPocketed && !ballB.isPocketed else { continue }
                
                // 已接触/重叠时立即触发一次碰撞，避免“穿透后只带走一点”
                if isBallPairOverlappingOrTouching(ballA, ballB) {
                    let immediate = PhysicsEvent(
                        type: .ballBall(ballA: nameA, ballB: nameB),
                        time: 0,
                        priority: -1
                    )
                    candidates.append(immediate)
                    continue
                }
                
                // 运动学剪裁（Ref: pooltool solve.py skip_ball_ball_collision）：
                // 两球均不平动（stationary/spinning）时不产生碰撞，与 pooltool nontranslating 判断一致。
                // 注意：此处不做空间距离裁剪和方向裁剪——这类裁剪曾导致合法碰撞漏检，
                // 改由四次方程求解器（maxTime 截断）处理无效球对，保证正确性。
                let aIsNontranslating = ballA.state == .stationary || ballA.state == .spinning
                let bIsNontranslating = ballB.state == .stationary || ballB.state == .spinning
                if aIsNontranslating && bIsNontranslating {
                    continue
                }

                // Negative cache check（Ref: pooltool cache[pair] = np.inf）：
                // 已确认此球对在当前运动状态下不会碰撞，直接跳过
                if eventCache.isBallBallNoCollision(ballA: nameA, ballB: nameB,
                                                    stateA: ballA.state, stateB: ballB.state,
                                                    currentTime: currentTime) {
                    continue
                }
                
                // Check cache first
                if let cached = eventCache.getBallBall(ballA: nameA, ballB: nameB, currentTime: currentTime) {
                    if cached.time > 0 && cached.time <= detectionMaxTime {
                        candidates.append(cached)
                    }
                    continue
                }
                
                // Compute acceleration for each ball based on state
                let aA = acceleration(for: ballA)
                let aB = acceleration(for: ballB)
                
                // Find collision time
                if let collisionTime = CollisionDetector.ballBallCollisionTime(
                    p1: ballA.position,
                    p2: ballB.position,
                    v1: ballA.velocity,
                    v2: ballB.velocity,
                    a1: aA,
                    a2: aB,
                    R: Double(BallPhysics.radius),
                    maxTime: Double(detectionMaxTime)
                ) {
                    let event = PhysicsEvent(
                        type: .ballBall(ballA: nameA, ballB: nameB),
                        time: collisionTime,
                        priority: 3
                    )
                    eventCache.setBallBall(ballA: nameA, ballB: nameB, event: event, currentTime: currentTime)
                    candidates.append(event)
                } else if shouldRunFallbackBallBallCheck(
                    ballA: ballA,
                    ballB: ballB,
                    aA: aA,
                    aB: aB,
                    maxTime: detectionMaxTime
                ), let fallbackTime = fallbackBallBallCollisionTime(
                    ballA: ballA,
                    ballB: ballB,
                    aA: aA,
                    aB: aB,
                    maxTime: detectionMaxTime
                ) {
                    // Quartic missed but discrete fallback found collision.
                    let dist = (ballB.position - ballA.position).length()
                    print("[PhysicsAnomaly] quarticMiss+fallbackHit: \(nameA)↔\(nameB) t=\(String(format:"%.4f",currentTime))s fallbackT=\(String(format:"%.4f",fallbackTime))s dist=\(String(format:"%.4f",dist*1000))mm stA=\(ballA.state) stB=\(ballB.state) vA=\(String(format:"%.3f",ballA.velocity.length())) vB=\(String(format:"%.3f",ballB.velocity.length()))")
                    let event = PhysicsEvent(
                        type: .ballBall(ballA: nameA, ballB: nameB),
                        time: fallbackTime,
                        priority: 3
                    )
                    eventCache.setBallBall(ballA: nameA, ballB: nameB, event: event, currentTime: currentTime)
                    candidates.append(event)
                } else {
                    // 四次方程和 fallback 均未找到碰撞 → 写入 negative cache（Ref: pooltool np.inf 标记）
                    // 下次同一球对直接跳过，无需重新计算（仅对静止/自旋球对有效，见 isBallBallNoCollision）
                    eventCache.setBallBallNoCollision(ballA: nameA, ballB: nameB,
                                                     stateA: ballA.state, stateB: ballB.state,
                                                     currentTime: currentTime)
                }
            }
        }
        PerformanceProfiler.end(ProfilerLabel.ballBallDetect)
        
        // Find ball-cushion collisions
        PerformanceProfiler.begin(ProfilerLabel.cushionDetect)
        for (name, ball) in balls {
            guard !ball.isPocketed else { continue }
            
            let a = acceleration(for: ball)
            
            // Check linear cushions
            for (index, cushion) in tableGeometry.linearCushions.enumerated() {
                // Negative cache check：已知此球-直线库组合不会碰撞，直接跳过
                // Check cache first
                if let cached = eventCache.getBallCushion(ball: name, cushionIndex: index, currentTime: currentTime) {
                    if cached.time > 0 && cached.time <= detectionMaxTime {
                        candidates.append(cached)
                    }
                    continue
                }
                
                // Compute line offset (distance from origin along normal)
                let lineOffset = Double(cushion.normal.dot(cushion.start))
                
                if let collisionTime = CollisionDetector.ballLinearCushionTime(
                    p: ball.position,
                    v: ball.velocity,
                    a: a,
                    lineNormal: cushion.normal,
                    lineOffset: lineOffset,
                    R: Double(BallPhysics.radius),
                    maxTime: Double(detectionMaxTime)
                ) {
                    // Convert infinite-line hit into finite-segment hit.
                    let collisionPos = ball.position
                        + ball.velocity * collisionTime
                        + a * (0.5 * collisionTime * collisionTime)
                    
                    if isWithinLinearCushionSegment(point: collisionPos, segment: cushion) {
                        let event = PhysicsEvent(
                            type: .ballCushion(ball: name, cushionIndex: index, normal: cushion.normal),
                            time: collisionTime,
                            priority: 3
                        )
                        eventCache.setBallCushion(ball: name, cushionIndex: index, event: event, currentTime: currentTime)
                        candidates.append(event)
                    }
                }
            }
        }
        
        // Find ball-circular-cushion collisions (pocket jaw arcs)
        let linearCount = tableGeometry.linearCushions.count
        for (name, ball) in balls {
            guard !ball.isPocketed else { continue }
            
            let a = acceleration(for: ball)
            
            for (arcIdx, arc) in tableGeometry.circularCushions.enumerated() {
                let cushionIndex = linearCount + arcIdx
                
                if let cached = eventCache.getBallCushion(ball: name, cushionIndex: cushionIndex, currentTime: currentTime) {
                    if cached.time > 0 && cached.time <= detectionMaxTime {
                        candidates.append(cached)
                    }
                    continue
                }
                
                if let collisionTime = CollisionDetector.ballCircularCushionTime(
                    p: ball.position,
                    v: ball.velocity,
                    a: a,
                    arc: arc,
                    R: BallPhysics.radius,
                    maxTime: Double(detectionMaxTime),
                    pockets: tableGeometry.pockets
                ) {
                    let t = collisionTime
                    let posAtT = ball.position + ball.velocity * t + a * (0.5 * t * t)
                    let normal = arc.normal(at: posAtT)
                    
                    let event = PhysicsEvent(
                        type: .ballCushion(ball: name, cushionIndex: cushionIndex, normal: normal),
                        time: collisionTime,
                        priority: 3
                    )
                    eventCache.setBallCushion(ball: name, cushionIndex: cushionIndex, event: event, currentTime: currentTime)
                    candidates.append(event)
                }
            }
        }
        
        // Find ball-pocket events (CCD quartic solve, XZ-plane only)
        // 注意：必须使用 XZ 2D 分量，不含 Y。
        // 原因：球心 Y 固定高于台面 BallPhysics.radius，而 r = pocket.radius - BallPhysics.radius < BallPhysics.radius，
        // 若使用 3D 向量，dp.y 恒大于 r，四次方程永远无实数根，进袋事件永远不触发。
        for (name, ball) in balls {
            guard !ball.isPocketed else { continue }
            
            let a = acceleration(for: ball)
            
            // Check each pocket
            for pocket in tableGeometry.pockets {
                let r = max(pocket.radius - BallPhysics.radius, 0.0)

                // XZ-only: 袋口检测在水平面进行，忽略 Y 轴高度差
                let dpX = ball.position.x - pocket.center.x
                let dpZ = ball.position.z - pocket.center.z
                let dvX = ball.velocity.x
                let dvZ = ball.velocity.z
                let daX = a.x
                let daZ = a.z

                let halfDaX = daX * 0.5
                let halfDaZ = daZ * 0.5

                let halfDaDotHalfDa = Double(halfDaX * halfDaX + halfDaZ * halfDaZ)
                let dvDotHalfDa    = Double(dvX * halfDaX + dvZ * halfDaZ)
                let dvDotDv        = Double(dvX * dvX + dvZ * dvZ)
                let dpDotHalfDa    = Double(dpX * halfDaX + dpZ * halfDaZ)
                let dpDotDv        = Double(dpX * dvX + dpZ * dvZ)
                let dpDotDp        = Double(dpX * dpX + dpZ * dpZ)

                let a4 = halfDaDotHalfDa
                let a3 = 2.0 * dvDotHalfDa
                let a2 = dvDotDv + 2.0 * dpDotHalfDa
                let a1 = 2.0 * dpDotDv
                let a0 = dpDotDp - Double(r * r)

                let roots = QuarticSolver.solveQuartic(a: a4, b: a3, c: a2, d: a1, e: a0)
                if let time = smallestPositiveRoot(roots, maxTime: detectionMaxTime) {
                    candidates.append(PhysicsEvent(
                        type: .pocket(ball: name, pocketId: pocket.id),
                        time: time,
                        priority: 2
                    ))
                }
            }
        }
        PerformanceProfiler.end(ProfilerLabel.cushionDetect)
        
        // Return earliest event
        return candidates.min()
    }
    
    /// Compute acceleration for a ball based on its state
    private func acceleration(for ball: BallState) -> SCNVector3 {
        switch ball.state {
        case .sliding:
            // Sliding friction acts in the direction of surface velocity, not linear velocity
            let relVel = AnalyticalMotion.surfaceVelocity(
                linear: ball.velocity,
                angular: ball.angularVelocity,
                radius: BallPhysics.radius
            )
            let relSpeed = relVel.length()
            guard relSpeed > 0.001 else { return SCNVector3Zero }
            let uHat = relVel.normalized()
            let decel = SpinPhysics.slidingFriction * TablePhysics.gravity
            return -uHat * decel
        case .rolling:
            let speed = ball.velocity.length()
            guard speed > 0.001 else { return SCNVector3Zero }
            let vHat = ball.velocity.normalized()
            let decel = SpinPhysics.rollingFriction * TablePhysics.gravity
            return -vHat * decel
        case .spinning, .stationary, .pocketed:
            return SCNVector3Zero
        }
    }
    
    /// Evolve all balls forward by dt
    private func evolveAllBalls(dt: Float) {
        for (name, ball) in balls {
            guard !ball.isPocketed else { continue }
            
            let evolved: (position: SCNVector3, velocity: SCNVector3, angularVelocity: SCNVector3)
            
            switch ball.state {
            case .sliding:
                evolved = AnalyticalMotion.evolveSliding(
                    position: ball.position,
                    velocity: ball.velocity,
                    angularVelocity: ball.angularVelocity,
                    dt: dt
                )
            case .rolling:
                evolved = AnalyticalMotion.evolveRolling(
                    position: ball.position,
                    velocity: ball.velocity,
                    angularVelocity: ball.angularVelocity,
                    dt: dt
                )
            case .spinning:
                let result = AnalyticalMotion.evolveSpinning(
                    position: ball.position,
                    angularVelocity: ball.angularVelocity,
                    dt: dt
                )
                evolved = (result.position, ball.velocity, result.angularVelocity)
            case .stationary, .pocketed:
                // No evolution
                continue
            }
            
            var nextState = BallState(
                position: evolved.position,
                velocity: evolved.velocity,
                angularVelocity: evolved.angularVelocity,
                state: ball.state,
                name: ball.name
            )

            enforceTableBounds(for: &nextState)
            balls[name] = nextState
        }
    }

    /// Diagnostic: after evolveAllBalls, scan all ball pairs for overlap and log which
    /// cull tier would have skipped their quartic solve in the *previous* findNextEvent call.
    /// This pinpoints why the collision was not detected before the balls interpenetrated.
    private func debugLogPostEvolveOverlaps(afterEvent: PhysicsEvent) {
        let names = Array(balls.keys)
        let minDist = 2 * BallPhysics.radius
        for i in 0..<names.count {
            for j in (i+1)..<names.count {
                guard let a = balls[names[i]], let b = balls[names[j]] else { continue }
                guard !a.isPocketed && !b.isPocketed else { continue }
                let delta = b.position - a.position
                // Use XZ-plane distance to match separateOverlappingBalls logic.
                // Balls on the table surface have the same Y; using 3D distance can mask
                // real XZ penetrations when Y differs slightly between nodes.
                let d2 = delta.x * delta.x + delta.z * delta.z
                guard d2 < minDist * minDist else { continue }
                let dist = sqrtf(max(d2, 1e-12))
                let penetration = minDist - dist
                // Only log cases where penetration is significant (> 0.01 mm)
                guard penetration > 0.00001 else { continue }

                // Diagnose which cull tier would have rejected this pair.
                // NOTE: when penetrating, dist < minDist, so we use dist as dpLen.
                var cullReason = "unknown"

                let aIsNontranslating = a.state == .stationary || a.state == .spinning
                let bIsNontranslating = b.state == .stationary || b.state == .spinning

                if aIsNontranslating && bIsNontranslating {
                    cullReason = "kinematic(both-nontranslating)"
                } else {
                    // At the time of the previous findNextEvent, the balls were farther apart.
                    // We can only check velocity-based culls at current state.
                    let relVec = b.velocity - a.velocity
                    let relSpeed = relVec.length()
                    let maxAccel: Float = SpinPhysics.slidingFriction * TablePhysics.gravity * 2
                    let stopTime = maxAccel > 0 ? relSpeed / maxAccel : 0
                    let cullHorizon = min(stopTime * 1.5 + 0.05, 1.0)
                    let maxReach = relSpeed * cullHorizon + 0.5 * maxAccel * cullHorizon * cullHorizon

                    if a.state == .rolling && b.state == .rolling && dist > 1e-6 {
                        let n = delta * (1.0 / dist)
                        let relV = b.velocity - a.velocity
                        if relV.dot(n) >= 0 {
                            let aA = acceleration(for: a)
                            let aB = acceleration(for: b)
                            let relA = aB - aA
                            let relADotN = relA.x * n.x + relA.y * n.y + relA.z * n.z
                            if relADotN >= 0 {
                                cullReason = "tier3(rolling-rolling-diverging relV.n=\(String(format:"%.3f",relV.dot(n))) relA.n=\(String(format:"%.3f",relADotN)))"
                            } else {
                                cullReason = "tier3-passed(relA.n<0)-but-quartic-missed(vA=\(String(format:"%.2f",a.velocity.length())) vB=\(String(format:"%.2f",b.velocity.length())))"
                            }
                        } else {
                            cullReason = "all-culls-passed-quartic-missed(vA=\(String(format:"%.2f",a.velocity.length())) vB=\(String(format:"%.2f",b.velocity.length())) stA=\(a.state) stB=\(b.state))"
                        }
                    } else if maxReach < 0.001 {
                        cullReason = "spatial(maxReach=\(String(format:"%.3f",maxReach))m relSpeed=\(String(format:"%.2f",relSpeed)))"
                    } else {
                        cullReason = "unknown-missed(vA=\(String(format:"%.2f",a.velocity.length())) vB=\(String(format:"%.2f",b.velocity.length())) stA=\(a.state) stB=\(b.state) relSpeed=\(String(format:"%.2f",relSpeed)))"
                    }
                }

                let penMM = String(format: "%.4f", penetration * 1000)
                print("[PhysicsAnomaly] postEvolveOverlap: \(names[i])↔\(names[j]) penetration=\(penMM)mm afterEvent=\(afterEvent.type) cullWouldBe=\(cullReason) t=\(String(format:"%.4f",currentTime))s")
            }
        }
    }

    /// 修正重叠球，减少"穿插后无碰撞"的数值死区
    private func separateOverlappingBalls(maxIterations: Int = 6) {
        let names = Array(balls.keys)
        guard names.count >= 2 else { return }
        let twoR = 2 * BallPhysics.radius
        // Trigger only when balls genuinely penetrate (d < 2R).
        // Use (2R)² as the detection threshold to avoid treating make_kiss clearance as overlap.
        let triggerDistSq = twoR * twoR
        // Push to 2R + spacer so after separation d > 2R, preventing Float32 boundary oscillation
        // where d² = (2R)² - epsilon triggers another iteration.
        let spacer: Float = 3e-5   // 0.03 mm clearance beyond 2R
        let targetDist = twoR + spacer

        var foundAnyOverlapThisCall = false

        for _ in 0..<maxIterations {
            var adjusted = false
            
            for i in 0..<(names.count - 1) {
                for j in (i + 1)..<names.count {
                    let aName = names[i]
                    let bName = names[j]
                    guard var a = balls[aName], var b = balls[bName] else { continue }
                    if a.isPocketed || b.isPocketed { continue }
                    
                    let delta = b.position - a.position
                    let d2 = delta.x * delta.x + delta.z * delta.z
                    // Only act on genuine penetration (d < 2R), not on spacer clearance.
                    if d2 >= triggerDistSq { continue }
                    
                    let dist = sqrtf(max(d2, 1e-12))
                    let nx: Float
                    let nz: Float
                    if dist < 1e-6 {
                        nx = 1
                        nz = 0
                    } else {
                        nx = delta.x / dist
                        nz = delta.z / dist
                    }
                    // Compute push needed to reach targetDist (2R + spacer).
                    let push = (targetDist - max(dist, 1e-6)) * 0.5
                    let realOverlap = twoR - max(dist, 1e-6)

                    // Diagnostic counters.
                    separateOverlapPairCount += 1
                    if realOverlap > maxSeparateOverlap { maxSeparateOverlap = realOverlap }
                    if !foundAnyOverlapThisCall {
                        foundAnyOverlapThisCall = true
                        separateOverlapTriggerCount += 1
                    }
                    let overlapMM = String(format: "%.4f", realOverlap * 1000)
                    let distMM = String(format: "%.4f", dist * 1000)
                    let tSec = String(format: "%.4f", currentTime)
                    print("[PhysicsAnomaly] separateOverlap: \(aName)↔\(bName) overlap=\(overlapMM)mm dist=\(distMM)mm t=\(tSec)s")

                    let move = SCNVector3(nx * push, 0, nz * push)
                    
                    a.position = a.position - move
                    b.position = b.position + move
                    // Do NOT call enforceTableBounds here: it can pull a ball back into
                    // overlap range, causing the loop to never converge.
                    
                    balls[aName] = a
                    balls[bName] = b
                    // Invalidate cache for this pair so the next findNextEvent re-solves
                    // their quartic rather than using a stale no-collision or positive entry.
                    eventCache.invalidateBallPair(ballA: aName, ballB: bName)
                    adjusted = true
                }
            }
            
            if !adjusted { break }
        }
    }

    /// 兜底边界约束：防止极端数值误差导致球“跑出台外”
    private func enforceTableBounds(for state: inout BallState) {
        guard !state.isPocketed else { return }
        
        let safeMinX = tableBounds.minX + BallPhysics.radius
        let safeMaxX = tableBounds.maxX - BallPhysics.radius
        let safeMinZ = tableBounds.minZ + BallPhysics.radius
        let safeMaxZ = tableBounds.maxZ - BallPhysics.radius
        
        let outX = state.position.x < safeMinX || state.position.x > safeMaxX
        let outZ = state.position.z < safeMinZ || state.position.z > safeMaxZ
        guard outX || outZ else { return }
        
        // If ball is near a pocket opening, let event-driven CCD handle it
        for pocket in tableGeometry.pockets {
            let dx = state.position.x - pocket.center.x
            let dz = state.position.z - pocket.center.z
            let dist = sqrtf(dx * dx + dz * dz)
            if dist < pocket.radius + BallPhysics.radius * 3 {
                // Close to pocket — only pocket if ball is really deep inside
                if dist <= pocket.radius {
                    state.state = .pocketed
                    state.velocity = SCNVector3Zero
                    state.angularVelocity = SCNVector3Zero
                }
                return
            }
        }
        
        // Not near any pocket — hard clamp (numerical safety net)
        let restitution: Float = 0.5
        
        if state.position.x < safeMinX {
            state.position.x = safeMinX
            state.velocity.x = abs(state.velocity.x) * restitution
        } else if state.position.x > safeMaxX {
            state.position.x = safeMaxX
            state.velocity.x = -abs(state.velocity.x) * restitution
        }
        
        if state.position.z < safeMinZ {
            state.position.z = safeMinZ
            state.velocity.z = abs(state.velocity.z) * restitution
        } else if state.position.z > safeMaxZ {
            state.position.z = safeMaxZ
            state.velocity.z = -abs(state.velocity.z) * restitution
        }
        
        state.state = determineMotionState(state)
    }
    
    /// Resolve a physics event
    private func resolveEvent(_ event: PhysicsEvent) {
        if case .ballBall = event.type, firstBallBallCollisionTime == nil {
            firstBallBallCollisionTime = event.time
        }
        
        switch event.type {
        case .ballBall(let ballA, let ballB):
            resolveBallBallCollision(ballA: ballA, ballB: ballB)
            resolvedEvents.append(event.type)
            resolvedEventTimes.append(currentTime)
            
        case .ballCushion(let ball, let cushionIndex, let normal):
            resolveBallCushionCollision(ball: ball, cushionIndex: cushionIndex, normal: normal)
            resolvedEvents.append(event.type)
            resolvedEventTimes.append(currentTime)
            
        case .transition(let ball, let fromState, let toState):
            resolveTransition(ball: ball, fromState: fromState, toState: toState)
            resolvedEvents.append(event.type)
            resolvedEventTimes.append(currentTime)
            
        case .pocket(let ball, let pocketId):
            // Record the event only if the ball was actually pocketed.
            // Previously events were recorded before resolution, causing game-rule layers
            // to see false pockets when resolvePocket's suspicious-pocket guard rejected the event.
            let pocketed = resolvePocket(ball: ball, pocketId: pocketId)
            if pocketed {
                resolvedEvents.append(event.type)
                resolvedEventTimes.append(currentTime)
            }
        }
    }
    
    /// Resolve ball-ball collision using pure computation
    private func resolveBallBallCollision(ballA: String, ballB: String) {
        guard var stateA = balls[ballA], var stateB = balls[ballB] else { return }
        guard !stateA.isPocketed && !stateB.isPocketed else { return }
        
        // Ref: pooltool/physics/resolve/ball_ball/core.py CoreBallBallCollision.make_kiss
        // Precisely position both balls at 2R + MIN_DIST separation before resolving
        // the collision impulse. Without this, floating-point drift from event evolution
        // leaves the balls slightly interpenetrating, causing cascading zero-time events.
        makeBallBallKiss(stateA: &stateA, stateB: &stateB)
        
        let result = CollisionResolver.resolveBallBallPure(
            posA: stateA.position,
            posB: stateB.position,
            velA: stateA.velocity,
            velB: stateB.velocity,
            angVelA: stateA.angularVelocity,
            angVelB: stateB.angularVelocity
        )
        
        stateA.velocity = result.velA
        stateA.angularVelocity = result.angVelA
        stateB.velocity = result.velB
        stateB.angularVelocity = result.angVelB
        
        stateA.state = determineMotionState(stateA)
        stateB.state = determineMotionState(stateB)
        
        balls[ballA] = stateA
        balls[ballB] = stateB
    }
    
    /// Precisely positions two balls at exactly 2R + MIN_DIST separation before impulse resolution.
    ///
    /// Ref: pooltool/physics/resolve/ball_ball/core.py CoreBallBallCollision.make_kiss
    ///
    /// Primary method: solve a quadratic for the time offset δt that achieves the target
    /// separation, then shift both balls by δt along their current velocities (acceleration
    /// is negligible for the small offsets involved).
    /// Fallback: when both balls are non-translating or the quadratic solution shifts the
    /// contact midpoint by more than 5× MIN_DIST, push each ball symmetrically along the
    /// line of centers.
    private func makeBallBallKiss(stateA: inout BallState, stateB: inout BallState) {
        let spacer: Float = 1e-5  // MIN_DIST equivalent for ball-ball contact
        let targetDist = 2 * BallPhysics.radius + spacer
        
        let delta = stateB.position - stateA.position
        let dist = delta.length()
        
        // Fast-path: already at or beyond target separation, nothing to do.
        if dist >= targetDist { return }

        // Diagnostic: a kiss correction is needed — ball centers are closer than 2R+spacer.
        let penetration = targetDist - dist
        kissCountBallBall += 1
        if penetration > maxBallBallPenetration { maxBallBallPenetration = penetration }
        let penMM_bb = String(format: "%.4f", penetration * 1000)
        let distMM_bb = String(format: "%.4f", dist * 1000)
        let tSec_bb = String(format: "%.4f", currentTime)
        print("[PhysicsAnomaly] ballBallKiss: \(stateA.name)↔\(stateB.name) penetration=\(penMM_bb)mm dist=\(distMM_bb)mm t=\(tSec_bb)s")
        
        let n: SCNVector3
        if dist > 1e-6 {
            n = delta * (1.0 / dist)
        } else {
            n = SCNVector3(1, 0, 0)
        }
        
        let aIsNontranslating = stateA.velocity.length() < 1e-6
        let bIsNontranslating = stateB.velocity.length() < 1e-6
        
        if aIsNontranslating && bIsNontranslating {
            // Both stationary: push symmetrically along line of centers (fallback).
            kissCountBallBallFallback += 1
            print("[PhysicsAnomaly] ballBallKiss fallback(both-nontranslating): \(stateA.name)↔\(stateB.name)")
            let push = (targetDist - dist) * 0.5
            stateA.position = stateA.position - n * push
            stateB.position = stateB.position + n * push
            return
        }
        
        // Quadratic solve: find δt such that |dr + dv·δt|² = targetDist²
        // where dr = rB - rA, dv = vB - vA
        let dv = stateB.velocity - stateA.velocity
        let alpha = dv.dot(dv)
        let beta  = 2 * delta.dot(dv)
        let gamma = delta.dot(delta) - targetDist * targetDist
        
        var useFallback = true
        if abs(alpha) > 1e-12 {
            let discriminant = beta * beta - 4 * alpha * gamma
            if discriminant >= 0 {
                let sqrtD = sqrtf(discriminant)
                let t1 = (-beta - sqrtD) / (2 * alpha)
                let t2 = (-beta + sqrtD) / (2 * alpha)
                // Pick the root with smallest |δt|, i.e. smallest position shift.
                let t = abs(t1) <= abs(t2) ? t1 : t2
                
                let r1New = stateA.position + stateA.velocity * t
                let r2New = stateB.position + stateB.velocity * t
                
                // Reject if the midpoint moves more than 5× spacer (similar velocity case).
                let midOld = (stateA.position + stateB.position) * 0.5
                let midNew = (r1New + r2New) * 0.5
                if (midNew - midOld).length() <= 5 * spacer {
                    stateA.position = r1New
                    stateB.position = r2New
                    useFallback = false
                }
            }
        }
        
        if useFallback {
            kissCountBallBallFallback += 1
            print("[PhysicsAnomaly] ballBallKiss fallback(quadratic-failed): \(stateA.name)↔\(stateB.name)")
            let newDist = (stateB.position - stateA.position).length()
            let push = (targetDist - max(newDist, 1e-6)) * 0.5
            if push > 0 {
                stateA.position = stateA.position - n * push
                stateB.position = stateB.position + n * push
            }
        }
    }
    
    /// Resolve ball-cushion collision using pure computation
    private func resolveBallCushionCollision(ball: String, cushionIndex: Int, normal: SCNVector3) {
        guard var state = balls[ball] else { return }
        guard !state.isPocketed else { return }
        
        let linearCount = tableGeometry.linearCushions.count
        let resolvedNormal: SCNVector3
        
        if cushionIndex >= linearCount {
            let arcIdx = cushionIndex - linearCount
            if arcIdx < tableGeometry.circularCushions.count {
                resolvedNormal = tableGeometry.circularCushions[arcIdx].normal(at: state.position)
            } else {
                resolvedNormal = normal
            }
        } else {
            resolvedNormal = normal
        }
        
        // Ref: pooltool/physics/resolve/ball_cushion/core.py CoreBallLCushionCollision.make_kiss
        // Move the ball to exactly R + spacer distance from the cushion surface before
        // applying the reflection impulse. Without this, accumulated floating-point drift
        // leaves the ball slightly inside the cushion wall; the reflected velocity then
        // points inward, causing repeated zero-time re-detections ("cushion oscillation").
        makeBallCushionKiss(state: &state, cushionIndex: cushionIndex, normal: resolvedNormal)
        
        let result = CollisionResolver.resolveCushionCollisionPure(
            velocity: state.velocity,
            angularVelocity: state.angularVelocity,
            normal: resolvedNormal
        )
        
        state.velocity = result.velocity
        state.angularVelocity = result.angularVelocity
        state.state = determineMotionState(state)
        
        balls[ball] = state
    }
    
    /// Translates the ball along the cushion normal so it sits exactly R + spacer from the surface.
    ///
    /// Ref: pooltool/physics/resolve/ball_cushion/core.py
    /// - For linear cushions: project ball center onto cushion line, compute gap, push out.
    /// - For circular cushions: use arc center distance, compute gap, push out along normal.
    private func makeBallCushionKiss(state: inout BallState, cushionIndex: Int, normal: SCNVector3) {
        let spacer: Float = 1e-6  // 1e-9 in pooltool; use 1e-6 to absorb Float32 rounding
        let linearCount = tableGeometry.linearCushions.count
        
        if cushionIndex < linearCount {
            let cushion = tableGeometry.linearCushions[cushionIndex]
            // Closest point on the cushion line segment to the ball center (XZ plane).
            let closest = closestPointOnSegmentXZ(
                point: state.position,
                segStart: cushion.start,
                segEnd: cushion.end
            )
            let dx = state.position.x - closest.x
            let dz = state.position.z - closest.z
            let gap = sqrtf(dx * dx + dz * dz)  // XZ distance from ball center to cushion edge
            let correction = BallPhysics.radius - gap + spacer
            if correction > -spacer {
                // Diagnostic: ball has penetrated linear cushion.
                kissCountCushion += 1
                let penetration = correction - spacer  // actual penetration depth
                if penetration > maxCushionPenetration { maxCushionPenetration = penetration }
                let penMM_lc = String(format: "%.4f", penetration * 1000)
                let tSec_lc = String(format: "%.4f", currentTime)
                print("[PhysicsAnomaly] cushionKiss(linear): \(state.name) cushion#\(cushionIndex) penetration=\(penMM_lc)mm t=\(tSec_lc)s")
                // Ensure the normal points away from the cushion (toward ball interior).
                let outward: SCNVector3
                if normal.dot(state.velocity) > 0 {
                    outward = normal
                } else {
                    outward = SCNVector3(-normal.x, -normal.y, -normal.z)
                }
                state.position = state.position - outward * correction
            }
        } else {
            let arcIdx = cushionIndex - linearCount
            guard arcIdx < tableGeometry.circularCushions.count else { return }
            let arc = tableGeometry.circularCushions[arcIdx]
            let dx = state.position.x - arc.center.x
            let dz = state.position.z - arc.center.z
            let distToCenter = sqrtf(dx * dx + dz * dz)
            // Ball surface should be at arc.radius + BallPhysics.radius from arc center.
            let correction = BallPhysics.radius + arc.radius - distToCenter - spacer
            if correction > -spacer {
                // Diagnostic: ball has penetrated circular cushion arc.
                kissCountCushion += 1
                let penetration = correction + spacer  // actual penetration into arc
                if penetration > maxCushionPenetration { maxCushionPenetration = penetration }
                let penMM_ac = String(format: "%.4f", penetration * 1000)
                let tSec_ac = String(format: "%.4f", currentTime)
                print("[PhysicsAnomaly] cushionKiss(arc): \(state.name) arc#\(arcIdx) penetration=\(penMM_ac)mm t=\(tSec_ac)s")
                let outward = normal  // arc normal already points away from arc center toward ball
                state.position = state.position + outward * correction
            }
        }
    }
    
    /// Returns the closest point on the infinite line through segStart–segEnd to the given point,
    /// clamped to the segment, computed only in the XZ plane (Y coordinate from segStart).
    private func closestPointOnSegmentXZ(point: SCNVector3, segStart: SCNVector3, segEnd: SCNVector3) -> SCNVector3 {
        let dx = segEnd.x - segStart.x
        let dz = segEnd.z - segStart.z
        let lenSq = dx * dx + dz * dz
        guard lenSq > 1e-12 else { return segStart }
        let t = max(0, min(1, ((point.x - segStart.x) * dx + (point.z - segStart.z) * dz) / lenSq))
        return SCNVector3(segStart.x + t * dx, segStart.y, segStart.z + t * dz)
    }
    
    /// Resolve state transition
    private func resolveTransition(ball: String, fromState: BallMotionState, toState: BallMotionState) {
        guard var state = balls[ball] else { return }
        guard state.state == fromState else { return }
        
        state.state = toState
        
        // When transitioning to rolling, ensure angular velocity matches rolling condition
        if toState == .rolling {
            let up = SCNVector3(0, 1, 0)
            let wRolling = up.cross(state.velocity) * (1.0 / BallPhysics.radius)
            state.angularVelocity = SCNVector3(wRolling.x, state.angularVelocity.y, wRolling.z)
        }
        
        // When transitioning to spinning, zero linear velocity
        if toState == .spinning {
            state.velocity = SCNVector3Zero
        }
        
        // When transitioning to stationary, zero everything
        if toState == .stationary {
            state.velocity = SCNVector3Zero
            state.angularVelocity = SCNVector3Zero
        }
        
        balls[ball] = state
    }
    
    /// Resolve pocket event. Returns true if the ball was actually pocketed, false if rejected.
    @discardableResult
    private func resolvePocket(ball: String, pocketId: String) -> Bool {
        guard var state = balls[ball] else { return false }
        
        // 防止数值误判导致"球在台面中部突然消失"：
        // 使用 XZ 2D 距离：袋口中心在台面高度处，球心在台面上方 radius，
        // 若用 3D 距离会永远带一个 Y 偏移量，导致误拒绝合法进袋。
        if let pocket = tableGeometry.pockets.first(where: { $0.id == pocketId }) {
            let dx = state.position.x - pocket.center.x
            let dz = state.position.z - pocket.center.z
            let dist = sqrtf(dx * dx + dz * dz)
            let allowed = pocket.radius + BallPhysics.radius * 1.5
            if dist > allowed {
                print("[EventDrivenEngine] 忽略可疑进袋: ball=\(ball), pocket=\(pocketId), dist2D=\(dist), allowed=\(allowed), pos=\(state.position)")
                return false
            }
        }
        state.state = .pocketed
        state.velocity = SCNVector3Zero
        state.angularVelocity = SCNVector3Zero
        
        balls[ball] = state
        return true
    }
    
    /// Determine motion state from ball kinematics
    private func determineMotionState(_ ball: BallState) -> BallMotionState {
        if ball.isPocketed {
            return .pocketed
        }
        
        let speed = ball.velocity.length()
        let relVel = AnalyticalMotion.surfaceVelocity(
            linear: ball.velocity,
            angular: ball.angularVelocity,
            radius: BallPhysics.radius
        )
        let relSpeed = relVel.length()
        
        if speed < 0.001 && abs(ball.angularVelocity.y) < 0.001 {
            return .stationary
        } else if relSpeed > 0.001 {
            return .sliding
        } else if speed > 0.001 {
            return .rolling
        } else if abs(ball.angularVelocity.y) > 0.001 {
            return .spinning
        } else {
            return .stationary
        }
    }
    
    /// Invalidate cache for affected balls in an event
    private func invalidateCache(for event: PhysicsEvent) {
        var affectedBalls: Set<String> = []
        
        switch event.type {
        case .ballBall(let ballA, let ballB):
            affectedBalls.insert(ballA)
            affectedBalls.insert(ballB)
        case .ballCushion(let ball, _, _):
            affectedBalls.insert(ball)
        case .transition(let ball, _, _):
            affectedBalls.insert(ball)
        case .pocket(let ball, _):
            affectedBalls.insert(ball)
        }
        
        eventCache.invalidate(affectedBalls: affectedBalls)
    }
    
    /// Record current state snapshot to trajectory recorder
    private func recordSnapshot() {
        for (name, ball) in balls {
            let frame = BallFrame(
                time: currentTime,
                position: ball.position,
                velocity: ball.velocity,
                angularVelocity: SCNVector4(ball.angularVelocity.x, ball.angularVelocity.y, ball.angularVelocity.z, 0),
                state: ball.state
            )
            trajectoryRecorder.recordFrame(ballName: name, frame: frame)
        }
    }
    
    /// Check whether a collision point lies on a finite cushion segment.
    private func isWithinLinearCushionSegment(point: SCNVector3, segment: LinearCushionSegment) -> Bool {
        let segmentVector = segment.end - segment.start
        let segmentLengthSquared = segmentVector.dot(segmentVector)
        guard segmentLengthSquared > 1e-8 else { return false }
        
        let t = (point - segment.start).dot(segmentVector) / segmentLengthSquared
        let epsilon: Float = 0.001
        return t >= -epsilon && t <= 1 + epsilon
    }
    
    /// 判断两球是否已经接触/重叠（用于在 findNextEvent 中立即调度 t=0 碰撞）
    ///
    /// 修复：严重重叠时（穿透 > 0.1mm）无条件返回 true，不检查速度方向。
    /// 原先因 relV.dot(n) 守卫，在链式碰撞后两球同向运动时会漏报 → 四次方程
    /// 对已穿透对求不到正根 → 碰撞被完全忽略 → 重叠积累到 15mm。
    private func isBallPairOverlappingOrTouching(_ a: BallState, _ b: BallState) -> Bool {
        let delta = b.position - a.position
        // Use XZ-plane distance to match separateOverlappingBalls. If we used 3D distance
        // here but separate uses XZ, a pair could be flagged by separate yet not trigger
        // a t=0 event, allowing penetration to grow unchecked.
        let d2 = delta.x * delta.x + delta.z * delta.z
        let dist = sqrtf(max(d2, 1e-12))
        let touchDist = 2 * BallPhysics.radius
        let eps: Float = 0.00025

        guard dist <= touchDist + eps else { return false }

        // If balls are actually penetrating (not just touching), always schedule a t=0
        // resolution regardless of velocity direction. Penetration means the quartic will
        // only find negative-time roots, so we must force-resolve now.
        let penetration = touchDist - dist
        if penetration > 0.00001 {  // > 0.01 mm actual overlap
            return true
        }

        // For just-touching balls, only trigger when approaching (relV.dot(n) < 0) to
        // avoid a storm of zero-time events on resting clusters.
        let relV = b.velocity - a.velocity
        if dist < 1e-5 {
            return relV.length() > 0.02
        }
        let n = SCNVector3(delta.x / dist, 0, delta.z / dist)
        return relV.dot(n) < -0.002
    }
    
    /// 是否值得触发离散保底碰撞检测（昂贵操作，需严格限流）
    private func shouldRunFallbackBallBallCheck(
        ballA: BallState,
        ballB: BallState,
        aA: SCNVector3,
        aB: SCNVector3,
        maxTime: Float
    ) -> Bool {
        guard maxTime > 0 else { return false }

        let dp = ballB.position - ballA.position
        let dx = dp.x, dz = dp.z
        let dist = sqrtf(dx * dx + dz * dz)
        let touch = 2 * BallPhysics.radius
        guard dist > 1e-6 else { return true }  // 已重叠，直接允许

        // Near-field safeguard: quartic misses are most visible for translating vs
        // nontranslating pairs at short range (stationary/spinning target hit by
        // rolling/sliding ball). Allow fallback early in this zone.
        let aTranslating = !(ballA.state == .stationary || ballA.state == .spinning || ballA.state == .pocketed)
        let bTranslating = !(ballB.state == .stationary || ballB.state == .spinning || ballB.state == .pocketed)
        let gap = dist - touch
        // Fallback is a local rescue for quartic misses, not a long-range predictor.
        // Far pairs tend to generate phantom hits under constant-acceleration approximation.
        if gap > 0.35 {
            return false
        }
        if aTranslating != bTranslating && gap < 0.25 {
            return true
        }

        // Also open fallback for generic near-field active pairs (including
        // rolling-rolling / rolling-spinning) where quartic misses still appear in logs.
        // We keep this band small to avoid excessive fallback scans.
        let relVxz = sqrtf(powf(ballB.velocity.x - ballA.velocity.x, 2) + powf(ballB.velocity.z - ballA.velocity.z, 2))
        if (aTranslating || bTranslating) && gap < 0.08 && relVxz > 0.01 {
            return true
        }

        // 连心线方向单位向量（XZ 平面）
        let nx = dx / dist, nz = dz / dist

        let relV = ballB.velocity - ballA.velocity
        let relA = aB - aA

        // 沿连心线的靠近速度（负值 = 靠近）
        let approachV = relV.x * nx + relV.z * nz
        // 沿连心线的靠近加速度（负值 = 加速靠近）
        let approachA = relA.x * nx + relA.z * nz

        // 必须在 horizon 内能靠近到 touch 距离
        // 最大可靠近量 = |min(approachV, 0)| * horizon + 0.5*|min(approachA,0)| * horizon²
        let closingV = max(-approachV, 0.0)   // 靠近速度分量（正值）
        let closingA = max(-approachA, 0.0)   // 靠近加速度分量（正值）
        // Keep the gate local in time to avoid approving long-horizon speculative collisions.
        let horizonForGate = min(maxTime, 0.6)
        let maxClosing = closingV * horizonForGate + 0.5 * closingA * horizonForGate * horizonForGate

        // 若最大可靠近量 + 容差仍不足以从 dist 缩短到 touch，则不可能碰撞
        if dist - touch > maxClosing + 0.002 {
            return false
        }

        return true
    }
    
    /// quartic 漏检时，使用离散+二分求保底碰撞时刻
    private func fallbackBallBallCollisionTime(
        ballA: BallState,
        ballB: BallState,
        aA: SCNVector3,
        aB: SCNVector3,
        maxTime: Float
    ) -> Float? {
        let touch = 2 * BallPhysics.radius
        guard maxTime > 0 else { return nil }

        // Limit horizon to the time during which the constant-acceleration model is valid.
        // Beyond a state-transition, the acceleration changes, so extending past it
        // produces incorrect (phantom) collision times.
        // Use the shorter of the two balls' remaining state lifetimes.
        func stateLifetime(_ ball: BallState) -> Float {
            switch ball.state {
            case .sliding:
                return AnalyticalMotion.slideToRollTime(
                    velocity: ball.velocity,
                    angularVelocity: ball.angularVelocity
                )
            case .rolling:
                return AnalyticalMotion.rollToSpinTime(velocity: ball.velocity)
            case .spinning:
                return AnalyticalMotion.spinToStationaryTime(angularVelocity: ball.angularVelocity)
            case .stationary, .pocketed:
                return 0
            }
        }
        let lifetimeA = stateLifetime(ballA)
        let lifetimeB = stateLifetime(ballB)
        // Add small margin (1 step) to catch collisions right at the boundary,
        // but cap strictly so we don't wander into the next motion phase.
        let stateHorizon = min(lifetimeA, lifetimeB) * 1.05 + 0.05
        // Keep fallback horizon short and local; quartic is the primary solver for long range.
        let horizon = min(maxTime, stateHorizon, 0.6)
        guard horizon > 0 else { return nil }

        // Adaptive steps: each step ≤ 0.02s; 40–300 steps
        let steps = min(300, max(40, Int(ceil(horizon / 0.02))))
        let dt = horizon / Float(steps)
        
        func distanceMinusTouch(_ t: Float) -> Float {
            let pA = ballA.position + ballA.velocity * t + aA * (0.5 * t * t)
            let pB = ballB.position + ballB.velocity * t + aB * (0.5 * t * t)
            let dx = pA.x - pB.x
            let dz = pA.z - pB.z
            return sqrtf(dx * dx + dz * dz) - touch
        }
        
        var t0: Float = 0
        var f0 = distanceMinusTouch(0)
        if f0 <= 0 { return 0 }
        
        for i in 1...steps {
            let t1 = Float(i) * dt
            let f1 = distanceMinusTouch(t1)
            if f1 <= 0 || (f0 > 0 && f1 < 0) {
                var lo = t0
                var hi = t1
                for _ in 0..<18 {
                    let mid = (lo + hi) * 0.5
                    if distanceMinusTouch(mid) <= 0 {
                        hi = mid
                    } else {
                        lo = mid
                    }
                }
                return hi
            }
            t0 = t1
            f0 = f1
        }
        
        return nil
    }
    
    /// Select smallest positive root within maxTime
    private func smallestPositiveRoot(_ roots: [Double], maxTime: Float) -> Float? {
        let epsilon = 1e-6
        let maxT = Double(maxTime) + 1e-6
        let validRoots = roots.filter { $0 > epsilon && $0 <= maxT && $0.isFinite && !$0.isNaN }
        guard let smallest = validRoots.min() else { return nil }
        return Float(smallest)
    }
}

// MARK: - SceneKit Bridge

/// Bridge for playing back trajectory recordings in SceneKit
class SceneKitBridge {
    /// Play back trajectory for a ball node
    /// - Parameters:
    ///   - node: SceneKit node to animate
    ///   - ballName: Name of the ball in the trajectory recorder
    ///   - recorder: Trajectory recorder containing recorded frames
    ///   - speed: Playback speed multiplier (1.0 = real-time)
    /// - Returns: SCNAction sequence for the trajectory, or nil if no trajectory found
    static func playTrajectory(
        node: SCNNode,
        ballName: String,
        recorder: TrajectoryRecorder,
        speed: Float = 1.0
    ) -> SCNAction? {
        return recorder.action(for: node, ballName: ballName, speed: speed)
    }
    
    /// Play back trajectories for multiple balls simultaneously
    /// - Parameters:
    ///   - nodes: Dictionary mapping ball names to SceneKit nodes
    ///   - recorder: Trajectory recorder containing recorded frames
    ///   - speed: Playback speed multiplier (1.0 = real-time)
    /// - Returns: Dictionary mapping ball names to SCNAction sequences
    static func playTrajectories(
        nodes: [String: SCNNode],
        recorder: TrajectoryRecorder,
        speed: Float = 1.0
    ) -> [String: SCNAction] {
        var actions: [String: SCNAction] = [:]
        
        for (ballName, node) in nodes {
            if let action = recorder.action(for: node, ballName: ballName, speed: speed) {
                actions[ballName] = action
            }
        }
        
        return actions
    }
}
