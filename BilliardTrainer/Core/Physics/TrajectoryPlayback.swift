//
//  TrajectoryPlayback.swift
//  BilliardTrainer
//
//  基于事件快照 + AnalyticalMotion 解析演进的轨迹回放器
//  物理积分路径零改动：在任意时刻 t 精确计算球的位置和旋转
//

import SceneKit

struct PlaybackBallState {
    let position: SCNVector3
    let velocity: SCNVector3
    let motionState: BallMotionState
    /// 从回放起点累积的滚动弧度（用于视觉旋转）
    let accumulatedRotation: Float
    /// 瞬时运动方向（用于确定旋转轴）
    let moveDirection: SCNVector3
}

final class TrajectoryPlayback {
    
    let recorder: TrajectoryRecorder
    let surfaceY: Float
    
    /// 每个球的帧数据缓存（按时间排序，来自 recorder）
    private let sortedFrames: [String: [BallFrame]]
    
    /// 缓存：每个球各帧之间的累积滚动弧度前缀和
    private var rotationPrefixSums: [String: [Float]] = [:]
    
    /// 已触发进袋的球名称集合（防止重复触发）
    private(set) var pocketedBalls: Set<String> = []
    
    /// 已触发淡出动画的球（进袋后需要一小段淡出时间）
    private(set) var fadingBalls: [String: Float] = [:]
    
    private let fadeOutDuration: Float = 0.25
    
    var duration: Float { recorder.duration }
    
    init(recorder: TrajectoryRecorder, surfaceY: Float) {
        self.recorder = recorder
        self.surfaceY = surfaceY
        
        var sorted: [String: [BallFrame]] = [:]
        for (name, frames) in recorder.framesByBallName {
            sorted[name] = frames.sorted { $0.time < $1.time }
        }
        self.sortedFrames = sorted
        
        precomputeRotationPrefixSums()
    }
    
    /// 预计算每个球在事件快照之间的累积滚动弧度前缀和
    private func precomputeRotationPrefixSums() {
        for (name, frames) in sortedFrames {
            guard frames.count > 1 else {
                rotationPrefixSums[name] = [0]
                continue
            }
            var sums: [Float] = [0]
            for i in 1..<frames.count {
                let prev = frames[i - 1]
                let next = frames[i]
                let displacement = next.position - prev.position
                let distance = displacement.length()
                let angle = distance / BallPhysics.radius
                sums.append(sums[i - 1] + angle)
            }
            rotationPrefixSums[name] = sums
        }
    }
    
    /// 查询指定球在时刻 t 的精确状态
    func stateAt(ballName: String, time: Float) -> PlaybackBallState? {
        guard let frames = sortedFrames[ballName], !frames.isEmpty else { return nil }
        
        let t = max(0, time)
        
        if frames.count == 1 {
            let f = frames[0]
            return PlaybackBallState(
                position: SCNVector3(f.position.x, surfaceY, f.position.z),
                velocity: f.velocity,
                motionState: f.state,
                accumulatedRotation: 0,
                moveDirection: SCNVector3Zero
            )
        }
        
        if t <= frames[0].time {
            let f = frames[0]
            return PlaybackBallState(
                position: SCNVector3(f.position.x, surfaceY, f.position.z),
                velocity: f.velocity,
                motionState: f.state,
                accumulatedRotation: 0,
                moveDirection: f.velocity.length() > 0.001 ? f.velocity.normalized() : SCNVector3Zero
            )
        }
        
        // 二分查找：找到最后一个 frame.time <= t 的索引
        let idx = binarySearchFloor(frames: frames, time: t)
        let baseFrame = frames[idx]
        
        if baseFrame.state == .pocketed {
            return PlaybackBallState(
                position: SCNVector3(baseFrame.position.x, surfaceY, baseFrame.position.z),
                velocity: SCNVector3Zero,
                motionState: .pocketed,
                accumulatedRotation: rotationPrefixSums[ballName]?[idx] ?? 0,
                moveDirection: SCNVector3Zero
            )
        }
        
        if baseFrame.state == .stationary {
            return PlaybackBallState(
                position: SCNVector3(baseFrame.position.x, surfaceY, baseFrame.position.z),
                velocity: SCNVector3Zero,
                motionState: .stationary,
                accumulatedRotation: rotationPrefixSums[ballName]?[idx] ?? 0,
                moveDirection: SCNVector3Zero
            )
        }
        
        // 解析演进：从 baseFrame 推进 dt 到时刻 t
        let dt = t - baseFrame.time
        
        // 限制 dt 不超过下一帧时刻（防止越过事件）
        let maxDt: Float
        if idx + 1 < frames.count {
            maxDt = frames[idx + 1].time - baseFrame.time
        } else {
            maxDt = dt
        }
        let clampedDt = min(dt, maxDt)
        
        let angularVel3 = SCNVector3(
            baseFrame.angularVelocity.x,
            baseFrame.angularVelocity.y,
            baseFrame.angularVelocity.z
        )
        
        let evolved: (position: SCNVector3, velocity: SCNVector3, angularVelocity: SCNVector3)
        
        switch baseFrame.state {
        case .sliding:
            evolved = AnalyticalMotion.evolveSliding(
                position: baseFrame.position,
                velocity: baseFrame.velocity,
                angularVelocity: angularVel3,
                dt: clampedDt
            )
        case .rolling:
            evolved = AnalyticalMotion.evolveRolling(
                position: baseFrame.position,
                velocity: baseFrame.velocity,
                angularVelocity: angularVel3,
                dt: clampedDt
            )
        case .spinning:
            let result = AnalyticalMotion.evolveSpinning(
                position: baseFrame.position,
                angularVelocity: angularVel3,
                dt: clampedDt
            )
            evolved = (result.position, baseFrame.velocity, result.angularVelocity)
        case .stationary, .pocketed:
            evolved = (baseFrame.position, baseFrame.velocity, angularVel3)
        }
        
        // 累积旋转 = 前缀和到 baseFrame + 本段解析位移产生的旋转
        let basePrefixRotation = rotationPrefixSums[ballName]?[idx] ?? 0
        let segmentDisplacement = evolved.position - baseFrame.position
        let segmentDistance = segmentDisplacement.length()
        let segmentRotation = segmentDistance / BallPhysics.radius
        
        let moveDir: SCNVector3
        if evolved.velocity.length() > 0.001 {
            moveDir = evolved.velocity.normalized()
        } else if segmentDistance > 0.0001 {
            moveDir = segmentDisplacement.normalized()
        } else {
            moveDir = SCNVector3Zero
        }
        
        return PlaybackBallState(
            position: SCNVector3(evolved.position.x, surfaceY, evolved.position.z),
            velocity: evolved.velocity,
            motionState: baseFrame.state,
            accumulatedRotation: basePrefixRotation + segmentRotation,
            moveDirection: moveDir
        )
    }
    
    /// 标记球已进袋并开始淡出
    func markPocketed(_ ballName: String, at time: Float) {
        guard !pocketedBalls.contains(ballName) else { return }
        pocketedBalls.insert(ballName)
        fadingBalls[ballName] = time
    }
    
    /// 获取球当前应有的不透明度（进袋淡出）
    func opacity(for ballName: String, at time: Float) -> Float {
        guard let fadeStart = fadingBalls[ballName] else { return 1.0 }
        let elapsed = time - fadeStart
        if elapsed >= fadeOutDuration { return 0.0 }
        return 1.0 - (elapsed / fadeOutDuration)
    }
    
    /// 检查球是否会在轨迹中被进袋
    func willBePocketed(_ ballName: String) -> Bool {
        recorder.isBallPocketed(ballName)
    }
    
    /// 检查回放是否已完成（所有球到达最终状态）
    func isComplete(at time: Float) -> Bool {
        return time >= duration
    }
    
    // MARK: - Binary Search
    
    /// 找到最后一个 frame.time <= targetTime 的索引
    private func binarySearchFloor(frames: [BallFrame], time targetTime: Float) -> Int {
        var lo = 0
        var hi = frames.count - 1
        var result = 0
        
        while lo <= hi {
            let mid = (lo + hi) / 2
            if frames[mid].time <= targetTime {
                result = mid
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }
        
        return result
    }
}
