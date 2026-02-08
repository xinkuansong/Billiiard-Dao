//
//  AnalyticalMotion.swift
//  BilliardTrainer
//
//  Analytical motion equations for sliding, rolling, and spinning states
//

import SceneKit

/// Analytical motion equations for billiard ball physics
struct AnalyticalMotion {
    
    // MARK: - Helper Functions
    
    /// Calculate surface velocity at contact point (xz plane)
    /// - Parameters:
    ///   - linear: Linear velocity vector (m/s)
    ///   - angular: Angular velocity vector (rad/s)
    ///   - radius: Ball radius (m)
    /// - Returns: Surface velocity vector at contact point
    static func surfaceVelocity(linear: SCNVector3, angular: SCNVector3, radius: Float) -> SCNVector3 {
        // Contact point is at bottom of ball: r = (0, -radius, 0)
        let r = SCNVector3(0, -radius, 0)
        // Surface velocity = linear velocity + angular velocity × contact point vector
        return linear + angular.cross(r)
    }
    
    /// Decay perpendicular spin (y-component only)
    /// - Parameters:
    ///   - angularVelocity: Current angular velocity (rad/s)
    ///   - dt: Time step (s)
    ///   - radius: Ball radius (m)
    ///   - spinFriction: Spin friction coefficient
    ///   - gravity: Gravitational acceleration (m/s²)
    /// - Returns: Updated angular velocity with decayed y-component
    static func decaySpin(
        angularVelocity: SCNVector3,
        dt: Float,
        radius: Float = BallPhysics.radius,
        spinFriction: Float = SpinPhysics.spinFriction,
        gravity: Float = TablePhysics.gravity
    ) -> SCNVector3 {
        let alpha = 5 * spinFriction * gravity / (2 * radius)
        let wy = angularVelocity.y
        
        // If spin is negligible, return zero
        if abs(wy) < 0.0001 {
            return SCNVector3(angularVelocity.x, 0, angularVelocity.z)
        }
        
        // Decay towards zero
        let delta = min(abs(wy), alpha * dt)
        let sign: Float = wy > 0 ? 1 : -1
        let newWy = wy - sign * delta
        
        return SCNVector3(angularVelocity.x, newWy, angularVelocity.z)
    }
    
    // MARK: - Motion Evolution Functions
    
    /// Evolve sliding motion state analytically
    /// - Parameters:
    ///   - position: Current position (m)
    ///   - velocity: Current linear velocity (m/s)
    ///   - angularVelocity: Current angular velocity (rad/s)
    ///   - dt: Time step (s)
    ///   - radius: Ball radius (m)
    ///   - slidingFriction: Sliding friction coefficient
    ///   - spinFriction: Spin friction coefficient
    ///   - gravity: Gravitational acceleration (m/s²)
    /// - Returns: Tuple of (newPosition, newVelocity, newAngularVelocity)
    static func evolveSliding(
        position: SCNVector3,
        velocity: SCNVector3,
        angularVelocity: SCNVector3,
        dt: Float,
        radius: Float = BallPhysics.radius,
        slidingFriction: Float = SpinPhysics.slidingFriction,
        spinFriction: Float = SpinPhysics.spinFriction,
        gravity: Float = TablePhysics.gravity
    ) -> (position: SCNVector3, velocity: SCNVector3, angularVelocity: SCNVector3) {
        // Calculate relative velocity at contact point
        let relVel = surfaceVelocity(linear: velocity, angular: angularVelocity, radius: radius)
        let relSpeed = relVel.length()
        
        guard relSpeed > 0.0001 else {
            // No sliding, return unchanged
            return (position, velocity, angularVelocity)
        }
        
        // Unit vector in direction of relative velocity
        let uHat = relVel.normalized()
        
        // Deceleration magnitude
        let decel = slidingFriction * gravity
        
        // Update position: r(t) = r₀ + v₀*t - 0.5*a*t²*û
        let newPosition = position + velocity * dt - uHat * (0.5 * decel * dt * dt)
        
        // Update velocity: v(t) = v₀ - a*t*û
        let newVelocity = velocity - uHat * (decel * dt)
        
        // Update angular velocity: ω(t) = ω₀ - (5/2R)*a*t*(û × ẑ)
        let up = SCNVector3(0, 1, 0)
        let deltaW = uHat.cross(up) * (-5.0 * decel * dt / (2.0 * radius))
        let newAngularVelocity = angularVelocity + deltaW
        
        // Decay perpendicular spin (y-component)
        let finalAngularVelocity = decaySpin(
            angularVelocity: newAngularVelocity,
            dt: dt,
            radius: radius,
            spinFriction: spinFriction,
            gravity: gravity
        )
        
        return (newPosition, newVelocity, finalAngularVelocity)
    }
    
    /// Evolve rolling motion state analytically
    /// - Parameters:
    ///   - position: Current position (m)
    ///   - velocity: Current linear velocity (m/s)
    ///   - angularVelocity: Current angular velocity (rad/s)
    ///   - dt: Time step (s)
    ///   - radius: Ball radius (m)
    ///   - rollingFriction: Rolling friction coefficient
    ///   - spinFriction: Spin friction coefficient
    ///   - gravity: Gravitational acceleration (m/s²)
    /// - Returns: Tuple of (newPosition, newVelocity, newAngularVelocity)
    static func evolveRolling(
        position: SCNVector3,
        velocity: SCNVector3,
        angularVelocity: SCNVector3,
        dt: Float,
        radius: Float = BallPhysics.radius,
        rollingFriction: Float = SpinPhysics.rollingFriction,
        spinFriction: Float = SpinPhysics.spinFriction,
        gravity: Float = TablePhysics.gravity
    ) -> (position: SCNVector3, velocity: SCNVector3, angularVelocity: SCNVector3) {
        let speed = velocity.length()
        
        guard speed > 0.0001 else {
            // No motion, return unchanged
            return (position, velocity, angularVelocity)
        }
        
        // Unit vector in direction of velocity
        let vHat = velocity.normalized()
        
        // Deceleration magnitude
        let decel = rollingFriction * gravity
        
        // Update position: r(t) = r₀ + v₀*t - 0.5*a*t²*v̂
        let newPosition = position + velocity * dt - vHat * (0.5 * decel * dt * dt)
        
        // Update velocity: v(t) = v₀ - a*t*v̂
        let newVelocity = velocity - vHat * (decel * dt)
        
        // Angular velocity matches rolling: ω = (1/R) * (ẑ × v)
        let up = SCNVector3(0, 1, 0)
        let wRolling = up.cross(newVelocity) * (1.0 / radius)
        
        // Preserve y-component (perpendicular spin) and decay it
        let currentWy = angularVelocity.y
        let decayedWy = decaySpin(
            angularVelocity: SCNVector3(0, currentWy, 0),
            dt: dt,
            radius: radius,
            spinFriction: spinFriction,
            gravity: gravity
        ).y
        
        let newAngularVelocity = SCNVector3(wRolling.x, decayedWy, wRolling.z)
        
        return (newPosition, newVelocity, newAngularVelocity)
    }
    
    /// Evolve spinning motion state analytically (only y-component spin)
    /// - Parameters:
    ///   - position: Current position (m, unchanged)
    ///   - angularVelocity: Current angular velocity (rad/s)
    ///   - dt: Time step (s)
    ///   - radius: Ball radius (m)
    ///   - spinFriction: Spin friction coefficient
    ///   - gravity: Gravitational acceleration (m/s²)
    /// - Returns: Updated angular velocity with decayed y-component
    static func evolveSpinning(
        position: SCNVector3,
        angularVelocity: SCNVector3,
        dt: Float,
        radius: Float = BallPhysics.radius,
        spinFriction: Float = SpinPhysics.spinFriction,
        gravity: Float = TablePhysics.gravity
    ) -> (position: SCNVector3, angularVelocity: SCNVector3) {
        // Only decay y-component (perpendicular spin)
        let newAngularVelocity = decaySpin(
            angularVelocity: angularVelocity,
            dt: dt,
            radius: radius,
            spinFriction: spinFriction,
            gravity: gravity
        )
        
        // Position remains unchanged during pure spinning
        return (position, newAngularVelocity)
    }
    
    // MARK: - Transition Time Helpers
    
    /// Calculate time until transition from sliding to rolling
    /// - Parameters:
    ///   - velocity: Current linear velocity (m/s)
    ///   - angularVelocity: Current angular velocity (rad/s)
    ///   - radius: Ball radius (m)
    ///   - slidingFriction: Sliding friction coefficient
    ///   - gravity: Gravitational acceleration (m/s²)
    /// - Returns: Time until transition (s), or infinity if no transition
    static func slideToRollTime(
        velocity: SCNVector3,
        angularVelocity: SCNVector3,
        radius: Float = BallPhysics.radius,
        slidingFriction: Float = SpinPhysics.slidingFriction,
        gravity: Float = TablePhysics.gravity
    ) -> Float {
        guard slidingFriction > 0 else {
            return Float.infinity
        }
        
        // Relative velocity at contact point
        let relVel = surfaceVelocity(linear: velocity, angular: angularVelocity, radius: radius)
        let relSpeed = relVel.length()
        
        guard relSpeed > 0.0001 else {
            // Already rolling
            return 0
        }
        
        // Time until relative velocity becomes zero: t = 2|v_rel| / (7 * μ_s * g)
        return 2 * relSpeed / (7 * slidingFriction * gravity)
    }
    
    /// Calculate time until transition from rolling to spinning
    /// - Parameters:
    ///   - velocity: Current linear velocity (m/s)
    ///   - rollingFriction: Rolling friction coefficient
    ///   - gravity: Gravitational acceleration (m/s²)
    /// - Returns: Time until transition (s), or infinity if no transition
    static func rollToSpinTime(
        velocity: SCNVector3,
        rollingFriction: Float = SpinPhysics.rollingFriction,
        gravity: Float = TablePhysics.gravity
    ) -> Float {
        guard rollingFriction > 0 else {
            return Float.infinity
        }
        
        let speed = velocity.length()
        
        guard speed > 0.0001 else {
            // Already stopped
            return 0
        }
        
        // Time until velocity becomes zero: t = |v| / (μ_r * g)
        return speed / (rollingFriction * gravity)
    }
    
    /// Calculate time until transition from spinning to stationary
    /// - Parameters:
    ///   - angularVelocity: Current angular velocity (rad/s)
    ///   - radius: Ball radius (m)
    ///   - spinFriction: Spin friction coefficient
    ///   - gravity: Gravitational acceleration (m/s²)
    /// - Returns: Time until transition (s), or infinity if no transition
    static func spinToStationaryTime(
        angularVelocity: SCNVector3,
        radius: Float = BallPhysics.radius,
        spinFriction: Float = SpinPhysics.spinFriction,
        gravity: Float = TablePhysics.gravity
    ) -> Float {
        guard spinFriction > 0 else {
            return Float.infinity
        }
        
        // Only y-component (perpendicular spin) matters
        let wy = abs(angularVelocity.y)
        
        guard wy > 0.0001 else {
            // Already stationary
            return 0
        }
        
        // Time until y-component becomes zero: t = |w_y| * (2/5) * R / (μ_sp * g)
        return wy * 2.0 / 5.0 * radius / (spinFriction * gravity)
    }
}
