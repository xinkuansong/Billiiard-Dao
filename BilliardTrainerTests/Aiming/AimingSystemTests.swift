import XCTest
import SceneKit
@testable import BilliardTrainer

final class AimingSystemTests: XCTestCase {

    let tableY = TablePhysics.height + BallPhysics.radius

    // MARK: - Ghost Ball

    func testGhostBallPositionStraightShot() {
        let objectBall = SCNVector3(0, tableY, 0)
        let pocket = SCNVector3(0, tableY, -0.635)
        let ghost = AimingCalculator.ghostBallCenter(objectBall: objectBall, pocket: pocket)

        // Ghost ball should be 2R behind the object ball along ball-to-pocket line
        let expectedDir = (pocket - objectBall).normalized()
        let expectedPos = objectBall - expectedDir * (BallPhysics.radius * 2)
        XCTAssertVector3Equal(ghost, expectedPos, accuracy: 0.01)
    }

    func testGhostBallIsAlwaysTwoRadiiAway() {
        let objectBall = SCNVector3(0.3, tableY, 0.2)
        let pocket = SCNVector3(-1.0, tableY, -0.5)
        let ghost = AimingCalculator.ghostBallCenter(objectBall: objectBall, pocket: pocket)

        let distance = (ghost - objectBall).length()
        XCTAssertEqual(distance, BallPhysics.radius * 2, accuracy: 0.001)
    }

    // MARK: - Thickness Calculation

    func testThicknessFullHit() {
        let cueToBall = SCNVector3(0, 0, -1)
        let ballToPocket = SCNVector3(0, 0, -1)
        let thickness = AimingCalculator.calculateThickness(
            cueToBall: cueToBall, ballToPocket: ballToPocket
        )
        XCTAssertEqual(thickness, 1.0, accuracy: 0.01, "Straight shot should be full thickness")
    }

    func testThicknessHalfBall() {
        let cueToBall = SCNVector3(0, 0, -1).normalized()
        let ballToPocket = SCNVector3(1, 0, -1).normalized()
        let thickness = AimingCalculator.calculateThickness(
            cueToBall: cueToBall, ballToPocket: ballToPocket
        )
        // cos(45°) ≈ 0.707
        XCTAssertEqual(thickness, cos(.pi / 4), accuracy: 0.05)
    }

    func testThicknessRangeClampedZeroToOne() {
        let cueToBall = SCNVector3(0, 0, -1)
        let ballToPocket = SCNVector3(0, 0, 1)
        let thickness = AimingCalculator.calculateThickness(
            cueToBall: cueToBall, ballToPocket: ballToPocket
        )
        XCTAssertGreaterThanOrEqual(thickness, 0)
        XCTAssertLessThanOrEqual(thickness, 1)
    }

    // MARK: - Thickness Description

    func testThicknessDescriptionFullThick() {
        XCTAssertEqual(AimingCalculator.thicknessDescription(0.95), "全厚")
    }

    func testThicknessDescriptionHalfBall() {
        XCTAssertEqual(AimingCalculator.thicknessDescription(0.6), "半球")
    }

    func testThicknessDescriptionThin() {
        XCTAssertEqual(AimingCalculator.thicknessDescription(0.3), "薄球")
    }

    func testThicknessDescriptionVeryThin() {
        XCTAssertEqual(AimingCalculator.thicknessDescription(0.1), "极薄")
    }

    // MARK: - Separation Angle

    func testSeparationAnglePureRolling() {
        let angle = AimingCalculator.calculateSeparationAngle(thickness: 1.0, spinY: 0)
        XCTAssertEqual(angle, SeparationAngle.pureRolling, accuracy: 1.0)
    }

    func testSeparationAngleTopSpinReduces() {
        let angleCenter = AimingCalculator.calculateSeparationAngle(thickness: 0.7, spinY: 0)
        let angleTopSpin = AimingCalculator.calculateSeparationAngle(thickness: 0.7, spinY: 0.8)
        XCTAssertLessThan(angleTopSpin, angleCenter,
                          "Top spin should reduce separation angle")
    }

    func testSeparationAngleBackSpinIncreases() {
        let angleCenter = AimingCalculator.calculateSeparationAngle(thickness: 0.7, spinY: 0)
        let angleBackSpin = AimingCalculator.calculateSeparationAngle(thickness: 0.7, spinY: -0.8)
        XCTAssertGreaterThan(angleBackSpin, angleCenter,
                             "Back spin should increase separation angle")
    }

    func testSeparationAngleClamped() {
        let angle1 = AimingCalculator.calculateSeparationAngle(thickness: 0.0, spinY: -1.0)
        XCTAssertGreaterThanOrEqual(angle1, 0)
        XCTAssertLessThanOrEqual(angle1, 180)

        let angle2 = AimingCalculator.calculateSeparationAngle(thickness: 1.0, spinY: 1.0)
        XCTAssertGreaterThanOrEqual(angle2, 0)
        XCTAssertLessThanOrEqual(angle2, 180)
    }

    // MARK: - Path Occlusion

    func testPathOccludedByObstacle() {
        let from = SCNVector3(0, tableY, 0.5)
        let to = SCNVector3(0, tableY, -0.5)
        let obstacle = [SCNVector3(0, tableY, 0)]

        let occluded = AimingCalculator.isPathOccluded(
            from: from, to: to, obstacles: obstacle, ballRadius: BallPhysics.radius
        )
        XCTAssertTrue(occluded, "Direct obstacle should block path")
    }

    func testPathNotOccludedWhenClear() {
        let from = SCNVector3(0, tableY, 0.5)
        let to = SCNVector3(0, tableY, -0.5)
        let obstacle = [SCNVector3(0.5, tableY, 0)]

        let occluded = AimingCalculator.isPathOccluded(
            from: from, to: to, obstacles: obstacle, ballRadius: BallPhysics.radius
        )
        XCTAssertFalse(occluded, "Offset obstacle should not block path")
    }

    func testPathNotOccludedByObstacleBehind() {
        let from = SCNVector3(0, tableY, 0)
        let to = SCNVector3(0, tableY, -0.5)
        let obstacle = [SCNVector3(0, tableY, 0.5)]

        let occluded = AimingCalculator.isPathOccluded(
            from: from, to: to, obstacles: obstacle, ballRadius: BallPhysics.radius
        )
        XCTAssertFalse(occluded, "Obstacle behind start should not block path")
    }

    // MARK: - Difficulty

    func testDifficultyRangeOneToFive() {
        let cueBall = SCNVector3(0, tableY, 0.5)
        let target = SCNVector3(0, tableY, 0)
        let pocket = SCNVector3(0, tableY, -0.635)

        let diff = AimingCalculator.calculateDifficulty(
            cueBall: cueBall, targetBall: target, pocket: pocket, thickness: 0.9
        )
        XCTAssertGreaterThanOrEqual(diff, 1)
        XCTAssertLessThanOrEqual(diff, 5)
    }

    func testThinShotHarderThanThick() {
        let cueBall = SCNVector3(0, tableY, 0.5)
        let target = SCNVector3(0, tableY, 0)
        let pocket = SCNVector3(0, tableY, -0.635)

        let diffThick = AimingCalculator.calculateDifficulty(
            cueBall: cueBall, targetBall: target, pocket: pocket, thickness: 0.9
        )
        let diffThin = AimingCalculator.calculateDifficulty(
            cueBall: cueBall, targetBall: target, pocket: pocket, thickness: 0.15
        )
        XCTAssertGreaterThanOrEqual(diffThin, diffThick)
    }

    // MARK: - Calculate Aim (Integration)

    func testCalculateAimReturnsValidResult() {
        let cueBall = SCNVector3(0, tableY, 0.4)
        let target = SCNVector3(0, tableY, 0)
        let pocket = SCNVector3(0, tableY, -0.635)

        let result = AimingCalculator.calculateAim(
            cueBall: cueBall, targetBall: target, pocket: pocket
        )

        XCTAssertVector3Finite(result.aimPoint)
        XCTAssertVector3Finite(result.aimDirection)
        XCTAssertGreaterThanOrEqual(result.thickness, 0)
        XCTAssertLessThanOrEqual(result.thickness, 1)
        XCTAssertGreaterThanOrEqual(result.separationAngle, 0)
        XCTAssertGreaterThanOrEqual(result.difficulty, 1)
        XCTAssertLessThanOrEqual(result.difficulty, 5)
    }
}
