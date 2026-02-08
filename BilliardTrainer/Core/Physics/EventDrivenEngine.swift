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
    
    static func < (lhs: PhysicsEvent, rhs: PhysicsEvent) -> Bool {
        if abs(lhs.time - rhs.time) < 0.0001 {
            return lhs.priority < rhs.priority
        }
        return lhs.time < rhs.time
    }
    
    static func == (lhs: PhysicsEvent, rhs: PhysicsEvent) -> Bool {
        return abs(lhs.time - rhs.time) < 0.0001 && lhs.priority == rhs.priority
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
class EventCache {
    private struct CachedEvent {
        let event: PhysicsEvent
        let timeStamp: Float
    }
    
    // Cache keys: "ballA-ballB" for ball-ball collisions
    private var ballBallCache: [String: CachedEvent] = [:]
    
    // Cache keys: "ball-cushionIndex" for ball-cushion collisions
    private var ballCushionCache: [String: CachedEvent] = [:]
    
    // Cache keys: "ball-transitionType" for state transitions
    private var transitionCache: [String: CachedEvent] = [:]
    
    /// Invalidate cache entries for affected balls
    func invalidate(affectedBalls: Set<String>) {
        // Remove all entries involving affected balls
        ballBallCache = ballBallCache.filter { key, _ in
            let parts = key.split(separator: "-")
            guard parts.count == 2 else { return false }
            let ballA = String(parts[0])
            let ballB = String(parts[1])
            return !affectedBalls.contains(ballA) && !affectedBalls.contains(ballB)
        }
        
        ballCushionCache = ballCushionCache.filter { key, _ in
            let parts = key.split(separator: "-")
            guard parts.count == 2 else { return false }
            let ball = String(parts[0])
            return !affectedBalls.contains(ball)
        }
        
        transitionCache = transitionCache.filter { key, _ in
            let parts = key.split(separator: "-")
            guard parts.count >= 1 else { return false }
            let ball = String(parts[0])
            return !affectedBalls.contains(ball)
        }
    }
    
    /// Get cached ball-ball event
    func getBallBall(ballA: String, ballB: String, currentTime: Float) -> PhysicsEvent? {
        let key = makeBallBallKey(ballA: ballA, ballB: ballB)
        guard let cached = ballBallCache[key] else { return nil }
        let remaining = cached.event.time - (currentTime - cached.timeStamp)
        if remaining <= 0 {
            ballBallCache[key] = nil
            return nil
        }
        return PhysicsEvent(type: cached.event.type, time: remaining, priority: cached.event.priority)
    }
    
    /// Set cached ball-ball event
    func setBallBall(ballA: String, ballB: String, event: PhysicsEvent, currentTime: Float) {
        let key = makeBallBallKey(ballA: ballA, ballB: ballB)
        ballBallCache[key] = CachedEvent(event: event, timeStamp: currentTime)
    }
    
    /// Get cached ball-cushion event
    func getBallCushion(ball: String, cushionIndex: Int, currentTime: Float) -> PhysicsEvent? {
        let key = makeBallCushionKey(ball: ball, cushionIndex: cushionIndex)
        guard let cached = ballCushionCache[key] else { return nil }
        let remaining = cached.event.time - (currentTime - cached.timeStamp)
        if remaining <= 0 {
            ballCushionCache[key] = nil
            return nil
        }
        return PhysicsEvent(type: cached.event.type, time: remaining, priority: cached.event.priority)
    }
    
    /// Set cached ball-cushion event
    func setBallCushion(ball: String, cushionIndex: Int, event: PhysicsEvent, currentTime: Float) {
        let key = makeBallCushionKey(ball: ball, cushionIndex: cushionIndex)
        ballCushionCache[key] = CachedEvent(event: event, timeStamp: currentTime)
    }
    
    /// Get cached transition event
    func getTransition(ball: String, transitionType: String, currentTime: Float) -> PhysicsEvent? {
        let key = makeTransitionKey(ball: ball, transitionType: transitionType)
        guard let cached = transitionCache[key] else { return nil }
        let remaining = cached.event.time - (currentTime - cached.timeStamp)
        if remaining <= 0 {
            transitionCache[key] = nil
            return nil
        }
        return PhysicsEvent(type: cached.event.type, time: remaining, priority: cached.event.priority)
    }
    
    /// Set cached transition event
    func setTransition(ball: String, transitionType: String, event: PhysicsEvent, currentTime: Float) {
        let key = makeTransitionKey(ball: ball, transitionType: transitionType)
        transitionCache[key] = CachedEvent(event: event, timeStamp: currentTime)
    }
    
    /// Clear all caches
    func clear() {
        ballBallCache.removeAll()
        ballCushionCache.removeAll()
        transitionCache.removeAll()
    }
    
    // MARK: - Private Helpers
    
    private func makeBallBallKey(ballA: String, ballB: String) -> String {
        // Ensure consistent ordering
        if ballA < ballB {
            return "\(ballA)-\(ballB)"
        } else {
            return "\(ballB)-\(ballA)"
        }
    }
    
    private func makeBallCushionKey(ball: String, cushionIndex: Int) -> String {
        return "\(ball)-cushion\(cushionIndex)"
    }
    
    private func makeTransitionKey(ball: String, transitionType: String) -> String {
        return "\(ball)-\(transitionType)"
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
        var eventCount = 0
        
        while eventCount < maxEvents && currentTime < maxTime {
            // Find next event
            guard let nextEvent = findNextEvent(maxTimeRemaining: maxTime - currentTime) else {
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
                resolveEvent(nextEvent)
                invalidateCache(for: nextEvent)
                recordSnapshot()
                eventCount += 1
                continue
            }
            
            evolveAllBalls(dt: dt)
            currentTime += dt
            
            // Resolve event
            resolveEvent(nextEvent)
            
            // Invalidate cache for affected balls
            invalidateCache(for: nextEvent)
            
            // Record snapshot
            recordSnapshot()
            
            eventCount += 1
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
        
        // Find next transition events
        for (name, ball) in balls {
            guard !ball.isPocketed else { continue }
            
            // Check slide-to-roll transition
            if ball.state == .sliding {
                let transitionType = "slideToRoll"
                if let cached = eventCache.getTransition(ball: name, transitionType: transitionType, currentTime: currentTime) {
                    if cached.time > 0 && cached.time <= maxTimeRemaining {
                        candidates.append(cached)
                    }
                } else {
                    let transitionTime = AnalyticalMotion.slideToRollTime(
                        velocity: ball.velocity,
                        angularVelocity: ball.angularVelocity
                    )
                    if transitionTime > 0 && transitionTime <= maxTimeRemaining {
                        let event = PhysicsEvent(
                            type: .transition(ball: name, fromState: .sliding, toState: .rolling),
                            time: transitionTime,
                            priority: 1
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
                    if cached.time > 0 && cached.time <= maxTimeRemaining {
                        candidates.append(cached)
                    }
                } else {
                    let transitionTime = AnalyticalMotion.rollToSpinTime(velocity: ball.velocity)
                    if transitionTime > 0 && transitionTime <= maxTimeRemaining {
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
                    if cached.time > 0 && cached.time <= maxTimeRemaining {
                        candidates.append(cached)
                    }
                } else {
                    let transitionTime = AnalyticalMotion.spinToStationaryTime(angularVelocity: ball.angularVelocity)
                    if transitionTime > 0 && transitionTime <= maxTimeRemaining {
                        let event = PhysicsEvent(
                            type: .transition(ball: name, fromState: .spinning, toState: .stationary),
                            time: transitionTime,
                            priority: 3
                        )
                        eventCache.setTransition(ball: name, transitionType: transitionType, event: event, currentTime: currentTime)
                        candidates.append(event)
                    }
                }
            }
        }
        
        // Find ball-ball collisions
        let ballNames = Array(balls.keys)
        for i in 0..<ballNames.count {
            for j in (i+1)..<ballNames.count {
                let nameA = ballNames[i]
                let nameB = ballNames[j]
                
                guard let ballA = balls[nameA], let ballB = balls[nameB] else { continue }
                guard !ballA.isPocketed && !ballB.isPocketed else { continue }
                
                // Check cache first
                if let cached = eventCache.getBallBall(ballA: nameA, ballB: nameB, currentTime: currentTime) {
                    if cached.time > 0 && cached.time <= maxTimeRemaining {
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
                    maxTime: Double(maxTimeRemaining)
                ) {
                    let event = PhysicsEvent(
                        type: .ballBall(ballA: nameA, ballB: nameB),
                        time: collisionTime,
                        priority: 0  // Highest priority
                    )
                    eventCache.setBallBall(ballA: nameA, ballB: nameB, event: event, currentTime: currentTime)
                    candidates.append(event)
                }
            }
        }
        
        // Find ball-cushion collisions
        for (name, ball) in balls {
            guard !ball.isPocketed else { continue }
            
            let a = acceleration(for: ball)
            
            // Check linear cushions
            for (index, cushion) in tableGeometry.linearCushions.enumerated() {
                // Check cache first
                if let cached = eventCache.getBallCushion(ball: name, cushionIndex: index, currentTime: currentTime) {
                    if cached.time > 0 && cached.time <= maxTimeRemaining {
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
                    maxTime: Double(maxTimeRemaining)
                ) {
                    let event = PhysicsEvent(
                        type: .ballCushion(ball: name, cushionIndex: index, normal: cushion.normal),
                        time: collisionTime,
                        priority: 0  // Highest priority
                    )
                    eventCache.setBallCushion(ball: name, cushionIndex: index, event: event, currentTime: currentTime)
                    candidates.append(event)
                }
            }
        }
        
        // Find ball-pocket events (CCD quartic solve)
        for (name, ball) in balls {
            guard !ball.isPocketed else { continue }
            
            let a = acceleration(for: ball)
            
            // Check each pocket
            for pocket in tableGeometry.pockets {
                let r = max(pocket.radius - BallPhysics.radius, 0.0)
                let dp = ball.position - pocket.center
                let dv = ball.velocity
                let da = a
                let halfDa = da * 0.5
                
                let halfDaDotHalfDa = Double(halfDa.dot(halfDa))
                let dvDotHalfDa = Double(dv.dot(halfDa))
                let dvDotDv = Double(dv.dot(dv))
                let dpDotHalfDa = Double(dp.dot(halfDa))
                let dpDotDv = Double(dp.dot(dv))
                let dpDotDp = Double(dp.dot(dp))
                
                let a4 = halfDaDotHalfDa
                let a3 = 2.0 * dvDotHalfDa
                let a2 = dvDotDv + 2.0 * dpDotHalfDa
                let a1 = 2.0 * dpDotDv
                let a0 = dpDotDp - Double(r * r)
                
                let roots = QuarticSolver.solveQuartic(a: a4, b: a3, c: a2, d: a1, e: a0)
                if let time = smallestPositiveRoot(roots, maxTime: maxTimeRemaining) {
                    candidates.append(PhysicsEvent(
                        type: .pocket(ball: name, pocketId: pocket.id),
                        time: time,
                        priority: 2
                    ))
                }
            }
        }
        
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
            
            balls[name] = BallState(
                position: evolved.position,
                velocity: evolved.velocity,
                angularVelocity: evolved.angularVelocity,
                state: ball.state,
                name: ball.name
            )
        }
    }
    
    /// Resolve a physics event
    private func resolveEvent(_ event: PhysicsEvent) {
        // Record event for game rules / audio
        resolvedEvents.append(event.type)
        
        switch event.type {
        case .ballBall(let ballA, let ballB):
            resolveBallBallCollision(ballA: ballA, ballB: ballB)
            
        case .ballCushion(let ball, let cushionIndex, let normal):
            resolveBallCushionCollision(ball: ball, cushionIndex: cushionIndex, normal: normal)
            
        case .transition(let ball, let fromState, let toState):
            resolveTransition(ball: ball, fromState: fromState, toState: toState)
            
        case .pocket(let ball, let pocketId):
            resolvePocket(ball: ball, pocketId: pocketId)
        }
    }
    
    /// Resolve ball-ball collision using pure computation
    private func resolveBallBallCollision(ballA: String, ballB: String) {
        guard var stateA = balls[ballA], var stateB = balls[ballB] else { return }
        guard !stateA.isPocketed && !stateB.isPocketed else { return }
        
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
    
    /// Resolve ball-cushion collision using pure computation
    private func resolveBallCushionCollision(ball: String, cushionIndex: Int, normal: SCNVector3) {
        guard var state = balls[ball] else { return }
        guard !state.isPocketed else { return }
        
        let result = CollisionResolver.resolveCushionCollisionPure(
            velocity: state.velocity,
            angularVelocity: state.angularVelocity,
            normal: normal
        )
        
        state.velocity = result.velocity
        state.angularVelocity = result.angularVelocity
        state.state = determineMotionState(state)
        
        balls[ball] = state
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
    
    /// Resolve pocket event
    private func resolvePocket(ball: String, pocketId: String) {
        guard var state = balls[ball] else { return }
        
        state.state = .pocketed
        state.velocity = SCNVector3Zero
        state.angularVelocity = SCNVector3Zero
        
        balls[ball] = state
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
