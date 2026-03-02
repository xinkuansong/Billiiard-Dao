import XCTest
import SceneKit
@testable import BilliardTrainer

// MARK: - JSON Suite Models: Cue Strike

private struct CueStrikeTestSuite: Decodable {
    struct Tolerance: Decodable {
        let abs: Double
        let rel: Double
    }
    struct TestCase: Decodable {
        struct Input: Decodable {
            // swiftlint:disable identifier_name
            let V0: Double
            let phi: Double
            let theta: Double
            let Q: [Double]
            let R: Double
            let m: Double
            let cue_m: Double
            // swiftlint:enable identifier_name
        }
        struct Expected: Decodable {
            let squirt: Double
            let rvw_after: [[Double]]
        }
        let id: String
        let input: Input
        let expected: Expected
    }
    let module: String
    let source: String
    let tolerance: Tolerance
    let testCases: [TestCase]
    enum CodingKeys: String, CodingKey {
        case module, source, tolerance
        case testCases = "test_cases"
    }
}

final class CueBallStrikeTests: XCTestCase {

    // MARK: - Center Strike (No Spin)

    func testCenterStrikeNoSpin() {
        let result = CueBallStrike.strike(V0: 3.0, phi: 0, a: 0, b: 0)
        XCTAssertVector3Finite(result.velocity)
        XCTAssertVector3Finite(result.angularVelocity)
        XCTAssertGreaterThan(result.velocity.length(), 0)
        // Center strike should produce minimal angular velocity
        XCTAssertLessThan(result.angularVelocity.length(), 1.0,
                          "Center strike should have very little spin")
    }

    func testCenterStrikeDirectionMatchesPhi() {
        let phi: Float = .pi / 4
        let result = CueBallStrike.strike(V0: 3.0, phi: phi, a: 0, b: 0)
        let dir = result.velocity.normalized()
        // Velocity should be roughly in the phi direction (in XZ plane)
        let expectedDir = SCNVector3(sin(phi), 0, -cos(phi)).normalized()
        // Allow generous tolerance for the physics model
        let dot = dir.dot(expectedDir)
        XCTAssertGreaterThan(dot, 0.9, "Velocity should align with phi direction")
    }

    // MARK: - Top Spin (High Ball)

    func testTopSpinProducesForwardAngularVelocity() {
        let result = CueBallStrike.strike(V0: 3.0, phi: 0, a: 0, b: 0.8)
        XCTAssertVector3Finite(result.angularVelocity)
        // Top spin (b > 0) with phi=0 (ball moves in -Z): forward rolling has omega_x < 0
        // (right-hand rule: rotation from +Y toward -Z is around -X axis)
        XCTAssertLessThan(result.angularVelocity.x, 0,
                          "Top spin should produce negative omega_x for forward rolling in -Z")
    }

    // MARK: - Back Spin (Draw)

    func testBackSpinProducesReverseAngularVelocity() {
        let result = CueBallStrike.strike(V0: 3.0, phi: 0, a: 0, b: -0.8)
        XCTAssertVector3Finite(result.angularVelocity)
        // Back spin (b < 0) with phi=0: omega_x > 0 (opposite to forward rolling)
        XCTAssertGreaterThan(result.angularVelocity.x, 0,
                             "Back spin should produce positive omega_x (reverse of forward rolling)")
    }

    // MARK: - Side Spin (English)

    func testLeftEnglishProducesYSpin() {
        let result = CueBallStrike.strike(V0: 3.0, phi: 0, a: 0.5, b: 0)
        XCTAssertVector3Finite(result.angularVelocity)
        // Side spin should produce y-component angular velocity
        XCTAssertGreaterThan(abs(result.angularVelocity.y), 0.1,
                             "English should produce vertical spin")
    }

    // MARK: - Squirt Angle

    func testSquirtAngleZeroForCenterStrike() {
        let squirt = CueBallStrike.squirtAngle(a: 0)
        XCTAssertEqual(squirt, 0, accuracy: 0.001)
    }

    func testSquirtAngleNonZeroForSideSpin() {
        let squirt = CueBallStrike.squirtAngle(a: 0.5)
        XCTAssertNotEqual(squirt, 0, "Side spin should produce squirt")
        XCTAssertTrue(squirt.isFinite)
    }

    func testSquirtAngleSymmetry() {
        let squirtLeft = CueBallStrike.squirtAngle(a: 0.5)
        let squirtRight = CueBallStrike.squirtAngle(a: -0.5)
        XCTAssertEqual(squirtLeft, -squirtRight, accuracy: 0.001,
                       "Squirt should be symmetric")
    }

    func testSquirtAngleIncreasesWithSpin() {
        let squirt1 = abs(CueBallStrike.squirtAngle(a: 0.3))
        let squirt2 = abs(CueBallStrike.squirtAngle(a: 0.7))
        XCTAssertGreaterThan(squirt2, squirt1,
                             "More spin should produce more squirt")
    }

    // MARK: - Actual Direction

    func testActualDirectionCenterHit() {
        let aim = SCNVector3(0, 0, -1)
        let actual = CueBallStrike.actualDirection(aimDirection: aim, spinX: 0)
        XCTAssertVector3Equal(actual, aim, accuracy: 0.01)
    }

    func testActualDirectionWithEnglish() {
        let aim = SCNVector3(0, 0, -1)
        let actual = CueBallStrike.actualDirection(aimDirection: aim, spinX: 0.5)
        let dot = aim.dot(actual)
        XCTAssertLessThan(dot, 1.0, "English should deflect the actual direction")
        XCTAssertGreaterThan(dot, 0.9, "Deflection should be small")
    }

    // MARK: - Execute Strike

    func testExecuteStrikeReturnsConsistentResults() {
        let aimDir = SCNVector3(0, 0, -1)
        let result = CueBallStrike.executeStrike(
            aimDirection: aimDir, velocity: 3.0, spinX: 0.3, spinY: 0.5
        )
        XCTAssertVector3Finite(result.velocity)
        XCTAssertVector3Finite(result.angularVelocity)
        XCTAssertTrue(result.squirtAngle.isFinite)
    }

    // MARK: - Extreme Inputs

    func testExtremeSpinDoesNotCrash() {
        let result1 = CueBallStrike.strike(V0: 8.0, phi: 0, a: 1.0, b: 1.0)
        XCTAssertVector3Finite(result1.velocity)
        XCTAssertVector3Finite(result1.angularVelocity)

        let result2 = CueBallStrike.strike(V0: 8.0, phi: 0, a: -1.0, b: -1.0)
        XCTAssertVector3Finite(result2.velocity)
        XCTAssertVector3Finite(result2.angularVelocity)
    }

    func testZeroVelocityStrike() {
        let result = CueBallStrike.strike(V0: 0, phi: 0, a: 0, b: 0)
        XCTAssertEqual(result.velocity.length(), 0, accuracy: 0.001)
    }

    // MARK: - JSON-Driven Pooltool Cross-Validation: Cue Strike

    func testPooltoolCueStrikeBaseline() throws {
        try runCueStrikeJSONSuite(filename: "cue_strike.json")
    }

    // MARK: - Cue Strike JSON Suite Helpers

    private var csTestDataDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Physics/
            .deletingLastPathComponent() // BilliardTrainerTests/
            .appendingPathComponent("TestData/cue_strike")
    }

    /// Convert pooltool cue-strike velocity [vx, vy, 0] (Z-up XY-table) to Swift SCNVector3 (Y-up XZ-table).
    ///
    /// Axis mapping: pooltool X → Swift X, pooltool Y → Swift Z, pooltool Z → Swift Y.
    /// Velocity: (vx, vy, 0) → Swift (vx, 0, vy).
    private func csVelocityToSwift(_ v: [Double]) -> SCNVector3 {
        SCNVector3(Float(v[0]), 0.0, Float(v[1]))
    }

    /// Convert pooltool cue-strike angular velocity [wx, wy, wz] (Z-up) to Swift SCNVector3 (Y-up).
    ///
    /// Axis mapping: pooltool X → Swift X, pooltool Y → Swift Z, pooltool Z → Swift Y.
    /// Angular velocity: (wx, wy, wz) → Swift (wx, wz, wy).
    private func csAngularVelToSwift(_ w: [Double]) -> SCNVector3 {
        SCNVector3(Float(w[0]), Float(w[2]), Float(w[1]))
    }

    private func runCueStrikeJSONSuite(filename: String) throws {
        let url = csTestDataDir.appendingPathComponent(filename)
        let data = try Data(contentsOf: url)
        let suite = try JSONDecoder().decode(CueStrikeTestSuite.self, from: data)

        let absTol = Float(suite.tolerance.abs)
        let relTol = Float(suite.tolerance.rel)
        var failures: [String] = []

        for tc in suite.testCases {
            let inp = tc.input

            // Q = [a, c, b] in pooltool export convention; extract Swift a and b.
            let a = Float(inp.Q[0])
            let b = Float(inp.Q[2])

            // phi: pooltool phi=0 → ball moves in +X (XY-table).
            // Swift phi=π/2 → ball moves in +X (XZ-table).
            // General mapping: phi_sw = phi_pt_rad + π/2.
            let phiSw = Float(inp.phi * .pi / 180.0) + .pi / 2.0
            let thetaSw = Float(inp.theta * .pi / 180.0)

            let result = CueBallStrike.strike(V0: Float(inp.V0), phi: phiSw, theta: thetaSw, a: a, b: b)

            let expVel = csVelocityToSwift(tc.expected.rvw_after[1])
            let expOmega = csAngularVelToSwift(tc.expected.rvw_after[2])

            let velChecks: [(got: Float, exp: Float, label: String)] = [
                (result.velocity.x, expVel.x, "vel.x"),
                (result.velocity.y, expVel.y, "vel.y"),
                (result.velocity.z, expVel.z, "vel.z"),
            ]
            let omegaChecks: [(got: Float, exp: Float, label: String)] = [
                (result.angularVelocity.x, expOmega.x, "omega.x"),
                (result.angularVelocity.y, expOmega.y, "omega.y"),
                (result.angularVelocity.z, expOmega.z, "omega.z"),
            ]

            for check in velChecks + omegaChecks {
                let diff = abs(check.got - check.exp)
                let tol = max(absTol, relTol * abs(check.exp))
                if diff > tol {
                    failures.append(
                        "\(tc.id) \(check.label): " +
                        "got=\(check.got) exp=\(check.exp) diff=\(diff) tol=\(tol)"
                    )
                }
            }

            // Squirt angle comparison.
            let squirtGot = CueBallStrike.squirtAngle(a: a)
            let squirtExp = Float(tc.expected.squirt)
            let squirtDiff = abs(squirtGot - squirtExp)
            let squirtTol = max(absTol, relTol * abs(squirtExp))
            if squirtDiff > squirtTol {
                failures.append(
                    "\(tc.id) squirt: " +
                    "got=\(squirtGot) exp=\(squirtExp) diff=\(squirtDiff) tol=\(squirtTol)"
                )
            }
        }

        XCTAssertTrue(
            failures.isEmpty,
            "[\(suite.source)] \(failures.count) component(s) failed across \(suite.testCases.count) cases:\n"
                + failures.prefix(20).joined(separator: "\n")
        )
    }
}
