import XCTest
import SceneKit
@testable import BilliardTrainer

final class CollisionResolverTests: XCTestCase {

    let tableY = TablePhysics.height + BallPhysics.radius

    // MARK: - Ball-Ball: Head-On Collision

    func testHeadOnCollisionMomentumConservation() {
        let posA = SCNVector3(-0.1, tableY, 0)
        let posB = SCNVector3(0.1, tableY, 0)
        let velA = SCNVector3(2, 0, 0)
        let velB = SCNVector3Zero
        let omegaZero = SCNVector3Zero

        let result = CollisionResolver.resolveBallBallPure(
            posA: posA, posB: posB,
            velA: velA, velB: velB,
            angVelA: omegaZero, angVelB: omegaZero
        )

        // Momentum conservation: m*(vA + vB) should be same before and after
        let totalBefore = velA + velB
        let totalAfter = result.velA + result.velB
        XCTAssertVector3Equal(totalBefore, totalAfter, accuracy: 0.05,
                              "Momentum should be approximately conserved")
    }

    func testHeadOnCollisionVelocityTransfer() {
        let posA = SCNVector3(-0.1, tableY, 0)
        let posB = SCNVector3(0.1, tableY, 0)
        let velA = SCNVector3(2, 0, 0)
        let velB = SCNVector3Zero
        let omegaZero = SCNVector3Zero

        let result = CollisionResolver.resolveBallBallPure(
            posA: posA, posB: posB,
            velA: velA, velB: velB,
            angVelA: omegaZero, angVelB: omegaZero
        )

        // Ball A should slow down, ball B should gain velocity
        XCTAssertLessThan(result.velA.length(), velA.length())
        XCTAssertGreaterThan(result.velB.length(), 0.1)
    }

    func testHeadOnCollisionResultsFinite() {
        let posA = SCNVector3(-0.1, tableY, 0)
        let posB = SCNVector3(0.1, tableY, 0)
        let velA = SCNVector3(5, 0, 0)
        let omegaA = SCNVector3(10, 5, -10)

        let result = CollisionResolver.resolveBallBallPure(
            posA: posA, posB: posB,
            velA: velA, velB: SCNVector3Zero,
            angVelA: omegaA, angVelB: SCNVector3Zero
        )

        XCTAssertVector3Finite(result.velA)
        XCTAssertVector3Finite(result.velB)
        XCTAssertVector3Finite(result.angVelA)
        XCTAssertVector3Finite(result.angVelB)
    }

    // MARK: - Ball-Ball: Oblique Collision

    func testObliqueCollisionSeparationAngle() {
        // Ball B offset in Z, creating an angle shot
        let posA = SCNVector3(-0.2, tableY, 0)
        let posB = SCNVector3(0, tableY, 0.05)
        let velA = SCNVector3(2, 0, 0)

        let result = CollisionResolver.resolveBallBallPure(
            posA: posA, posB: posB,
            velA: velA, velB: SCNVector3Zero,
            angVelA: SCNVector3Zero, angVelB: SCNVector3Zero
        )

        // Both balls should move after oblique collision
        XCTAssertGreaterThan(result.velA.length(), 0.01)
        XCTAssertGreaterThan(result.velB.length(), 0.01)
        XCTAssertVector3Finite(result.velA)
        XCTAssertVector3Finite(result.velB)
    }

    // MARK: - Ball-Ball: Very Low Speed

    func testVeryLowSpeedCollisionNoNaN() {
        let posA = SCNVector3(-0.06, tableY, 0)
        let posB = SCNVector3(0.06, tableY, 0)
        let velA = SCNVector3(0.001, 0, 0)

        let result = CollisionResolver.resolveBallBallPure(
            posA: posA, posB: posB,
            velA: velA, velB: SCNVector3Zero,
            angVelA: SCNVector3Zero, angVelB: SCNVector3Zero
        )

        XCTAssertVector3NotNaN(result.velA)
        XCTAssertVector3NotNaN(result.velB)
        XCTAssertVector3NotNaN(result.angVelA)
        XCTAssertVector3NotNaN(result.angVelB)
    }

    // MARK: - Ball-Cushion Collision

    func testCushionCollisionReflection() {
        let vel = SCNVector3(0, 0, 2)
        let normal = SCNVector3(0, 0, -1)

        let result = CollisionResolver.resolveCushionCollisionPure(
            velocity: vel, angularVelocity: SCNVector3Zero, normal: normal
        )

        // Ball should bounce back (negative Z velocity)
        XCTAssertLessThan(result.velocity.z, 0,
                          "Ball should bounce back from cushion")
        XCTAssertVector3Finite(result.velocity)
    }

    func testCushionCollisionEnergyLoss() {
        let vel = SCNVector3(0, 0, 3)
        let normal = SCNVector3(0, 0, -1)

        let result = CollisionResolver.resolveCushionCollisionPure(
            velocity: vel, angularVelocity: SCNVector3Zero, normal: normal
        )

        // Should lose some energy (restitution < 1)
        XCTAssertLessThan(result.velocity.length(), vel.length(),
                          "Cushion bounce should lose energy")
    }

    func testCushionCollisionWithSpin() {
        let vel = SCNVector3(1, 0, 2)
        let omega = SCNVector3(0, 10, 0)
        let normal = SCNVector3(0, 0, -1)

        let result = CollisionResolver.resolveCushionCollisionPure(
            velocity: vel, angularVelocity: omega, normal: normal
        )

        XCTAssertVector3Finite(result.velocity)
        XCTAssertVector3Finite(result.angularVelocity)
        XCTAssertVector3NotNaN(result.velocity)
        XCTAssertVector3NotNaN(result.angularVelocity)
    }

    func testCushionCollisionLowSpeed() {
        let vel = SCNVector3(0, 0, 0.01)
        let normal = SCNVector3(0, 0, -1)

        let result = CollisionResolver.resolveCushionCollisionPure(
            velocity: vel, angularVelocity: SCNVector3Zero, normal: normal
        )

        XCTAssertVector3NotNaN(result.velocity)
        XCTAssertVector3Finite(result.velocity)
    }

    // MARK: - Cushion: Different Normals

    func testCushionAllFourWalls() {
        let speed: Float = 2.0
        let normals: [(SCNVector3, SCNVector3)] = [
            (SCNVector3(0, 0, speed), SCNVector3(0, 0, -1)),   // top
            (SCNVector3(0, 0, -speed), SCNVector3(0, 0, 1)),   // bottom
            (SCNVector3(speed, 0, 0), SCNVector3(-1, 0, 0)),   // right
            (SCNVector3(-speed, 0, 0), SCNVector3(1, 0, 0)),   // left
        ]

        for (vel, normal) in normals {
            let result = CollisionResolver.resolveCushionCollisionPure(
                velocity: vel, angularVelocity: SCNVector3Zero, normal: normal
            )
            XCTAssertVector3Finite(result.velocity, "Failed for normal \(normal)")
            XCTAssertLessThan(result.velocity.length(), vel.length(),
                              "Should lose energy for normal \(normal)")
        }
    }
}
