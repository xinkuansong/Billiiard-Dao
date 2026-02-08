//
//  CollisionResolver.swift
//  BilliardTrainer
//
//  碰撞解析模型（球-球、球-库边）
//

import SceneKit

struct CollisionResolver {
    
    // MARK: - Pure Computation Results
    
    /// Result of a ball-ball collision resolution
    struct BallBallResult {
        let velA: SCNVector3
        let velB: SCNVector3
        let angVelA: SCNVector3
        let angVelB: SCNVector3
    }
    
    /// Result of a ball-cushion collision resolution
    struct CushionResult {
        let velocity: SCNVector3
        let angularVelocity: SCNVector3
    }
    
    // MARK: - Pure Computation Functions (no SCNNode dependency)
    
    /// 球-球摩擦非弹性碰撞 — 纯计算版本（Alciatore frictional inelastic model）
    static func resolveBallBallPure(
        posA: SCNVector3, posB: SCNVector3,
        velA: SCNVector3, velB: SCNVector3,
        angVelA: SCNVector3, angVelB: SCNVector3
    ) -> BallBallResult {
        let delta = posB - posA
        let theta = atan2f(delta.z, delta.x)
        
        // Rotate into collision frame (x = line-of-centers)
        let vA_r = rotateY(velA, angle: -theta)
        let vB_r = rotateY(velB, angle: -theta)
        let wA_r = rotateY(angVelA, angle: -theta)
        let wB_r = rotateY(angVelB, angle: -theta)
        
        let e = BallPhysics.restitution
        let R = BallPhysics.radius
        let M = BallPhysics.mass
        
        // Compute normal velocity exchange using restitution
        let v1n = 0.5 * ((1 - e) * vA_r.x + (1 + e) * vB_r.x)
        let v2n = 0.5 * ((1 + e) * vA_r.x + (1 - e) * vB_r.x)
        
        var vA_f = vA_r
        var vB_f = vB_r
        vA_f.x = v1n
        vB_f.x = v2n
        
        // Compute relative surface velocity at contact
        let contactA = surfaceVelocity(linear: vA_r, angular: wA_r, radius: R, normal: SCNVector3(1, 0, 0))
        let contactB = surfaceVelocity(linear: vB_r, angular: wB_r, radius: R, normal: SCNVector3(-1, 0, 0))
        let v_rel = contactA - contactB
        
        let v_rel_mag = v_rel.length()
        let eps: Float = 0.0001
        
        var wA_f: SCNVector3
        var wB_f: SCNVector3
        
        if v_rel_mag > eps {
            // Sliding case: velocity-dependent friction
            let u_b = 0.009951 + 0.108 * expf(-1.088 * v_rel_mag)
            let tHat = v_rel.normalized()
            let J_n = M * (1 + e) * (vB_r.x - vA_r.x)
            let J_t_max = u_b * abs(J_n)
            let J_t_needed = M * v_rel_mag / 2.0
            let J_t_applied = min(J_t_max, J_t_needed)
            
            let tangentialScale = J_t_applied / M
            let deltaV_t = (-tHat) * tangentialScale
            vA_f = vA_f + deltaV_t
            vB_f = vB_f - deltaV_t
            
            let rA = SCNVector3(R, 0, 0)
            let rB = SCNVector3(-R, 0, 0)
            let J_t_vec = (-tHat) * J_t_applied
            let inertiaScale = 5.0 / (2.0 * M * R * R)
            let dwA = rA.cross(J_t_vec) * inertiaScale
            let dwB = rB.cross(-J_t_vec) * inertiaScale
            
            wA_f = wA_r + dwA
            wB_f = wB_r + dwB
            
            // Check for slip reversal
            let contactA_new = surfaceVelocity(linear: vA_f, angular: wA_f, radius: R, normal: SCNVector3(1, 0, 0))
            let contactB_new = surfaceVelocity(linear: vB_f, angular: wB_f, radius: R, normal: SCNVector3(-1, 0, 0))
            let v_rel_new = contactA_new - contactB_new
            
            if v_rel.dot(v_rel_new) < 0 {
                let v_rel_new_mag = v_rel_new.length()
                if v_rel_new_mag > eps {
                    let tHat_new = v_rel_new.normalized()
                    let u_b_new = 0.009951 + 0.108 * expf(-1.088 * v_rel_new_mag)
                    let J_t_correction = min(u_b_new * abs(J_n), M * v_rel_new_mag / 2.0)
                    let correctionScale = J_t_correction / M
                    let deltaV_t_corr = (-tHat_new) * correctionScale
                    vA_f = vA_f + deltaV_t_corr
                    vB_f = vB_f - deltaV_t_corr
                    
                    let J_t_corr_vec = (-tHat_new) * J_t_correction
                    wA_f = wA_f + rA.cross(J_t_corr_vec) * inertiaScale
                    wB_f = wB_f + rB.cross(-J_t_corr_vec) * inertiaScale
                }
            }
        } else {
            // No-slip case: Alciatore formulas
            let unitX = SCNVector3(1, 0, 0)
            var v_diff = vA_f - vB_f
            v_diff.x = 0
            let w_sum = wA_r + wB_r
            let tangentialAdjust = v_diff + w_sum.cross(unitX) * R
            var D_v1_t = tangentialAdjust * (-(1.0 / 7.0))
            D_v1_t.x = 0
            
            let angularAdjust = (unitX.cross(v_diff) / R) + w_sum
            let D_w1 = angularAdjust * (-(5.0 / 14.0))
            
            vA_f = vA_f + D_v1_t
            vB_f = vB_f - D_v1_t
            wA_f = wA_r + D_w1
            wB_f = wB_r + D_w1
        }
        
        // Rotate back to world frame
        return BallBallResult(
            velA: rotateY(vA_f, angle: theta),
            velB: rotateY(vB_f, angle: theta),
            angVelA: rotateY(wA_f, angle: theta),
            angVelB: rotateY(wB_f, angle: theta)
        )
    }
    
    /// 球-库边碰撞 — 纯计算版本（Mathavan 2010 model）
    static func resolveCushionCollisionPure(
        velocity: SCNVector3,
        angularVelocity: SCNVector3,
        normal: SCNVector3
    ) -> CushionResult {
        let v = velocity
        let w = angularVelocity
        
        let nNorm = normal.normalized()
        let v_dot_n = v.dot(nNorm)
        let n = (v_dot_n > 0) ? nNorm : -nNorm
        
        let n_horizontal = SCNVector3(n.x, 0, n.z)
        let n_horizontal_len = n_horizontal.length()
        
        if n_horizontal_len <= 0.001 {
            // Nearly vertical normal fallback
            let t_horizontal = SCNVector3(1, 0, 0)
            let n_h_vertical = SCNVector3(0, 0, 1)
            let up = SCNVector3(0, 1, 0)
            
            let result = CushionCollisionModel.solve(
                vx: v.dot(t_horizontal),
                vy: v.dot(n),
                omega_x: w.dot(t_horizontal),
                omega_y: w.dot(n_h_vertical),
                omega_z: w.dot(up),
                mu_s: TablePhysics.clothFriction,
                mu_w: TablePhysics.cushionFriction,
                ee: TablePhysics.cushionRestitution,
                h: TablePhysics.cushionHeight,
                R: BallPhysics.radius,
                M: BallPhysics.mass
            )
            
            let v_final = (t_horizontal * result.vx) + (n * result.vy)
            let w_final = (t_horizontal * result.omega_x) + (n_h_vertical * result.omega_y) + (up * result.omega_z)
            return CushionResult(velocity: v_final, angularVelocity: w_final)
        }
        
        let n_h = n_horizontal.normalized()
        let t_horizontal = SCNVector3(-n_h.z, 0, n_h.x)
        let up = SCNVector3(0, 1, 0)
        
        let result = CushionCollisionModel.solve(
            vx: v.dot(t_horizontal),
            vy: v.dot(n_h),
            omega_x: w.dot(t_horizontal),
            omega_y: w.dot(n_h),
            omega_z: w.dot(up),
            mu_s: TablePhysics.clothFriction,
            mu_w: TablePhysics.cushionFriction,
            ee: TablePhysics.cushionRestitution,
            h: TablePhysics.cushionHeight,
            R: BallPhysics.radius,
            M: BallPhysics.mass
        )
        
        let v_final = (t_horizontal * result.vx) + (n_h * result.vy)
        let w_final = (t_horizontal * result.omega_x) + (n_h * result.omega_y) + (up * result.omega_z)
        return CushionResult(velocity: v_final, angularVelocity: w_final)
    }
    
    // MARK: - SCNNode Wrapper Functions (for SceneKit integration)
    
    /// 球-球碰撞 — SCNNode 包装版本
    static func resolveBallBall(ballA: SCNNode, ballB: SCNNode) {
        guard let bodyA = ballA.physicsBody,
              let bodyB = ballB.physicsBody else { return }
        
        let result = resolveBallBallPure(
            posA: ballA.presentation.position,
            posB: ballB.presentation.position,
            velA: bodyA.velocity,
            velB: bodyB.velocity,
            angVelA: SCNVector3(bodyA.angularVelocity.x, bodyA.angularVelocity.y, bodyA.angularVelocity.z),
            angVelB: SCNVector3(bodyB.angularVelocity.x, bodyB.angularVelocity.y, bodyB.angularVelocity.z)
        )
        
        bodyA.velocity = result.velA
        bodyB.velocity = result.velB
        bodyA.angularVelocity = SCNVector4(result.angVelA.x, result.angVelA.y, result.angVelA.z, 0)
        bodyB.angularVelocity = SCNVector4(result.angVelB.x, result.angVelB.y, result.angVelB.z, 0)
    }
    
    /// 球-库边碰撞 — SCNNode 包装版本
    static func resolveCushionCollision(ball: SCNNode, normal: SCNVector3) {
        guard let body = ball.physicsBody else { return }
        
        let result = resolveCushionCollisionPure(
            velocity: body.velocity,
            angularVelocity: SCNVector3(body.angularVelocity.x, body.angularVelocity.y, body.angularVelocity.z),
            normal: normal
        )
        
        body.velocity = result.velocity
        body.angularVelocity = SCNVector4(result.angularVelocity.x, result.angularVelocity.y, result.angularVelocity.z, 0)
    }
    
    // MARK: - Private Helpers
    
    private static func surfaceVelocity(linear: SCNVector3, angular: SCNVector3, radius: Float, normal: SCNVector3) -> SCNVector3 {
        let r = normal * radius
        return linear + angular.cross(r)
    }
    
    private static func rotateY(_ v: SCNVector3, angle: Float) -> SCNVector3 {
        let cosA = cosf(angle)
        let sinA = sinf(angle)
        return SCNVector3(v.x * cosA - v.z * sinA, v.y, v.x * sinA + v.z * cosA)
    }
    
    private static func vector4(from v: SCNVector3) -> SCNVector4 {
        return SCNVector4(v.x, v.y, v.z, 0)
    }
}
