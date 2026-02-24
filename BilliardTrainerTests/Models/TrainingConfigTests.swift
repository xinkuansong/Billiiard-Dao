import XCTest
import SceneKit
@testable import BilliardTrainer

final class TrainingConfigTests: XCTestCase {

    // MARK: - Difficulty Clamping

    func testDifficultyClampedToMin() {
        let config = TrainingConfig(groundId: "test", difficulty: 0)
        XCTAssertEqual(config.difficulty, 1)
    }

    func testDifficultyClampedToMax() {
        let config = TrainingConfig(groundId: "test", difficulty: 10)
        XCTAssertEqual(config.difficulty, 5)
    }

    func testDifficultyInRange() {
        for d in 1...5 {
            let config = TrainingConfig(groundId: "test", difficulty: d)
            XCTAssertEqual(config.difficulty, d)
        }
    }

    func testDifficultyNegativeClamped() {
        let config = TrainingConfig(groundId: "test", difficulty: -3)
        XCTAssertEqual(config.difficulty, 1)
    }

    // MARK: - Factory Methods

    func testAimingConfigReturnsCorrectType() {
        let config = TrainingConfig.aimingConfig(difficulty: 3)
        XCTAssertEqual(config.trainingType, .aiming)
        XCTAssertEqual(config.difficulty, 3)
        XCTAssertEqual(config.goalCount, 10)
    }

    func testSpinConfigReturnsCorrectType() {
        let config = TrainingConfig.spinConfig(difficulty: 2)
        XCTAssertEqual(config.trainingType, .spin)
        XCTAssertEqual(config.difficulty, 2)
    }

    func testBankShotConfigReturnsCorrectType() {
        let config = TrainingConfig.bankShotConfig(difficulty: 4)
        XCTAssertEqual(config.trainingType, .bankShot)
        XCTAssertEqual(config.difficulty, 4)
    }

    func testKickShotConfigReturnsCorrectType() {
        let config = TrainingConfig.kickShotConfig(difficulty: 1)
        XCTAssertEqual(config.trainingType, .kickShot)
    }

    func testDiamondConfigReturnsCorrectType() {
        let config = TrainingConfig.diamondConfig(difficulty: 5)
        XCTAssertEqual(config.trainingType, .diamond)
        XCTAssertEqual(config.difficulty, 5)
    }

    // MARK: - TrainingSceneType

    func testAllTrainingTypesHaveIcons() {
        for type in TrainingSceneType.allCases {
            XCTAssertFalse(type.iconName.isEmpty, "\(type) should have an icon")
        }
    }

    func testAllTrainingTypesHaveDescriptions() {
        for type in TrainingSceneType.allCases {
            XCTAssertFalse(type.description.isEmpty, "\(type) should have a description")
        }
    }

    // MARK: - BallPosition

    func testCueBallIsCueBall() {
        let pos = BallPosition(ballNumber: 0, x: 0, z: 0)
        XCTAssertTrue(pos.isCueBall)
    }

    func testTargetBallIsNotCueBall() {
        let pos = BallPosition(ballNumber: 1, x: 0, z: 0)
        XCTAssertFalse(pos.isCueBall)
    }

    func testDefaultCueBallPosition() {
        let pos = BallPosition.defaultCueBall
        XCTAssertTrue(pos.isCueBall)
        XCTAssertEqual(pos.ballNumber, 0)
        XCTAssertEqual(pos.position.x, -TablePhysics.innerLength / 4, accuracy: 0.01)
    }

    func testStraightTargetPosition() {
        let pos = BallPosition.straightTarget(number: 1)
        XCTAssertEqual(pos.ballNumber, 1)
        XCTAssertEqual(pos.position.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(pos.position.z, 0, accuracy: 0.001)
    }

    func testAngleTargetPosition() {
        let pos = BallPosition.angleTarget(number: 2, angle: 30)
        XCTAssertEqual(pos.ballNumber, 2)
        let expectedZ = 0.5 * sin(30 * Float.pi / 180)
        XCTAssertEqual(pos.position.z, expectedZ, accuracy: 0.01)
    }

    func testBallPositionYHeight() {
        let pos = BallPosition(ballNumber: 1, x: 0, z: 0)
        let expectedY = TablePhysics.height + BallPhysics.radius + 0.001
        XCTAssertEqual(pos.position.y, expectedY, accuracy: 0.001)
    }

    // MARK: - TargetZone

    func testTargetZoneContainsCenter() {
        let zone = TargetZone(x: 0, z: 0, radius: 0.1)
        let center = SCNVector3(0, TablePhysics.height + 0.001, 0)
        XCTAssertTrue(zone.contains(center))
    }

    func testTargetZoneContainsPointInsideRadius() {
        let zone = TargetZone(x: 0, z: 0, radius: 0.1)
        let inside = SCNVector3(0.05, 0, 0.05)
        XCTAssertTrue(zone.contains(inside))
    }

    func testTargetZoneDoesNotContainPointOutside() {
        let zone = TargetZone(x: 0, z: 0, radius: 0.1)
        let outside = SCNVector3(0.2, 0, 0.2)
        XCTAssertFalse(zone.contains(outside))
    }

    func testTargetZoneDistanceRatioCenter() {
        let zone = TargetZone(x: 0, z: 0, radius: 0.2)
        let ratio = zone.distanceRatio(from: SCNVector3(0, 0, 0))
        XCTAssertEqual(ratio, 0, accuracy: 0.001)
    }

    func testTargetZoneDistanceRatioEdge() {
        let zone = TargetZone(x: 0, z: 0, radius: 0.2)
        let ratio = zone.distanceRatio(from: SCNVector3(0.2, 0, 0))
        XCTAssertEqual(ratio, 1.0, accuracy: 0.01)
    }

    func testTargetZoneDistanceRatioOutside() {
        let zone = TargetZone(x: 0, z: 0, radius: 0.2)
        let ratio = zone.distanceRatio(from: SCNVector3(0.4, 0, 0))
        XCTAssertGreaterThan(ratio, 1.0)
    }

    // MARK: - TrainingResult

    func testTrainingResultAccuracy() {
        let result = TrainingResult(score: 80, pocketedCount: 8, totalShots: 10, duration: 120, stars: 4)
        XCTAssertEqual(result.accuracy, 0.8, accuracy: 0.001)
    }

    func testTrainingResultAccuracyZeroShots() {
        let result = TrainingResult(score: 0, pocketedCount: 0, totalShots: 0, duration: 0, stars: 1)
        XCTAssertEqual(result.accuracy, 0)
    }

    func testTrainingResultFormattedAccuracy() {
        let result = TrainingResult(score: 80, pocketedCount: 8, totalShots: 10, duration: 120, stars: 4)
        XCTAssertEqual(result.formattedAccuracy, "80.0%")
    }

    func testTrainingResultFormattedDuration() {
        let result = TrainingResult(score: 80, pocketedCount: 8, totalShots: 10, duration: 125, stars: 4)
        XCTAssertEqual(result.formattedDuration, "2:05")
    }

    // MARK: - Star Calculation

    func testStarCalculation5Stars() {
        XCTAssertEqual(TrainingResult.calculateStars(score: 90, maxScore: 100), 5)
        XCTAssertEqual(TrainingResult.calculateStars(score: 100, maxScore: 100), 5)
    }

    func testStarCalculation4Stars() {
        XCTAssertEqual(TrainingResult.calculateStars(score: 75, maxScore: 100), 4)
        XCTAssertEqual(TrainingResult.calculateStars(score: 89, maxScore: 100), 4)
    }

    func testStarCalculation3Stars() {
        XCTAssertEqual(TrainingResult.calculateStars(score: 60, maxScore: 100), 3)
        XCTAssertEqual(TrainingResult.calculateStars(score: 74, maxScore: 100), 3)
    }

    func testStarCalculation2Stars() {
        XCTAssertEqual(TrainingResult.calculateStars(score: 40, maxScore: 100), 2)
        XCTAssertEqual(TrainingResult.calculateStars(score: 59, maxScore: 100), 2)
    }

    func testStarCalculation1Star() {
        XCTAssertEqual(TrainingResult.calculateStars(score: 0, maxScore: 100), 1)
        XCTAssertEqual(TrainingResult.calculateStars(score: 39, maxScore: 100), 1)
    }
}
