import XCTest
@testable import BilliardTrainer

final class QuarticSolverTests: XCTestCase {

    private let eps = 1e-6

    // MARK: - Known Roots

    func testQuarticWithKnownRoots() {
        // (x-1)(x-2)(x-3)(x-4) = x^4 - 10x^3 + 35x^2 - 50x + 24
        let roots = QuarticSolver.solveQuartic(a: 1, b: -10, c: 35, d: -50, e: 24)
        XCTAssertEqual(roots.count, 4)
        for expected in [1.0, 2.0, 3.0, 4.0] {
            XCTAssertTrue(roots.contains(where: { abs($0 - expected) < 0.01 }),
                          "Missing root \(expected), got \(roots)")
        }
    }

    func testQuarticWithRepeatedRoots() {
        // (x-2)^2 * (x-5)^2 = x^4 - 14x^3 + 69x^2 - 140x + 100
        let roots = QuarticSolver.solveQuartic(a: 1, b: -14, c: 69, d: -140, e: 100)
        XCTAssertGreaterThanOrEqual(roots.count, 2)
        XCTAssertTrue(roots.contains(where: { abs($0 - 2.0) < 0.1 }))
        XCTAssertTrue(roots.contains(where: { abs($0 - 5.0) < 0.1 }))
    }

    func testQuarticNoRealRoots() {
        // x^4 + 1 = 0 has no real roots
        let roots = QuarticSolver.solveQuartic(a: 1, b: 0, c: 0, d: 0, e: 1)
        XCTAssertTrue(roots.isEmpty, "Expected no real roots, got \(roots)")
    }

    func testQuarticTwoRealRoots() {
        // x^4 - 5x^2 + 4 = (x^2-1)(x^2-4) => roots: -2, -1, 1, 2
        let roots = QuarticSolver.solveQuartic(a: 1, b: 0, c: -5, d: 0, e: 4)
        XCTAssertEqual(roots.count, 4)
        for expected in [-2.0, -1.0, 1.0, 2.0] {
            XCTAssertTrue(roots.contains(where: { abs($0 - expected) < 0.01 }),
                          "Missing root \(expected)")
        }
    }

    // MARK: - Degenerate Cases

    func testDegenerateToCubic() {
        // a=0: 2x^3 - 6x^2 + 4x = 0 => x(2x^2-6x+4) = 0 => x=0, x=1, x=2
        let roots = QuarticSolver.solveQuartic(a: 0, b: 2, c: -6, d: 4, e: 0)
        XCTAssertGreaterThanOrEqual(roots.count, 3)
        for expected in [0.0, 1.0, 2.0] {
            XCTAssertTrue(roots.contains(where: { abs($0 - expected) < 0.01 }),
                          "Missing root \(expected)")
        }
    }

    func testDegenerateToQuadratic() {
        // a=0, b=0: x^2 - 4 = 0 => x = ±2
        let roots = QuarticSolver.solveQuartic(a: 0, b: 0, c: 1, d: 0, e: -4)
        XCTAssertEqual(roots.count, 2)
        XCTAssertTrue(roots.contains(where: { abs($0 - (-2.0)) < 0.01 }))
        XCTAssertTrue(roots.contains(where: { abs($0 - 2.0) < 0.01 }))
    }

    func testDegenerateToLinear() {
        // a=0, b=0, c=0: 3x + 6 = 0 => x = -2
        let roots = QuarticSolver.solveQuartic(a: 0, b: 0, c: 0, d: 3, e: 6)
        XCTAssertEqual(roots.count, 1)
        XCTAssertEqual(roots[0], -2.0, accuracy: eps)
    }

    func testAllZeroCoefficients() {
        let roots = QuarticSolver.solveQuartic(a: 0, b: 0, c: 0, d: 0, e: 0)
        XCTAssertTrue(roots.isEmpty)
    }

    // MARK: - Robustness

    func testRootsAreSorted() {
        let roots = QuarticSolver.solveQuartic(a: 1, b: -10, c: 35, d: -50, e: 24)
        for i in 1..<roots.count {
            XCTAssertLessThanOrEqual(roots[i - 1], roots[i])
        }
    }

    func testRootsAreFinite() {
        let roots = QuarticSolver.solveQuartic(a: 1, b: -10, c: 35, d: -50, e: 24)
        for root in roots {
            XCTAssertTrue(root.isFinite && !root.isNaN)
        }
    }

    func testVerySmallCoefficients() {
        // Very small leading coefficient should still work
        let roots = QuarticSolver.solveQuartic(a: 1e-15, b: 0, c: 1, d: 0, e: -4)
        XCTAssertGreaterThanOrEqual(roots.count, 2)
    }
}
