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
    
    // MARK: - Initialization
    
    init(scene: BilliardScene) {
        self.scene = scene
    }
    
    // MARK: - Start/Stop
    
    /// 开始物理模拟
    func startSimulation() {
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
    
    // MARK: - Update Loop
    
    /// 物理更新循环
    private func update() {
        guard let scene = scene else { return }
        
        // 更新母球旋转效果
        if let cueBall = scene.cueBallNode {
            updateSpinEffects(for: cueBall)
        }
        
        // 更新所有目标球
        for ball in scene.targetBallNodes {
            updateSpinEffects(for: ball)
        }
        
        // 检查是否所有球都停止
        checkBallsAtRest()
    }
    
    /// 更新旋转效果
    private func updateSpinEffects(for ballNode: SCNNode) {
        guard let physicsBody = ballNode.physicsBody else { return }
        
        let velocity = physicsBody.velocity
        let angularVelocity = physicsBody.angularVelocity
        
        // 速度阈值检查
        let speed = sqrt(velocity.x * velocity.x + velocity.y * velocity.y + velocity.z * velocity.z)
        if speed < 0.01 {
            return
        }
        
        // 计算滑动/滚动状态
        let isSliding = isballSliding(
            linearVelocity: velocity,
            angularVelocity: angularVelocity
        )
        
        if isSliding {
            // 滑动状态：应用滑动摩擦，旋转衰减
            applySliFriction(to: physicsBody)
        } else {
            // 纯滚动状态：应用滚动摩擦
            applyRollingFriction(to: physicsBody)
        }
        
        // 旋转衰减
        decaySpin(physicsBody: physicsBody)
    }
    
    /// 检测球是否处于滑动状态
    private func isballSliding(linearVelocity: SCNVector3, angularVelocity: SCNVector4) -> Bool {
        // 纯滚动条件：v = ω × r
        let expectedAngularSpeed = sqrt(linearVelocity.x * linearVelocity.x + linearVelocity.z * linearVelocity.z) / BallPhysics.radius
        
        let actualAngularSpeed = sqrt(
            angularVelocity.x * angularVelocity.x +
            angularVelocity.y * angularVelocity.y +
            angularVelocity.z * angularVelocity.z
        )
        
        // 如果角速度与期望值相差较大，则为滑动
        return abs(actualAngularSpeed - expectedAngularSpeed) > 5.0
    }
    
    /// 应用滑动摩擦
    private func applySliFriction(to physicsBody: SCNPhysicsBody) {
        let friction = SpinPhysics.slidingFriction
        let velocity = physicsBody.velocity
        
        // 计算摩擦力方向（与速度相反）
        let speed = sqrt(velocity.x * velocity.x + velocity.z * velocity.z)
        if speed > 0.01 {
            let frictionForce = SCNVector3(
                -velocity.x / speed * friction * Float(updateFrequency),
                0,
                -velocity.z / speed * friction * Float(updateFrequency)
            )
            physicsBody.applyForce(frictionForce, asImpulse: true)
        }
    }
    
    /// 应用滚动摩擦
    private func applyRollingFriction(to physicsBody: SCNPhysicsBody) {
        let friction = SpinPhysics.rollingFriction
        let velocity = physicsBody.velocity
        
        // 滚动摩擦较小
        let speed = sqrt(velocity.x * velocity.x + velocity.z * velocity.z)
        if speed > 0.005 {
            let frictionForce = SCNVector3(
                -velocity.x / speed * friction * Float(updateFrequency),
                0,
                -velocity.z / speed * friction * Float(updateFrequency)
            )
            physicsBody.applyForce(frictionForce, asImpulse: true)
        }
    }
    
    /// 旋转衰减
    private func decaySpin(physicsBody: SCNPhysicsBody) {
        let decay = SpinPhysics.spinDecayRate
        let angular = physicsBody.angularVelocity
        
        physicsBody.angularVelocity = SCNVector4(
            angular.x * decay,
            angular.y * decay,
            angular.z * decay,
            angular.w
        )
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
        // 获取碰撞前的旋转状态
        guard let bodyA = ballA.physicsBody,
              let bodyB = ballB.physicsBody else { return }
        
        // 旋转传递计算
        transferSpin(from: bodyA, to: bodyB, at: contactPoint)
    }
    
    /// 旋转传递
    private func transferSpin(from source: SCNPhysicsBody, to target: SCNPhysicsBody, at contactPoint: SCNVector3) {
        let sourceAngular = source.angularVelocity
        
        // 侧旋部分传递
        let sideSpinTransfer = sourceAngular.y * SpinPhysics.spinToVelocityRatio * 0.3
        
        // 应用到目标球
        let currentAngular = target.angularVelocity
        target.angularVelocity = SCNVector4(
            currentAngular.x,
            currentAngular.y + sideSpinTransfer,
            currentAngular.z,
            currentAngular.w
        )
    }
    
    /// 处理球与库边碰撞
    func handleCushionCollision(ball: SCNNode, cushion: SCNNode, contactPoint: SCNVector3, normal: SCNVector3) {
        guard let body = ball.physicsBody else { return }
        
        // 获取塞的方向
        let sideSpinDirection = body.angularVelocity.y > 0 ? 1 : -1
        let sideSpinMagnitude = abs(body.angularVelocity.y)
        
        // 库边对塞的修正
        if sideSpinMagnitude > 5.0 {
            let correction = Float(sideSpinDirection) * sideSpinMagnitude * SpinPhysics.cushionSpinCorrectionFactor
            
            // 根据库边方向计算修正力
            let correctionForce: SCNVector3
            if abs(normal.x) > abs(normal.z) {
                // 左右库边
                correctionForce = SCNVector3(0, 0, correction * 0.01)
            } else {
                // 上下库边
                correctionForce = SCNVector3(correction * 0.01, 0, 0)
            }
            
            body.applyForce(correctionForce, asImpulse: true)
        }
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
        var position = startPosition
        var currentDirection = direction.normalized()
        var currentVelocity = velocity
        
        for _ in 0..<steps {
            // 简化的轨迹预测
            let step = currentDirection * currentVelocity * AimingSystem.trajectoryTimeStep
            position = position + step
            
            // 速度衰减
            currentVelocity *= 0.995
            
            // 边界检测
            if isOutOfBounds(position) {
                // 计算反弹
                let (newPos, newDir) = calculateBounce(position: position, direction: currentDirection)
                position = newPos
                currentDirection = newDir
                currentVelocity *= TablePhysics.cushionRestitution
            }
            
            trajectory.append(position)
            
            // 速度过小时停止
            if currentVelocity < 0.1 {
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
}

// MARK: - Notification Names

extension Notification.Name {
    static let ballsAtRest = Notification.Name("ballsAtRest")
    static let ballPocketed = Notification.Name("ballPocketed")
    static let collision = Notification.Name("collision")
}
