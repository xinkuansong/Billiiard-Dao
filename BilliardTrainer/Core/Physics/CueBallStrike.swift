//
//  CueBallStrike.swift
//  BilliardTrainer
//
//  杆-球碰撞模型 — 基于 pooltool instantaneous_point 模型
//  参考: Alciatore TP_A-30/A-31
//

import SceneKit

struct CueBallStrike {
    
    /// 根据击打点和力度计算母球初始状态
    ///
    /// 移植自 pooltool stick_ball/instantaneous_point
    ///
    /// - Parameters:
    ///   - V0: 球杆击球速度 (m/s)
    ///   - phi: 击球方向角 (弧度, 在台面XZ平面内, 0 = +X方向)
    ///   - theta: 球杆仰角 (弧度, 0 = 水平, 正值 = 杆尾抬高)
    ///   - a: 水平击打偏移 (-1..1, 正值 = 左塞/left english)
    ///   - b: 垂直击打偏移 (-1..1, 正值 = 高杆/top spin)
    /// - Returns: 母球初始速度和角速度
    static func strike(
        V0: Float,
        phi: Float,
        theta: Float = 0,
        a: Float,
        b: Float
    ) -> (velocity: SCNVector3, angularVelocity: SCNVector3) {
        let R = BallPhysics.radius
        let m = BallPhysics.mass
        let M = CuePhysics.mass
        let I_m: Float = (2.0 / 5.0) * R * R  // moment of inertia / mass
        
        // Effective contact point (adjusted for tip radius)
        let tipR = CuePhysics.tipRadius
        let a_eff = a / (1.0 + tipR / R)
        let b_eff = b / (1.0 + tipR / R)
        let c_sq = max(0, 1.0 - a_eff * a_eff - b_eff * b_eff)
        let c = sqrtf(c_sq)
        
        // Transform contact point from cue frame to ball frame
        // Cue frame: cue axis along -y, elevation theta rotates around x
        let cosT = cosf(theta)
        let sinT = sinf(theta)
        let ball_a = a_eff
        let ball_b = sinT * c + cosT * b_eff
        let ball_c = cosT * c - sinT * b_eff
        
        // Ball velocity magnitude
        let temp = ball_a * ball_a
            + (ball_b * cosT) * (ball_b * cosT)
            + (ball_c * sinT) * (ball_c * sinT)
            - 2.0 * ball_b * ball_c * cosT * sinT
        let denominator = 1.0 + m / M + temp / I_m
        let v = 2.0 * V0 / denominator
        
        // Linear velocity in ball frame (cue shoots along -y in ball frame)
        // Only horizontal component matters for table-plane motion
        let vx_ball: Float = 0
        let vy_ball: Float = 0  // vertical component ignored (stays on table)
        let vz_ball: Float = -v * cosT
        
        // Angular velocity in SceneKit ball frame (y-up)
        // Derived from omega ∝ Q × F where Q = [ball_a, ball_b, ball_c],
        // F = [0, -sinT, -cosT] in SceneKit's (x=side, y=up, z=forward) frame
        let wx_ball = (v / I_m) * (-ball_b * cosT + ball_c * sinT)
        let wy_ball = (v / I_m) * (ball_a * cosT)
        let wz_ball = (v / I_m) * (-ball_a * sinT)
        
        // Rotate from ball frame to table frame by phi
        // Ball frame z-axis aligns with initial cue direction
        // Rotate around Y axis by phi to get table coordinates
        let ballVelocity = SCNVector3(vx_ball, vy_ball, vz_ball)
        let ballAngularVelocity = SCNVector3(wx_ball, wy_ball, wz_ball)
        
        let velocity = ballVelocity.rotatedY(phi)
        let angularVelocity = ballAngularVelocity.rotatedY(phi)
        
        return (velocity, angularVelocity)
    }
    
    /// 计算 Squirt 角（侧旋导致母球偏离瞄准方向的角度）
    ///
    /// 移植自 pooltool squirt.py / get_squirt_angle
    /// 参考: Alciatore TP_A-31
    ///
    /// - Parameters:
    ///   - a: 水平击打偏移 (-1..1, 正值 = 左塞)
    ///   - throttle: Squirt 强度缩放 (0..1, 默认1.0)
    /// - Returns: Squirt 偏移角 (弧度, 负值 = 向右偏)
    static func squirtAngle(a: Float, throttle: Float = 1.0) -> Float {
        guard abs(a) > 0.001 else { return 0 }
        
        let m_r = BallPhysics.mass / CuePhysics.endMass
        let A = 1.0 - a * a
        let numerator = 2.5 * a * sqrtf(max(0, A))
        let denominator = 1.0 + m_r + 2.5 * A
        return -throttle * atan2f(numerator, denominator)
    }
    
    /// 计算考虑 squirt 后的实际击球方向
    ///
    /// - Parameters:
    ///   - aimDirection: 瞄准方向 (归一化)
    ///   - spinX: 水平击打偏移 (-1..1)
    /// - Returns: 实际母球运动方向 (归一化)
    static func actualDirection(aimDirection: SCNVector3, spinX: Float) -> SCNVector3 {
        let squirt = squirtAngle(a: spinX)
        guard abs(squirt) > 0.0001 else { return aimDirection }
        
        // Rotate aim direction around Y axis by squirt angle
        return aimDirection.rotatedY(squirt)
    }
    
    /// 便捷方法：根据瞄准方向、力度和打点计算完整的击球结果
    ///
    /// - Parameters:
    ///   - aimDirection: 瞄准方向 (XZ平面, 归一化)
    ///   - velocity: 击球速度 (m/s)
    ///   - spinX: 水平打点 (-1..1, 正=左塞)
    ///   - spinY: 垂直打点 (-1..1, 正=高杆)
    ///   - elevation: 球杆仰角 (弧度, 默认0)
    /// - Returns: 母球初始速度、角速度和squirt角
    static func executeStrike(
        aimDirection: SCNVector3,
        velocity: Float,
        spinX: Float,
        spinY: Float,
        elevation: Float = 0
    ) -> (velocity: SCNVector3, angularVelocity: SCNVector3, squirtAngle: Float) {
        // Calculate phi from aim direction.
        // Base forward vector in this strike model is -Z, so Z needs sign flip
        // to map velocity direction consistently with aimDirection.
        let phi = atan2f(aimDirection.x, -aimDirection.z)
        
        // Get squirt angle
        let squirt = squirtAngle(a: spinX)
        
        // Apply squirt to the direction angle
        let actualPhi = phi + squirt
        
        // Calculate strike
        let result = strike(
            V0: velocity,
            phi: actualPhi,
            theta: elevation,
            a: spinX,
            b: spinY
        )
        
        return (result.velocity, result.angularVelocity, squirt)
    }
}
