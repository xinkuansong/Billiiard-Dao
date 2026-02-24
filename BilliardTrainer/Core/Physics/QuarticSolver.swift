//
//  QuarticSolver.swift
//  BilliardTrainer
//
//  Solver for quartic equations: ax^4 + bx^3 + cx^2 + dx + e = 0
//  Used for Continuous Collision Detection (CCD)
//

import Foundation

/// Solver for quartic equations
struct QuarticSolver {
    
    /// Solve quartic equation: ax^4 + bx^3 + cx^2 + dx + e = 0
    /// - Parameters:
    ///   - a: Coefficient of x^4
    ///   - b: Coefficient of x^3
    ///   - c: Coefficient of x^2
    ///   - d: Coefficient of x^1
    ///   - e: Constant term
    /// - Returns: Array of real roots sorted in ascending order
    static func solveQuartic(a: Double, b: Double, c: Double, d: Double, e: Double) -> [Double] {
        // Handle degenerate cases
        if abs(a) < 1e-12 {
            // Cubic: bx^3 + cx^2 + dx + e = 0
            if abs(b) < 1e-12 {
                // Quadratic: cx^2 + dx + e = 0
                if abs(c) < 1e-12 {
                    // Linear: dx + e = 0
                    if abs(d) < 1e-12 {
                        return []
                    }
                    return [-e / d]
                }
                return solveQuadratic(a: c, b: d, c: e)
            }
            return solveCubic(a: b, b: c, c: d, d: e)
        }
        
        // Normalize to monic form: x^4 + (b/a)x^3 + (c/a)x^2 + (d/a)x + (e/a) = 0
        let invA = 1.0 / a
        let bNorm = b * invA
        let cNorm = c * invA
        let dNorm = d * invA
        let eNorm = e * invA
        
        // Use Ferrari's method: convert to depressed quartic
        // Substitute x = y - b/4 to eliminate cubic term
        let p = cNorm - 3.0 * bNorm * bNorm / 8.0
        let q = bNorm * bNorm * bNorm / 8.0 - bNorm * cNorm / 2.0 + dNorm
        let r = -3.0 * bNorm * bNorm * bNorm * bNorm / 256.0 + bNorm * bNorm * cNorm / 16.0 - bNorm * dNorm / 4.0 + eNorm
        
        // Depressed quartic: y^4 + py^2 + qy + r = 0
        // Find resolvent cubic: u^3 + 2pu^2 + (p^2 - 4r)u - q^2 = 0
        let cubicA = 1.0
        let cubicB = 2.0 * p
        let cubicC = p * p - 4.0 * r
        let cubicD = -q * q
        
        let cubicRoots = solveCubic(a: cubicA, b: cubicB, c: cubicC, d: cubicD)
        
        // Handle biquadratic case (q ≈ 0): y^4 + py^2 + r = 0
        if abs(q) < 1e-10 {
            let quadRoots = solveQuadratic(a: 1.0, b: p, c: r)
            var roots: [Double] = []
            for y2 in quadRoots {
                if y2 >= -1e-10 {
                    let y2Clamped = max(0, y2)
                    roots.append(sqrt(y2Clamped))
                    if y2Clamped > 1e-14 {
                        roots.append(-sqrt(y2Clamped))
                    }
                }
            }
            let offset = bNorm / 4.0
            roots = roots.map { $0 - offset }
            roots = roots.compactMap { refineRoot(a: a, b: b, c: c, d: d, e: e, x0: $0) }
            return removeDuplicates(roots.sorted(), tolerance: 1e-8)
        }
        
        // Find a real positive root u of the resolvent cubic (u = alpha^2)
        guard let u = cubicRoots.first(where: { $0 > 1e-14 }) else {
            return []
        }
        
        // Factor depressed quartic: (y^2 + alpha*y + beta)(y^2 - alpha*y + gamma) = 0
        let alpha = sqrt(u)
        let beta  = (p + u) / 2.0 - q / (2.0 * alpha)
        let gamma = (p + u) / 2.0 + q / (2.0 * alpha)
        
        var roots: [Double] = []
        
        // First quadratic: y^2 + alpha*y + beta = 0
        let disc1 = alpha * alpha - 4.0 * beta
        if disc1 >= -1e-10 {
            let sqrtDisc1 = sqrt(max(0, disc1))
            roots.append((-alpha + sqrtDisc1) / 2.0)
            roots.append((-alpha - sqrtDisc1) / 2.0)
        }
        
        // Second quadratic: y^2 - alpha*y + gamma = 0
        let disc2 = alpha * alpha - 4.0 * gamma
        if disc2 >= -1e-10 {
            let sqrtDisc2 = sqrt(max(0, disc2))
            roots.append((alpha + sqrtDisc2) / 2.0)
            roots.append((alpha - sqrtDisc2) / 2.0)
        }
        
        // Convert back from y to x: x = y - b/(4a)
        let offset = bNorm / 4.0
        roots = roots.map { $0 - offset }
        
        // Polish roots with Newton-Raphson and filter non-real artifacts
        roots = roots.compactMap { refineRoot(a: a, b: b, c: c, d: d, e: e, x0: $0) }
        
        return removeDuplicates(roots.sorted(), tolerance: 1e-8)
    }
    
    // MARK: - Helper Methods
    
    /// Solve quadratic equation: ax^2 + bx + c = 0
    private static func solveQuadratic(a: Double, b: Double, c: Double) -> [Double] {
        if abs(a) < 1e-12 {
            // Linear: bx + c = 0
            if abs(b) < 1e-12 {
                return []
            }
            return [-c / b]
        }
        
        let discriminant = b * b - 4.0 * a * c
        
        if discriminant < 0 {
            return []
        } else if abs(discriminant) < 1e-12 {
            return [-b / (2.0 * a)]
        } else {
            let sqrtDisc = sqrt(discriminant)
            let root1 = (-b + sqrtDisc) / (2.0 * a)
            let root2 = (-b - sqrtDisc) / (2.0 * a)
            return [root1, root2].sorted()
        }
    }
    
    /// Solve cubic equation: ax^3 + bx^2 + cx + d = 0
    private static func solveCubic(a: Double, b: Double, c: Double, d: Double) -> [Double] {
        if abs(a) < 1e-12 {
            return solveQuadratic(a: b, b: c, c: d)
        }
        
        // Normalize to monic form: x^3 + (b/a)x^2 + (c/a)x + (d/a) = 0
        let invA = 1.0 / a
        let bNorm = b * invA
        let cNorm = c * invA
        let dNorm = d * invA
        
        // Depressed cubic: y^3 + py + q = 0 where y = x + b/3
        let p = cNorm - bNorm * bNorm / 3.0
        let q = 2.0 * bNorm * bNorm * bNorm / 27.0 - bNorm * cNorm / 3.0 + dNorm
        
        let discriminant = (q / 2.0) * (q / 2.0) + (p / 3.0) * (p / 3.0) * (p / 3.0)
        
        var roots: [Double] = []
        
        if discriminant > 0 {
            // One real root
            let sqrtDisc = sqrt(discriminant)
            let u = cbrt(-q / 2.0 + sqrtDisc)
            let v = cbrt(-q / 2.0 - sqrtDisc)
            let root = u + v - bNorm / 3.0
            roots.append(root)
        } else if abs(discriminant) < 1e-12 {
            // Three real roots, two equal
            let u = cbrt(-q / 2.0)
            let root1 = 2.0 * u - bNorm / 3.0
            let root2 = -u - bNorm / 3.0
            roots.append(root1)
            roots.append(root2)
        } else {
            // Three distinct real roots
            let angle = acos(-q / 2.0 * sqrt(-27.0 / (p * p * p))) / 3.0
            let r = 2.0 * sqrt(-p / 3.0)
            let root1 = r * cos(angle) - bNorm / 3.0
            let root2 = r * cos(angle - 2.0 * .pi / 3.0) - bNorm / 3.0
            let root3 = r * cos(angle + 2.0 * .pi / 3.0) - bNorm / 3.0
            roots.append(contentsOf: [root1, root2, root3])
        }
        
        // Filter and sort
        roots = roots.filter { $0.isFinite && !$0.isNaN }
        return roots.sorted()
    }
    
    /// Newton-Raphson polishing: refine an approximate root of ax^4+bx^3+cx^2+dx+e
    /// Returns nil if the root diverges or is not actually near a real root.
    private static func refineRoot(a: Double, b: Double, c: Double, d: Double, e: Double, x0: Double, maxIter: Int = 8) -> Double? {
        var x = x0
        for _ in 0..<maxIter {
            let f  = ((((a * x + b) * x + c) * x + d) * x + e)
            let df = (((4 * a * x + 3 * b) * x + 2 * c) * x + d)
            if abs(df) < 1e-30 { break }
            let dx = f / df
            x -= dx
            if abs(dx) < 1e-14 { break }
        }
        guard x.isFinite && !x.isNaN else { return nil }
        let residual = abs(((((a * x + b) * x + c) * x + d) * x + e))
        let scale = max(1.0, abs(a) + abs(b) + abs(c) + abs(d) + abs(e))
        if residual / scale > 1e-6 { return nil }
        return x
    }
    
    /// Remove duplicate roots within a tolerance
    private static func removeDuplicates(_ sorted: [Double], tolerance: Double) -> [Double] {
        guard !sorted.isEmpty else { return [] }
        var result = [sorted[0]]
        for i in 1..<sorted.count {
            if abs(sorted[i] - result.last!) > tolerance {
                result.append(sorted[i])
            }
        }
        return result
    }
}
