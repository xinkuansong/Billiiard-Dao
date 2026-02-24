import XCTest
import SceneKit
@testable import BilliardTrainer

final class AnalyticalMotionTests: XCTestCase {

    let tableY = TablePhysics.height + BallPhysics.radius

    // MARK: - Surface Velocity

    func testSurfaceVelocityPureRolling() {
        let R = BallPhysics.radius
        let v = SCNVector3(1, 0, 0)
        // Rolling condition: v + omega x r = 0 at contact
        // r = (0, -R, 0), omega x r = (omega_z*R, 0, -omega_x*R)
        // For v = (1,0,0): need 1 + omega_z*R = 0, so omega_z = -1/R
        let omega = SCNVector3(0, 0, -1.0 / R)
        let surfVel = AnalyticalMotion.surfaceVelocity(linear: v, angular: omega, radius: R)
        // Should be near zero for pure rolling
        XCTAssertLessThan(surfVel.length(), 0.01, "Surface velocity should be ~0 for pure rolling")
    }

    func testSurfaceVelocitySliding() {
        let R = BallPhysics.radius
        let v = SCNVector3(2, 0, 0)
        let omega = SCNVector3Zero
        let surfVel = AnalyticalMotion.surfaceVelocity(linear: v, angular: omega, radius: R)
        XCTAssertGreaterThan(surfVel.length(), 1.0, "Sliding ball should have nonzero surface velocity")
    }

    // MARK: - Sliding Evolution

    func testEvolveSlidingDeceleratesVelocity() {
        let pos = SCNVector3(0, tableY, 0)
        let vel = SCNVector3(2, 0, 0)
        let omega = SCNVector3Zero
        let dt: Float = 0.1

        let result = AnalyticalMotion.evolveSliding(
            position: pos, velocity: vel, angularVelocity: omega, dt: dt
        )

        XCTAssertLessThan(result.velocity.length(), vel.length(),
                          "Sliding should decelerate")
        XCTAssertGreaterThan(result.position.x, pos.x,
                             "Ball should move forward")
    }

    func testEvolveSlidingZeroVelocityUnchanged() {
        let pos = SCNVector3(0, tableY, 0)
        let vel = SCNVector3Zero
        let omega = SCNVector3Zero

        let result = AnalyticalMotion.evolveSliding(
            position: pos, velocity: vel, angularVelocity: omega, dt: 0.1
        )

        XCTAssertVector3Equal(result.position, pos)
        XCTAssertVector3Equal(result.velocity, vel)
    }

    func testEvolveSlidingProducesFiniteResults() {
        let pos = SCNVector3(0, tableY, 0)
        let vel = SCNVector3(5, 0, -3)
        let omega = SCNVector3(10, 5, -10)

        let result = AnalyticalMotion.evolveSliding(
            position: pos, velocity: vel, angularVelocity: omega, dt: 0.05
        )

        XCTAssertVector3Finite(result.position)
        XCTAssertVector3Finite(result.velocity)
        XCTAssertVector3Finite(result.angularVelocity)
    }

    // MARK: - Rolling Evolution

    func testEvolveRollingDecelerates() {
        let pos = SCNVector3(0, tableY, 0)
        let vel = SCNVector3(1, 0, 0)
        let R = BallPhysics.radius
        let omega = SCNVector3(0, 0, -1.0 / R)

        let result = AnalyticalMotion.evolveRolling(
            position: pos, velocity: vel, angularVelocity: omega, dt: 0.5
        )

        XCTAssertLessThan(result.velocity.length(), vel.length())
        XCTAssertGreaterThan(result.position.x, pos.x)
    }

    func testEvolveRollingZeroVelocityUnchanged() {
        let pos = SCNVector3(0, tableY, 0)
        let result = AnalyticalMotion.evolveRolling(
            position: pos, velocity: SCNVector3Zero, angularVelocity: SCNVector3Zero, dt: 0.5
        )
        XCTAssertVector3Equal(result.position, pos)
    }

    // MARK: - Spinning Evolution

    func testEvolveSpinningDecaysYComponent() {
        let pos = SCNVector3(0, tableY, 0)
        let omega = SCNVector3(0, 50, 0)

        let result = AnalyticalMotion.evolveSpinning(
            position: pos, angularVelocity: omega, dt: 0.1
        )

        XCTAssertVector3Equal(result.position, pos, accuracy: 0.001,
                              "Position should not change during spinning")
        XCTAssertLessThan(abs(result.angularVelocity.y), abs(omega.y),
                          "Spin should decay")
    }

    func testEvolveSpinningNearZeroStops() {
        let pos = SCNVector3(0, tableY, 0)
        let omega = SCNVector3(0, 0.00005, 0)

        let result = AnalyticalMotion.evolveSpinning(
            position: pos, angularVelocity: omega, dt: 0.01
        )

        XCTAssertEqual(result.angularVelocity.y, 0, accuracy: 0.001)
    }

    // MARK: - Transition Times

    func testSlideToRollTimePositive() {
        let vel = SCNVector3(2, 0, 0)
        let omega = SCNVector3Zero
        let t = AnalyticalMotion.slideToRollTime(velocity: vel, angularVelocity: omega)
        XCTAssertGreaterThan(t, 0)
        XCTAssertLessThan(t, 10, "Transition should happen in reasonable time")
    }

    func testSlideToRollTimeAlreadyRolling() {
        let vel = SCNVector3(1, 0, 0)
        let R = BallPhysics.radius
        let omega = SCNVector3(0, 0, -1.0 / R)
        let t = AnalyticalMotion.slideToRollTime(velocity: vel, angularVelocity: omega)
        XCTAssertEqual(t, 0, accuracy: 0.01)
    }

    func testRollToSpinTimePositive() {
        let vel = SCNVector3(1, 0, 0)
        let t = AnalyticalMotion.rollToSpinTime(velocity: vel)
        XCTAssertGreaterThan(t, 0)
        XCTAssertLessThan(t, 60, "Ball should stop rolling within a minute")
    }

    func testRollToSpinTimeZeroVelocity() {
        let t = AnalyticalMotion.rollToSpinTime(velocity: SCNVector3Zero)
        XCTAssertEqual(t, 0, accuracy: 0.001)
    }

    func testSpinToStationaryTimePositive() {
        let omega = SCNVector3(0, 30, 0)
        let t = AnalyticalMotion.spinToStationaryTime(angularVelocity: omega)
        XCTAssertGreaterThan(t, 0)
    }

    func testSpinToStationaryTimeZeroSpin() {
        let t = AnalyticalMotion.spinToStationaryTime(angularVelocity: SCNVector3Zero)
        XCTAssertEqual(t, 0, accuracy: 0.001)
    }

    // MARK: - Spin Decay

    func testDecaySpinReducesY() {
        let omega = SCNVector3(0, 20, 0)
        let result = AnalyticalMotion.decaySpin(angularVelocity: omega, dt: 0.1)
        XCTAssertLessThan(abs(result.y), abs(omega.y))
    }

    func testDecaySpinPreservesXZ() {
        let omega = SCNVector3(5, 20, -3)
        let result = AnalyticalMotion.decaySpin(angularVelocity: omega, dt: 0.1)
        XCTAssertEqual(result.x, omega.x, accuracy: 0.001)
        XCTAssertEqual(result.z, omega.z, accuracy: 0.001)
    }
}
