//
//  CushionCollisionModel.swift
//  BilliardTrainer
//
//  Mathavan 2010 cushion collision model (impulse integration)
//  Based on: Mathavan S, Jackson MR, Parkin RM. A theoretical analysis of billiard
//  ball-cushion dynamics under cushion impacts. Proceedings of the Institution of
//  Mechanical Engineers, Part C. 2010;224(9):1863-1873.
//

import Foundation

/// Mathavan 2010 cushion collision model implementation
struct CushionCollisionModel {
    
    // MARK: - Main Solve Function
    
    /// Solve the cushion collision using Mathavan 2010 model
    ///
    /// - Parameters:
    ///   - vx: Initial x-velocity (tangential to cushion, in cushion-normal frame)
    ///   - vy: Initial y-velocity (normal to cushion, positive = approaching)
    ///   - omega_x: Initial x-angular velocity (around x-axis)
    ///   - omega_y: Initial y-angular velocity (around y-axis)
    ///   - omega_z: Initial z-angular velocity (around z-axis)
    ///   - mu_s: Sliding friction coefficient between ball and table
    ///   - mu_w: Sliding friction coefficient between ball and cushion
    ///   - ee: Coefficient of restitution
    ///   - h: Height of the cushion (contact point height)
    ///   - R: Ball radius
    ///   - M: Ball mass
    ///   - maxSteps: Maximum number of integration steps
    ///   - deltaP: Impulse step size
    /// - Returns: Tuple of (vx, vy, omega_x, omega_y, omega_z) after collision
    static func solve(
        vx: Float,
        vy: Float,
        omega_x: Float,
        omega_y: Float,
        omega_z: Float,
        mu_s: Float,
        mu_w: Float,
        ee: Float,
        h: Float,
        R: Float,
        M: Float,
        maxSteps: Int = 5000,
        deltaP: Float = 0.0001
    ) -> (vx: Float, vy: Float, omega_x: Float, omega_y: Float, omega_z: Float) {
        
        // Calculate contact angle
        let (sinTheta, cosTheta) = getSinAndCosTheta(h: h, R: R)
        
        // Run compression phase
        let compressionResult = compressionPhase(
            vx: vx,
            vy: vy,
            omega_x: omega_x,
            omega_y: omega_y,
            omega_z: omega_z,
            mu_s: mu_s,
            mu_w: mu_w,
            sinTheta: sinTheta,
            cosTheta: cosTheta,
            R: R,
            M: M,
            maxSteps: maxSteps,
            deltaP: deltaP
        )
        
        // Calculate target work for rebound (e^2 * compression work)
        let targetWorkRebound = ee * ee * compressionResult.totalWork
        
        // Run restitution phase
        let restitutionResult = restitutionPhase(
            vx: compressionResult.vx,
            vy: compressionResult.vy,
            omega_x: compressionResult.omega_x,
            omega_y: compressionResult.omega_y,
            omega_z: compressionResult.omega_z,
            mu_s: mu_s,
            mu_w: mu_w,
            sinTheta: sinTheta,
            cosTheta: cosTheta,
            R: R,
            M: M,
            targetWorkRebound: targetWorkRebound,
            maxSteps: maxSteps,
            deltaP: deltaP
        )
        
        return (
            vx: restitutionResult.vx,
            vy: restitutionResult.vy,
            omega_x: restitutionResult.omega_x,
            omega_y: restitutionResult.omega_y,
            omega_z: restitutionResult.omega_z
        )
    }
    
    // MARK: - Helper Functions
    
    /// Calculate sin and cos of contact angle theta
    /// - Parameters:
    ///   - h: Height of cushion contact point
    ///   - R: Ball radius
    /// - Returns: (sin(theta), cos(theta))
    private static func getSinAndCosTheta(h: Float, R: Float) -> (sinTheta: Float, cosTheta: Float) {
        var sinTheta = (h - R) / R
        // Clamp sinTheta to [-1,1] to avoid NaN in sqrt
        sinTheta = max(-1.0, min(1.0, sinTheta))
        let cosTheta = sqrtf(1 - sinTheta * sinTheta)
        return (sinTheta, cosTheta)
    }
    
    /// Calculate slip speeds and angles at cushion (I) and table (C)
    /// - Parameters:
    ///   - R: Ball radius
    ///   - sinTheta: Sine of contact angle
    ///   - cosTheta: Cosine of contact angle
    ///   - vx: x-velocity
    ///   - vy: y-velocity
    ///   - omega_x: x-angular velocity
    ///   - omega_y: y-angular velocity
    ///   - omega_z: z-angular velocity
    /// - Returns: (slipSpeed, slipAngle, slipSpeedPrime, slipAnglePrime)
    private static func calculateSlipSpeedsAndAngles(
        R: Float,
        sinTheta: Float,
        cosTheta: Float,
        vx: Float,
        vy: Float,
        omega_x: Float,
        omega_y: Float,
        omega_z: Float
    ) -> (slipSpeed: Float, slipAngle: Float, slipSpeedPrime: Float, slipAnglePrime: Float) {
        
        // Velocities at the cushion (I)
        let v_xI = vx + omega_y * R * sinTheta - omega_z * R * cosTheta
        let v_yI = -vy * sinTheta + omega_x * R
        
        // Velocities at the table (C)
        let v_xC = vx - omega_y * R
        let v_yC = vy + omega_x * R
        
        // Calculate slip speed and angle at the cushion (I)
        let slipSpeed = sqrtf(v_xI * v_xI + v_yI * v_yI)
        var slipAngle = atan2f(v_yI, v_xI)
        if slipAngle < 0 {
            slipAngle += 2 * Float.pi
        }
        
        // Calculate slip speed and angle at the table (C)
        let slipSpeedPrime = sqrtf(v_xC * v_xC + v_yC * v_yC)
        var slipAnglePrime = atan2f(v_yC, v_xC)
        if slipAnglePrime < 0 {
            slipAnglePrime += 2 * Float.pi
        }
        
        return (slipSpeed, slipAngle, slipSpeedPrime, slipAnglePrime)
    }
    
    /// Update centroid velocity components
    /// - Parameters:
    ///   - M: Ball mass
    ///   - mu_s: Table friction coefficient
    ///   - mu_w: Cushion friction coefficient
    ///   - sinTheta: Sine of contact angle
    ///   - cosTheta: Cosine of contact angle
    ///   - vx: Current x-velocity
    ///   - vy: Current y-velocity
    ///   - slipAngle: Slip angle at cushion
    ///   - slipAnglePrime: Slip angle at table
    ///   - deltaP: Impulse increment
    /// - Returns: (vx_new, vy_new)
    private static func updateVelocity(
        M: Float,
        mu_s: Float,
        mu_w: Float,
        sinTheta: Float,
        cosTheta: Float,
        vx: Float,
        vy: Float,
        slipAngle: Float,
        slipAnglePrime: Float,
        deltaP: Float
    ) -> (vx: Float, vy: Float) {
        
        // Update vx
        let vx_new = vx - (1.0 / M) * (
            mu_w * cosf(slipAngle) +
            mu_s * cosf(slipAnglePrime) * (sinTheta + mu_w * sinf(slipAngle) * cosTheta)
        ) * deltaP
        
        // Update vy
        let vy_new = vy - (1.0 / M) * (
            cosTheta -
            mu_w * sinTheta * sinf(slipAngle) +
            mu_s * sinf(slipAnglePrime) * (sinTheta + mu_w * sinf(slipAngle) * cosTheta)
        ) * deltaP
        
        return (vx_new, vy_new)
    }
    
    /// Update angular velocity components
    /// - Parameters:
    ///   - M: Ball mass
    ///   - R: Ball radius
    ///   - mu_s: Table friction coefficient
    ///   - mu_w: Cushion friction coefficient
    ///   - sinTheta: Sine of contact angle
    ///   - cosTheta: Cosine of contact angle
    ///   - omega_x: Current x-angular velocity
    ///   - omega_y: Current y-angular velocity
    ///   - omega_z: Current z-angular velocity
    ///   - slipAngle: Slip angle at cushion
    ///   - slipAnglePrime: Slip angle at table
    ///   - deltaP: Impulse increment
    /// - Returns: (omega_x_new, omega_y_new, omega_z_new)
    private static func updateAngularVelocity(
        M: Float,
        R: Float,
        mu_s: Float,
        mu_w: Float,
        sinTheta: Float,
        cosTheta: Float,
        omega_x: Float,
        omega_y: Float,
        omega_z: Float,
        slipAngle: Float,
        slipAnglePrime: Float,
        deltaP: Float
    ) -> (omega_x: Float, omega_y: Float, omega_z: Float) {
        
        let factor = 5.0 / (2.0 * M * R)
        
        let omega_x_new = omega_x + (-factor) * (
            mu_w * sinf(slipAngle) +
            mu_s * sinf(slipAnglePrime) * (sinTheta + mu_w * sinf(slipAngle) * cosTheta)
        ) * deltaP
        
        let omega_y_new = omega_y + (-factor) * (
            mu_w * cosf(slipAngle) * sinTheta -
            mu_s * cosf(slipAnglePrime) * (sinTheta + mu_w * sinf(slipAngle) * cosTheta)
        ) * deltaP
        
        let omega_z_new = omega_z + factor * (mu_w * cosf(slipAngle) * cosTheta) * deltaP
        
        return (omega_x_new, omega_y_new, omega_z_new)
    }
    
    /// Calculate work done for a single step
    /// - Parameters:
    ///   - vy: y-velocity
    ///   - cosTheta: Cosine of contact angle
    ///   - deltaP: Impulse increment
    /// - Returns: Work done
    private static func calculateWorkDone(vy: Float, cosTheta: Float, deltaP: Float) -> Float {
        return deltaP * abs(vy) * cosTheta
    }
    
    // MARK: - Compression Phase
    
    /// Run compression phase until y-velocity is no longer positive
    /// - Parameters:
    ///   - vx: Initial x-velocity
    ///   - vy: Initial y-velocity
    ///   - omega_x: Initial x-angular velocity
    ///   - omega_y: Initial y-angular velocity
    ///   - omega_z: Initial z-angular velocity
    ///   - mu_s: Table friction coefficient
    ///   - mu_w: Cushion friction coefficient
    ///   - sinTheta: Sine of contact angle
    ///   - cosTheta: Cosine of contact angle
    ///   - R: Ball radius
    ///   - M: Ball mass
    ///   - maxSteps: Maximum number of steps
    ///   - deltaP: Impulse step size
    /// - Returns: Final velocities, angular velocities, and total work
    private static func compressionPhase(
        vx: Float,
        vy: Float,
        omega_x: Float,
        omega_y: Float,
        omega_z: Float,
        mu_s: Float,
        mu_w: Float,
        sinTheta: Float,
        cosTheta: Float,
        R: Float,
        M: Float,
        maxSteps: Int,
        deltaP: Float
    ) -> (vx: Float, vy: Float, omega_x: Float, omega_y: Float, omega_z: Float, totalWork: Float) {
        
        var currentVx = vx
        var currentVy = vy
        var currentOmegaX = omega_x
        var currentOmegaY = omega_y
        var currentOmegaZ = omega_z
        var totalWork: Float = 0.0
        var stepCount = 0
        
        // Calculate initial step size based on initial velocity
        let adaptiveDeltaP = max((M * vy) / Float(maxSteps), deltaP)
        
        while currentVy > 0 {
            // Calculate slip states
            let (_, slipAngle, _, slipAnglePrime) = calculateSlipSpeedsAndAngles(
                R: R,
                sinTheta: sinTheta,
                cosTheta: cosTheta,
                vx: currentVx,
                vy: currentVy,
                omega_x: currentOmegaX,
                omega_y: currentOmegaY,
                omega_z: currentOmegaZ
            )
            
            // Update velocities
            let (vxNext, vyNext) = updateVelocity(
                M: M,
                mu_s: mu_s,
                mu_w: mu_w,
                sinTheta: sinTheta,
                cosTheta: cosTheta,
                vx: currentVx,
                vy: currentVy,
                slipAngle: slipAngle,
                slipAnglePrime: slipAnglePrime,
                deltaP: adaptiveDeltaP
            )
            
            // Check if threshold crossed
            if currentVy > 0 && vyNext <= 0 {
                // Binary refinement to find precise crossing point
                var refineVx = currentVx
                var refineVy = currentVy
                var refineOmegaX = currentOmegaX
                var refineOmegaY = currentOmegaY
                var refineOmegaZ = currentOmegaZ
                var refineWork = totalWork
                var refineDeltaP = adaptiveDeltaP
                
                // Binary search refinement (8 iterations)
                for _ in 0..<8 {
                    refineDeltaP /= 2.0
                    
                    let (_, slipAngleRefine, _, slipAnglePrimeRefine) = calculateSlipSpeedsAndAngles(
                        R: R,
                        sinTheta: sinTheta,
                        cosTheta: cosTheta,
                        vx: refineVx,
                        vy: refineVy,
                        omega_x: refineOmegaX,
                        omega_y: refineOmegaY,
                        omega_z: refineOmegaZ
                    )
                    
                    let (vxTest, vyTest) = updateVelocity(
                        M: M,
                        mu_s: mu_s,
                        mu_w: mu_w,
                        sinTheta: sinTheta,
                        cosTheta: cosTheta,
                        vx: refineVx,
                        vy: refineVy,
                        slipAngle: slipAngleRefine,
                        slipAnglePrime: slipAnglePrimeRefine,
                        deltaP: refineDeltaP
                    )
                    
                    if vyTest <= 0 {
                        // Step too large, continue refinement
                        continue
                    }
                    
                    // Step doesn't cross threshold, update state
                    refineVx = vxTest
                    refineVy = vyTest
                    
                    let (omegaXRefine, omegaYRefine, omegaZRefine) = updateAngularVelocity(
                        M: M,
                        R: R,
                        mu_s: mu_s,
                        mu_w: mu_w,
                        sinTheta: sinTheta,
                        cosTheta: cosTheta,
                        omega_x: refineOmegaX,
                        omega_y: refineOmegaY,
                        omega_z: refineOmegaZ,
                        slipAngle: slipAngleRefine,
                        slipAnglePrime: slipAnglePrimeRefine,
                        deltaP: refineDeltaP
                    )
                    
                    refineOmegaX = omegaXRefine
                    refineOmegaY = omegaYRefine
                    refineOmegaZ = omegaZRefine
                    
                    let deltaWork = calculateWorkDone(vy: refineVy, cosTheta: cosTheta, deltaP: refineDeltaP)
                    refineWork += deltaWork
                }
                
                // Return refined state
                return (
                    vx: refineVx,
                    vy: refineVy,
                    omega_x: refineOmegaX,
                    omega_y: refineOmegaY,
                    omega_z: refineOmegaZ,
                    totalWork: refineWork
                )
            }
            
            // Continue with normal update
            currentVx = vxNext
            currentVy = vyNext
            
            let (omegaXNew, omegaYNew, omegaZNew) = updateAngularVelocity(
                M: M,
                R: R,
                mu_s: mu_s,
                mu_w: mu_w,
                sinTheta: sinTheta,
                cosTheta: cosTheta,
                omega_x: currentOmegaX,
                omega_y: currentOmegaY,
                omega_z: currentOmegaZ,
                slipAngle: slipAngle,
                slipAnglePrime: slipAnglePrime,
                deltaP: adaptiveDeltaP
            )
            
            currentOmegaX = omegaXNew
            currentOmegaY = omegaYNew
            currentOmegaZ = omegaZNew
            
            // Calculate work for this step
            let deltaWork = calculateWorkDone(vy: currentVy, cosTheta: cosTheta, deltaP: adaptiveDeltaP)
            totalWork += deltaWork
            
            // Update step count
            stepCount += 1
            if stepCount > 10 * maxSteps {
                // Safety check: prevent infinite loops
                break
            }
        }
        
        return (
            vx: currentVx,
            vy: currentVy,
            omega_x: currentOmegaX,
            omega_y: currentOmegaY,
            omega_z: currentOmegaZ,
            totalWork: totalWork
        )
    }
    
    // MARK: - Restitution Phase
    
    /// Run restitution phase until target work is reached
    /// - Parameters:
    ///   - vx: Initial x-velocity (from compression phase)
    ///   - vy: Initial y-velocity (from compression phase)
    ///   - omega_x: Initial x-angular velocity (from compression phase)
    ///   - omega_y: Initial y-angular velocity (from compression phase)
    ///   - omega_z: Initial z-angular velocity (from compression phase)
    ///   - mu_s: Table friction coefficient
    ///   - mu_w: Cushion friction coefficient
    ///   - sinTheta: Sine of contact angle
    ///   - cosTheta: Cosine of contact angle
    ///   - R: Ball radius
    ///   - M: Ball mass
    ///   - targetWorkRebound: Target work for rebound (e^2 * compression work)
    ///   - maxSteps: Maximum number of steps
    ///   - deltaP: Impulse step size
    /// - Returns: Final velocities and angular velocities
    private static func restitutionPhase(
        vx: Float,
        vy: Float,
        omega_x: Float,
        omega_y: Float,
        omega_z: Float,
        mu_s: Float,
        mu_w: Float,
        sinTheta: Float,
        cosTheta: Float,
        R: Float,
        M: Float,
        targetWorkRebound: Float,
        maxSteps: Int,
        deltaP: Float
    ) -> (vx: Float, vy: Float, omega_x: Float, omega_y: Float, omega_z: Float) {
        
        var currentVx = vx
        var currentVy = vy
        var currentOmegaX = omega_x
        var currentOmegaY = omega_y
        var currentOmegaZ = omega_z
        var totalWork: Float = 0.0
        var stepCount = 0
        
        // Adaptive step size based on target work
        let adaptiveDeltaP = max(targetWorkRebound / Float(maxSteps), deltaP)
        
        while totalWork < targetWorkRebound {
            // Calculate slip states
            let (_, slipAngle, _, slipAnglePrime) = calculateSlipSpeedsAndAngles(
                R: R,
                sinTheta: sinTheta,
                cosTheta: cosTheta,
                vx: currentVx,
                vy: currentVy,
                omega_x: currentOmegaX,
                omega_y: currentOmegaY,
                omega_z: currentOmegaZ
            )
            
            // Calculate next work increment
            let nextDeltaWork = calculateWorkDone(vy: currentVy, cosTheta: cosTheta, deltaP: adaptiveDeltaP)
            
            if totalWork + nextDeltaWork > targetWorkRebound {
                // Next step would exceed target, refine step size
                let remainingWork = targetWorkRebound - totalWork
                
                // Calculate refined delta_p that should be just right
                let refineDeltaP = remainingWork / (abs(currentVy) * cosTheta)
                
                // Apply refined step
                let (_, slipAngleRefine, _, slipAnglePrimeRefine) = calculateSlipSpeedsAndAngles(
                    R: R,
                    sinTheta: sinTheta,
                    cosTheta: cosTheta,
                    vx: currentVx,
                    vy: currentVy,
                    omega_x: currentOmegaX,
                    omega_y: currentOmegaY,
                    omega_z: currentOmegaZ
                )
                
                let (refineVx, refineVy) = updateVelocity(
                    M: M,
                    mu_s: mu_s,
                    mu_w: mu_w,
                    sinTheta: sinTheta,
                    cosTheta: cosTheta,
                    vx: currentVx,
                    vy: currentVy,
                    slipAngle: slipAngleRefine,
                    slipAnglePrime: slipAnglePrimeRefine,
                    deltaP: refineDeltaP
                )
                
                let (refineOmegaX, refineOmegaY, refineOmegaZ) = updateAngularVelocity(
                    M: M,
                    R: R,
                    mu_s: mu_s,
                    mu_w: mu_w,
                    sinTheta: sinTheta,
                    cosTheta: cosTheta,
                    omega_x: currentOmegaX,
                    omega_y: currentOmegaY,
                    omega_z: currentOmegaZ,
                    slipAngle: slipAngleRefine,
                    slipAnglePrime: slipAnglePrimeRefine,
                    deltaP: refineDeltaP
                )
                
                // Return final state
                return (
                    vx: refineVx,
                    vy: refineVy,
                    omega_x: refineOmegaX,
                    omega_y: refineOmegaY,
                    omega_z: refineOmegaZ
                )
            }
            
            // Continue with normal update
            let (vxNew, vyNew) = updateVelocity(
                M: M,
                mu_s: mu_s,
                mu_w: mu_w,
                sinTheta: sinTheta,
                cosTheta: cosTheta,
                vx: currentVx,
                vy: currentVy,
                slipAngle: slipAngle,
                slipAnglePrime: slipAnglePrime,
                deltaP: adaptiveDeltaP
            )
            
            let (omegaXNew, omegaYNew, omegaZNew) = updateAngularVelocity(
                M: M,
                R: R,
                mu_s: mu_s,
                mu_w: mu_w,
                sinTheta: sinTheta,
                cosTheta: cosTheta,
                omega_x: currentOmegaX,
                omega_y: currentOmegaY,
                omega_z: currentOmegaZ,
                slipAngle: slipAngle,
                slipAnglePrime: slipAnglePrime,
                deltaP: adaptiveDeltaP
            )
            
            currentVx = vxNew
            currentVy = vyNew
            currentOmegaX = omegaXNew
            currentOmegaY = omegaYNew
            currentOmegaZ = omegaZNew
            
            // Calculate work for this step
            let deltaWork = calculateWorkDone(vy: currentVy, cosTheta: cosTheta, deltaP: adaptiveDeltaP)
            totalWork += deltaWork
            
            // Update step count
            stepCount += 1
            if stepCount > 10 * maxSteps {
                // Safety check: prevent infinite loops
                break
            }
        }
        
        return (
            vx: currentVx,
            vy: currentVy,
            omega_x: currentOmegaX,
            omega_y: currentOmegaY,
            omega_z: currentOmegaZ
        )
    }
}
