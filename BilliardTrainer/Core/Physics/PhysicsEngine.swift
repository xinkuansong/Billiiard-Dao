//
//  PhysicsEngine.swift
//  BilliardTrainer
//
//  物理引擎核心 - 扩展SceneKit物理以支持专业台球物理
//

import SceneKit

// MARK: - Physics Engine
/// 台球物理引擎
class PhysicsEngine {
    
    // MARK: - Properties
    
    weak var scene: BilliardScene?
    
    /// 当前所有运动中的球
    private var movingBalls: Set<SCNNode> = []
    
    /// 物理更新定时器
    private var updateTimer: Timer?
    
    /// 物理更新频率 (Hz)
    private let updateFrequency: TimeInterval = 1.0 / 60.0
    
    /// 球运动状态缓存
    private var ballStates: [ObjectIdentifier: BallMotionState] = [:]
    
    /// 轨迹记录器
    private var trajectoryRecorder: TrajectoryRecorder?
    
    /// 当前模拟时间
    private var simulationTime: Float = 0
    
    // MARK: - Initialization
    
    init(scene: BilliardScene) {
        self.scene = scene
    }
    
    // MARK: - Start/Stop
    
    /// 开始物理模拟
    func startSimulation() {
        simulationTime = 0
        trajectoryRecorder = TrajectoryRecorder()
        updateTimer = Timer.scheduledTimer(
            withTimeInterval: updateFrequency,
            repeats: true
        ) { [weak self] _ in
            self?.update()
        }
    }
    
    /// 停止物理模拟
    func stopSimulation() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    /// 获取最近一次轨迹记录
    func latestTrajectoryRecorder() -> TrajectoryRecorder? {
        return trajectoryRecorder
    }
    
    // MARK: - Update Loop
    
    /// 物理更新循环
    private func update() {
        guard let scene = scene else { return }
        let dt = Float(updateFrequency)
        simulationTime += dt
        
        // 更新母球旋转效果
        if let cueBall = scene.cueBallNode {
            updateBallPhysics(for: cueBall, dt: dt)
        }
        
        // 更新所有目标球
        for ball in scene.targetBallNodes {
            updateBallPhysics(for: ball, dt: dt)
        }
        
        // 检查是否所有球都停止
        checkBallsAtRest()
    }
    
    /// 更新球物理（滑动/滚动/旋转）
    private func updateBallPhysics(for ballNode: SCNNode, dt: Float) {
        guard let physicsBody = ballNode.physicsBody else { return }
        
        let velocity = physicsBody.velocity
        let angularVelocity = physicsBody.angularVelocity
        
        let speed = SCNVector3(velocity.x, velocity.y, velocity.z).length()
        let angularSpeed = SCNVector3(angularVelocity.x, angularVelocity.y, angularVelocity.z).length()
        
        let identifier = ObjectIdentifier(ballNode)
        let currentState = ballStates[identifier] ?? .sliding
        
        var newState = currentState
        if speed < 0.005 && angularSpeed < 0.1 {
            newState = .stationary
        } else if speed < 0.005 && angularSpeed >= 0.1 {
            newState = .spinning
        } else {
            let sliding = isBallSliding(linearVelocity: velocity, angularVelocity: angularVelocity)
            newState = sliding ? .sliding : .rolling
        }
        ballStates[identifier] = newState
        
        switch newState {
        case .sliding:
            applySlidingFriction(to: physicsBody, dt: dt)
            applySpinDecay(to: physicsBody, dt: dt)
        case .rolling:
            applyRollingFriction(to: physicsBody, dt: dt)
            applySpinDecay(to: physicsBody, dt: dt)
        case .spinning:
            applySpinDecay(to: physicsBody, dt: dt)
        case .stationary, .pocketed:
            break
        }
        
        if let recorder = trajectoryRecorder, let name = ballNode.name {
            let frame = BallFrame(
                time: simulationTime,
                position: ballNode.presentation.position,
                velocity: physicsBody.velocity,
                angularVelocity: physicsBody.angularVelocity,
                state: newState
            )
            recorder.recordFrame(ballName: name, frame: frame)
        }
    }
    
    /// 检测球是否处于滑动状态
    private func isBallSliding(linearVelocity: SCNVector3, angularVelocity: SCNVector4) -> Bool {
        let v = SCNVector3(linearVelocity.x, linearVelocity.y, linearVelocity.z)
        let w = SCNVector3(angularVelocity.x, angularVelocity.y, angularVelocity.z)
        let contactVelocity = surfaceVelocity(linear: v, angular: w, radius: BallPhysics.radius)
        return contactVelocity.length() > 0.03
    }
    
    /// 应用滑动摩擦（解析式）
    private func applySlidingFriction(to physicsBody: SCNPhysicsBody, dt: Float) {
        let friction = SpinPhysics.slidingFriction
        let v = SCNVector3(physicsBody.velocity.x, physicsBody.velocity.y, physicsBody.velocity.z)
        let w = SCNVector3(physicsBody.angularVelocity.x, physicsBody.angularVelocity.y, physicsBody.angularVelocity.z)
        let rel = surfaceVelocity(linear: v, angular: w, radius: BallPhysics.radius)
        let relSpeed = rel.length()
        guard relSpeed > 0.0001 else { return }
        
        let uHat = rel.normalized()
        let decel = friction * 9.81
        let newV = v - uHat * (decel * dt)
        
        let up = SCNVector3(0, 1, 0)
        let deltaW = uHat.cross(up) * (-5.0 * decel * dt / (2.0 * BallPhysics.radius))
        let newW = w + deltaW
        
        physicsBody.velocity = newV
        physicsBody.angularVelocity = SCNVector4(newW.x, newW.y, newW.z, physicsBody.angularVelocity.w)
    }
    
    /// 应用滚动摩擦（解析式）
    private func applyRollingFriction(to physicsBody: SCNPhysicsBody, dt: Float) {
        let friction = SpinPhysics.rollingFriction
        let v = SCNVector3(physicsBody.velocity.x, physicsBody.velocity.y, physicsBody.velocity.z)
        let speed = v.length()
        guard speed > 0.0001 else { return }
        
        let vHat = v.normalized()
        let decel = friction * 9.81
        let newV = v - vHat * (decel * dt)
        physicsBody.velocity = newV
        
        let up = SCNVector3(0, 1, 0)
        let wRolling = up.cross(newV) * (1.0 / BallPhysics.radius)
        physicsBody.angularVelocity = SCNVector4(wRolling.x, wRolling.y, wRolling.z, physicsBody.angularVelocity.w)
    }
    
    /// 旋转衰减（解析式）
    /// 只衰减垂直旋转分量（y分量）
    private func applySpinDecay(to physicsBody: SCNPhysicsBody, dt: Float) {
        let angular = physicsBody.angularVelocity
        let alpha = 5 * SpinPhysics.spinFriction * 9.81 / (2 * BallPhysics.radius)
        
        // 只衰减 y 分量（垂直旋转）
        func decayYComponent(_ w: Float) -> Float {
            if abs(w) < 0.0001 { return 0 }
            let delta = min(abs(w), alpha * dt)
            return w - (w > 0 ? delta : -delta)
        }
        
        // X 和 Z 分量保持不变，只衰减 Y 分量
        let newX = angular.x
        let newY = decayYComponent(angular.y)
        let newZ = angular.z
        
        physicsBody.angularVelocity = SCNVector4(newX, newY, newZ, angular.w)
    }
    
    /// 检查所有球是否静止
    private func checkBallsAtRest() {
        guard let scene = scene else { return }
        
        var allAtRest = true
        
        // 检查母球
        if let cueBall = scene.cueBallNode,
           let body = cueBall.physicsBody {
            if !isAtRest(body) {
                allAtRest = false
            }
        }
        
        // 检查目标球
        for ball in scene.targetBallNodes {
            if let body = ball.physicsBody, !isAtRest(body) {
                allAtRest = false
                break
            }
        }
        
        if allAtRest {
            // 通知所有球已静止
            NotificationCenter.default.post(
                name: .ballsAtRest,
                object: nil
            )
        }
    }
    
    /// 检查物理体是否静止
    private func isAtRest(_ body: SCNPhysicsBody) -> Bool {
        let velocity = body.velocity
        let speed = sqrt(velocity.x * velocity.x + velocity.y * velocity.y + velocity.z * velocity.z)
        
        let angular = body.angularVelocity
        let angularSpeed = sqrt(angular.x * angular.x + angular.y * angular.y + angular.z * angular.z)
        
        return speed < 0.005 && angularSpeed < 0.1
    }
    
    // MARK: - Collision Handling
    
    /// 处理球与球碰撞
    func handleBallCollision(ballA: SCNNode, ballB: SCNNode, contactPoint: SCNVector3) {
        CollisionResolver.resolveBallBall(ballA: ballA, ballB: ballB)
    }
    
    
    /// 处理球与库边碰撞
    func handleCushionCollision(ball: SCNNode, cushion: SCNNode, contactPoint: SCNVector3, normal: SCNVector3) {
        CollisionResolver.resolveCushionCollision(ball: ball, normal: normal)
    }
    
    // MARK: - Trajectory Prediction
    
    /// 预测轨迹
    func predictTrajectory(
        from startPosition: SCNVector3,
        direction: SCNVector3,
        velocity: Float,
        spin: SCNVector4,
        steps: Int = 100
    ) -> [SCNVector3] {
        var trajectory: [SCNVector3] = []
        
        // Initialize state variables
        var position = startPosition
        var velocityVector = direction.normalized() * velocity
        var angularVelocity = SCNVector3(spin.x, spin.y, spin.z)
        var currentState: BallMotionState = .sliding
        
        // Constants
        let sampleInterval = AimingSystem.trajectoryTimeStep
        let maxTime = Float(steps) * sampleInterval
        let halfLength = TablePhysics.innerLength / 2
        let halfWidth = TablePhysics.innerWidth / 2
        let radius = BallPhysics.radius
        let cushionRestitution = TablePhysics.cushionRestitution
        
        var currentTime: Float = 0
        
        // Main loop
        while currentTime < maxTime {
            // Compute transition time for current state
            var transitionTime: Float = Float.infinity
            switch currentState {
            case .sliding:
                transitionTime = AnalyticalMotion.slideToRollTime(
                    velocity: velocityVector,
                    angularVelocity: angularVelocity,
                    radius: radius
                )
            case .rolling:
                transitionTime = AnalyticalMotion.rollToSpinTime(velocity: velocityVector)
            case .spinning:
                transitionTime = AnalyticalMotion.spinToStationaryTime(
                    angularVelocity: angularVelocity,
                    radius: radius
                )
            case .stationary, .pocketed:
                break
            }
            
            // Compute acceleration vector for CCD based on current state
            var acceleration = SCNVector3(0, 0, 0)
            switch currentState {
            case .sliding:
                let relVel = AnalyticalMotion.surfaceVelocity(
                    linear: velocityVector,
                    angular: angularVelocity,
                    radius: radius
                )
                let relSpeed = relVel.length()
                if relSpeed > 0.0001 {
                    let uHat = relVel.normalized()
                    let decel = SpinPhysics.slidingFriction * TablePhysics.gravity
                    acceleration = -uHat * decel
                }
            case .rolling:
                let speed = velocityVector.length()
                if speed > 0.0001 {
                    let vHat = velocityVector.normalized()
                    let decel = SpinPhysics.rollingFriction * TablePhysics.gravity
                    acceleration = -vHat * decel
                }
            case .spinning, .stationary, .pocketed:
                acceleration = SCNVector3(0, 0, 0)
            }
            
            // Find earliest cushion collision time using CCD
            var cushionTime: Float = Float.infinity
            var cushionNormal: SCNVector3?
            
            // Check four boundaries: ±halfLength (x), ±halfWidth (z)
            // Line equation: n·p = offset, where normals point outward and offsets are positive
            let boundaries: [(normal: SCNVector3, offset: Double)] = [
                (SCNVector3(1, 0, 0), Double(halfLength)),   // +x boundary (x = +halfLength)
                (SCNVector3(-1, 0, 0), Double(halfLength)),   // -x boundary (x = -halfLength)
                (SCNVector3(0, 0, 1), Double(halfWidth)),     // +z boundary (z = +halfWidth)
                (SCNVector3(0, 0, -1), Double(halfWidth))     // -z boundary (z = -halfWidth)
            ]
            
            for (normal, offset) in boundaries {
                if let collisionTime = CollisionDetector.ballLinearCushionTime(
                    p: position,
                    v: velocityVector,
                    a: acceleration,
                    lineNormal: normal,
                    lineOffset: offset,
                    R: Double(radius),
                    maxTime: Double(maxTime - currentTime)
                ) {
                    if collisionTime < cushionTime {
                        cushionTime = collisionTime
                        cushionNormal = normal
                    }
                }
            }
            
            // Determine dt = min(sampleInterval, transitionTime, cushionTime)
            var dt = sampleInterval
            var eventType: String = "sample"
            
            if transitionTime < dt {
                dt = transitionTime
                eventType = "transition"
            }
            
            if cushionTime < dt {
                dt = cushionTime
                eventType = "cushion"
            }
            
            // Ensure dt is positive and finite
            guard dt > 0 && dt.isFinite else {
                break
            }
            
            // Evolve state for dt using AnalyticalMotion
            switch currentState {
            case .sliding:
                let result = AnalyticalMotion.evolveSliding(
                    position: position,
                    velocity: velocityVector,
                    angularVelocity: angularVelocity,
                    dt: dt
                )
                position = result.position
                velocityVector = result.velocity
                angularVelocity = result.angularVelocity
                
            case .rolling:
                let result = AnalyticalMotion.evolveRolling(
                    position: position,
                    velocity: velocityVector,
                    angularVelocity: angularVelocity,
                    dt: dt
                )
                position = result.position
                velocityVector = result.velocity
                angularVelocity = result.angularVelocity
                
            case .spinning:
                let result = AnalyticalMotion.evolveSpinning(
                    position: position,
                    angularVelocity: angularVelocity,
                    dt: dt
                )
                position = result.position
                angularVelocity = result.angularVelocity
                
            case .stationary, .pocketed:
                break
            }
            
            // Handle state transition if dt equals transitionTime
            if eventType == "transition" {
                switch currentState {
                case .sliding:
                    currentState = .rolling
                case .rolling:
                    currentState = .spinning
                case .spinning:
                    currentState = .stationary
                default:
                    break
                }
            }
            
            // Handle cushion collision if dt equals cushionTime
            if eventType == "cushion", let normal = cushionNormal {
                // Reflect velocity on the normal
                let velocityDotNormal = velocityVector.x * normal.x + 
                                       velocityVector.y * normal.y + 
                                       velocityVector.z * normal.z
                velocityVector = velocityVector - normal * (2 * velocityDotNormal)
                velocityVector = velocityVector * cushionRestitution
            }
            
            // Add position to trajectory
            trajectory.append(position)
            
            // Update time
            currentTime += dt
            
            // Check stop conditions
            let speed = velocityVector.length()
            let angularSpeed = angularVelocity.length()
            
            if speed < 0.1 && angularSpeed < 0.1 {
                break
            }
            
            if currentState == .stationary || currentState == .pocketed {
                break
            }
        }
        
        return trajectory
    }
    
    /// 检查是否出界
    private func isOutOfBounds(_ position: SCNVector3) -> Bool {
        let halfLength = TablePhysics.innerLength / 2
        let halfWidth = TablePhysics.innerWidth / 2
        
        return abs(position.x) > halfLength || abs(position.z) > halfWidth
    }
    
    /// 计算反弹
    private func calculateBounce(position: SCNVector3, direction: SCNVector3) -> (SCNVector3, SCNVector3) {
        let halfLength = TablePhysics.innerLength / 2
        let halfWidth = TablePhysics.innerWidth / 2
        
        var newPosition = position
        var newDirection = direction
        
        // X方向反弹
        if abs(position.x) > halfLength {
            newPosition.x = position.x > 0 ? halfLength : -halfLength
            newDirection.x = -direction.x
        }
        
        // Z方向反弹
        if abs(position.z) > halfWidth {
            newPosition.z = position.z > 0 ? halfWidth : -halfWidth
            newDirection.z = -direction.z
        }
        
        return (newPosition, newDirection)
    }
    
    private func surfaceVelocity(linear: SCNVector3, angular: SCNVector3, radius: Float) -> SCNVector3 {
        let r = SCNVector3(0, -radius, 0)
        return linear + angular.cross(r)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let ballsAtRest = Notification.Name("ballsAtRest")
    static let ballPocketed = Notification.Name("ballPocketed")
    static let collision = Notification.Name("collision")
}
