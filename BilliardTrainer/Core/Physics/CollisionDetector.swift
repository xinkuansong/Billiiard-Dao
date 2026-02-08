//
//  CollisionDetector.swift
//  BilliardTrainer
//
//  Continuous Collision Detection (CCD) for ball-ball and ball-cushion collisions
//

import Foundation
import SceneKit

/// Continuous Collision Detection for billiard physics
struct CollisionDetector {
    
    // MARK: - Ball-Ball Collision
    
    /// Find collision time between two balls with constant acceleration
    /// - Parameters:
    ///   - p1: Initial position of ball 1 (SCNVector3)
    ///   - p2: Initial position of ball 2 (SCNVector3)
    ///   - v1: Initial velocity of ball 1 (SCNVector3)
    ///   - v2: Initial velocity of ball 2 (SCNVector3)
    ///   - a1: Constant acceleration of ball 1 (SCNVector3)
    ///   - a2: Constant acceleration of ball 2 (SCNVector3)
    ///   - R: Ball radius (Double)
    ///   - maxTime: Maximum time to search (Double)
    /// - Returns: Collision time if found, nil otherwise (Float?)
    static func ballBallCollisionTime(
        p1: SCNVector3,
        p2: SCNVector3,
        v1: SCNVector3,
        v2: SCNVector3,
        a1: SCNVector3,
        a2: SCNVector3,
        R: Double,
        maxTime: Double
    ) -> Float? {
        // Convert to Double for computation
        let p1d = SIMD3<Double>(Double(p1.x), Double(p1.y), Double(p1.z))
        let p2d = SIMD3<Double>(Double(p2.x), Double(p2.y), Double(p2.z))
        let v1d = SIMD3<Double>(Double(v1.x), Double(v1.y), Double(v1.z))
        let v2d = SIMD3<Double>(Double(v2.x), Double(v2.y), Double(v2.z))
        let a1d = SIMD3<Double>(Double(a1.x), Double(a1.y), Double(a1.z))
        let a2d = SIMD3<Double>(Double(a2.x), Double(a2.y), Double(a2.z))
        
        return ballBallCollisionTime(
            p1: p1d,
            p2: p2d,
            v1: v1d,
            v2: v2d,
            a1: a1d,
            a2: a2d,
            R: R,
            maxTime: maxTime
        )
    }
    
    /// Find collision time between two balls with constant acceleration (Double precision)
    /// - Parameters:
    ///   - p1: Initial position of ball 1 (SIMD3<Double>)
    ///   - p2: Initial position of ball 2 (SIMD3<Double>)
    ///   - v1: Initial velocity of ball 1 (SIMD3<Double>)
    ///   - v2: Initial velocity of ball 2 (SIMD3<Double>)
    ///   - a1: Constant acceleration of ball 1 (SIMD3<Double>)
    ///   - a2: Constant acceleration of ball 2 (SIMD3<Double>)
    ///   - R: Ball radius (Double)
    ///   - maxTime: Maximum time to search (Double)
    /// - Returns: Collision time if found, nil otherwise (Float?)
    static func ballBallCollisionTime(
        p1: SIMD3<Double>,
        p2: SIMD3<Double>,
        v1: SIMD3<Double>,
        v2: SIMD3<Double>,
        a1: SIMD3<Double>,
        a2: SIMD3<Double>,
        R: Double,
        maxTime: Double
    ) -> Float? {
        // Relative position, velocity, and acceleration
        let dp = p1 - p2
        let dv = v1 - v2
        let da = a1 - a2
        
        // Distance squared at time t: ||p1(t) - p2(t)||^2 = (2R)^2
        // p1(t) = p1 + v1*t + 0.5*a1*t^2
        // p2(t) = p2 + v2*t + 0.5*a2*t^2
        // ||dp + dv*t + 0.5*da*t^2||^2 = (2R)^2
        
        // Expand: (dp + dv*t + 0.5*da*t^2) · (dp + dv*t + 0.5*da*t^2) = 4R^2
        // This gives: (da·da/4)*t^4 + (da·dv)*t^3 + (dv·dv + da·dp)*t^2 + 2*(dv·dp)*t + (dp·dp - 4R^2) = 0
        
        let daDotDa = dot(da, da)
        let daDotDv = dot(da, dv)
        let dvDotDv = dot(dv, dv)
        let daDotDp = dot(da, dp)
        let dvDotDp = dot(dv, dp)
        let dpDotDp = dot(dp, dp)
        
        let a = daDotDa / 4.0
        let b = daDotDv
        let c = dvDotDv + daDotDp
        let d = 2.0 * dvDotDp
        let e = dpDotDp - 4.0 * R * R
        
        // Solve quartic equation
        let roots = QuarticSolver.solveQuartic(a: a, b: b, c: c, d: d, e: e)
        
        // Find smallest positive root within maxTime
        return smallestPositiveRoot(roots: roots, maxTime: maxTime)
    }
    
    // MARK: - Ball-Linear Cushion Collision
    
    /// Find collision time between ball and linear cushion
    /// - Parameters:
    ///   - p: Initial ball position (SCNVector3)
    ///   - v: Initial ball velocity (SCNVector3)
    ///   - a: Constant ball acceleration (SCNVector3)
    ///   - lineNormal: Normal vector of the cushion line (SCNVector3, should be normalized)
    ///   - lineOffset: Offset of the cushion line (distance from origin along normal)
    ///   - R: Ball radius (Double)
    ///   - maxTime: Maximum time to search (Double)
    /// - Returns: Collision time if found, nil otherwise (Float?)
    static func ballLinearCushionTime(
        p: SCNVector3,
        v: SCNVector3,
        a: SCNVector3,
        lineNormal: SCNVector3,
        lineOffset: Double,
        R: Double,
        maxTime: Double
    ) -> Float? {
        // Convert to Double for computation
        let pd = SIMD3<Double>(Double(p.x), Double(p.y), Double(p.z))
        let vd = SIMD3<Double>(Double(v.x), Double(v.y), Double(v.z))
        let ad = SIMD3<Double>(Double(a.x), Double(a.y), Double(a.z))
        let nd = SIMD3<Double>(Double(lineNormal.x), Double(lineNormal.y), Double(lineNormal.z))
        
        return ballLinearCushionTime(
            p: pd,
            v: vd,
            a: ad,
            lineNormal: nd,
            lineOffset: lineOffset,
            R: R,
            maxTime: maxTime
        )
    }
    
    /// Find collision time between ball and linear cushion (Double precision)
    /// - Parameters:
    ///   - p: Initial ball position (SIMD3<Double>)
    ///   - v: Initial ball velocity (SIMD3<Double>)
    ///   - a: Constant ball acceleration (SIMD3<Double>)
    ///   - lineNormal: Normal vector of the cushion line (SIMD3<Double>, should be normalized, pointing inward)
    ///   - lineOffset: Offset of the cushion line (distance from origin along normal)
    ///   - R: Ball radius (Double)
    ///   - maxTime: Maximum time to search (Double)
    /// - Returns: Collision time if found, nil otherwise (Float?)
    static func ballLinearCushionTime(
        p: SIMD3<Double>,
        v: SIMD3<Double>,
        a: SIMD3<Double>,
        lineNormal: SIMD3<Double>,
        lineOffset: Double,
        R: Double,
        maxTime: Double
    ) -> Float? {
        // Ball position at time t: p(t) = p + v*t + 0.5*a*t^2
        // Signed distance from ball center to cushion line: d(t) = n·p(t) - lineOffset
        // d(t) = (n·p - lineOffset) + (n·v)*t + 0.5*(n·a)*t^2
        // Collision when d(t) = R (approaching from positive side) or d(t) = -R (from negative side)
        
        let nDotP = dot(lineNormal, p)
        let nDotV = dot(lineNormal, v)
        let nDotA = dot(lineNormal, a)
        
        let constant = nDotP - lineOffset
        
        // Solve two quadratic equations separately to avoid spurious roots from squaring:
        // Case 1: d(t) = +R  =>  0.5*(n·a)*t^2 + (n·v)*t + (constant - R) = 0
        // Case 2: d(t) = -R  =>  0.5*(n·a)*t^2 + (n·v)*t + (constant + R) = 0
        
        var candidates: [Double] = []
        
        for sign in [1.0, -1.0] {
            let qA = 0.5 * nDotA
            let qB = nDotV
            let qC = constant - sign * R
            
            let roots = solveQuadratic(a: qA, b: qB, c: qC)
            
            for t in roots {
                guard t > 1e-6 && t <= maxTime && t.isFinite else { continue }
                
                // Verify ball is approaching the cushion at time t (velocity component toward cushion)
                // Velocity at time t along normal: v_n(t) = n·v + (n·a)*t
                let vNormal = nDotV + nDotA * t
                
                // For d(t) = +R: ball is on positive side, approaching means vNormal < 0
                // For d(t) = -R: ball is on negative side, approaching means vNormal > 0
                if sign > 0 && vNormal < 0 {
                    candidates.append(t)
                } else if sign < 0 && vNormal > 0 {
                    candidates.append(t)
                }
            }
        }
        
        guard let smallest = candidates.min() else { return nil }
        return Float(smallest)
    }
    
    /// Solve quadratic equation a*t^2 + b*t + c = 0
    private static func solveQuadratic(a: Double, b: Double, c: Double) -> [Double] {
        if abs(a) < 1e-12 {
            // Linear equation: b*t + c = 0
            if abs(b) < 1e-12 { return [] }
            return [-c / b]
        }
        
        let discriminant = b * b - 4.0 * a * c
        if discriminant < 0 { return [] }
        
        let sqrtD = sqrt(discriminant)
        return [(-b - sqrtD) / (2.0 * a), (-b + sqrtD) / (2.0 * a)]
    }
    
    // MARK: - Helper Methods
    
    /// Find the smallest positive root from an array of roots
    /// - Parameters:
    ///   - roots: Array of roots (Double)
    ///   - maxTime: Maximum time threshold (Double)
    /// - Returns: Smallest positive root as Float, or nil if none found
    private static func smallestPositiveRoot(roots: [Double], maxTime: Double) -> Float? {
        let positiveRoots = roots.filter { root in
            root > 0 && root <= maxTime && root.isFinite && !root.isNaN
        }
        
        guard let smallest = positiveRoots.min() else {
            return nil
        }
        
        return Float(smallest)
    }
    
    /// Dot product helper for SIMD3<Double>
    private static func dot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        return a.x * b.x + a.y * b.y + a.z * b.z
    }
}
