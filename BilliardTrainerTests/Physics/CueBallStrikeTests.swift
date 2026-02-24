import XCTest
import SceneKit
@testable import BilliardTrainer

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
}
