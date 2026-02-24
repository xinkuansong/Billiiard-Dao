import XCTest
@testable import BilliardTrainer

/// Integration tests for TrainingViewModel.
///
/// Since TrainingViewModel internally creates BilliardSceneViewModel and uses timers,
/// these tests focus on the core logic that can be exercised without a full SceneKit context:
/// - calculateFinalResult()
/// - accuracy computation
/// - combo logic (via manual state setting)
/// - score computation
@MainActor
final class TrainingViewModelTests: XCTestCase {

    // MARK: - Initial State

    func testInitialState() {
        let config = TrainingConfig.aimingConfig(difficulty: 3)
        let vm = TrainingViewModel(config: config)

        XCTAssertEqual(vm.currentScore, 0)
        XCTAssertEqual(vm.shotCount, 0)
        XCTAssertEqual(vm.pocketedCount, 0)
        XCTAssertEqual(vm.comboCount, 0)
        XCTAssertEqual(vm.maxCombo, 0)
        XCTAssertFalse(vm.isTrainingComplete)
        XCTAssertFalse(vm.isPaused)
        XCTAssertFalse(vm.showResult)
        XCTAssertEqual(vm.remainingBalls, config.goalCount)
    }

    func testInitialStateWithTimeLimit() {
        let config = TrainingConfig(groundId: "test", difficulty: 2, timeLimit: 120, trainingType: .aiming)
        let vm = TrainingViewModel(config: config)
        XCTAssertEqual(vm.timeRemaining, 120)
    }

    func testInitialStateNoTimeLimit() {
        let config = TrainingConfig(groundId: "test", difficulty: 2, trainingType: .aiming)
        let vm = TrainingViewModel(config: config)
        XCTAssertNil(vm.timeRemaining)
    }

    // MARK: - Accuracy

    func testAccuracyZeroShots() {
        let vm = TrainingViewModel(config: TrainingConfig.aimingConfig(difficulty: 1))
        XCTAssertEqual(vm.accuracy, 0)
    }

    func testAccuracyComputation() {
        let vm = TrainingViewModel(config: TrainingConfig.aimingConfig(difficulty: 1))
        vm.shotCount = 10
        vm.pocketedCount = 7
        XCTAssertEqual(vm.accuracy, 0.7, accuracy: 0.001)
    }

    func testFormattedAccuracy() {
        let vm = TrainingViewModel(config: TrainingConfig.aimingConfig(difficulty: 1))
        vm.shotCount = 10
        vm.pocketedCount = 8
        XCTAssertEqual(vm.formattedAccuracy, "80%")
    }

    // MARK: - Progress

    func testProgress() {
        let config = TrainingConfig(groundId: "test", difficulty: 1, goalCount: 10, trainingType: .aiming)
        let vm = TrainingViewModel(config: config)
        vm.pocketedCount = 5
        XCTAssertEqual(vm.progress, 0.5, accuracy: 0.001)
    }

    // MARK: - Formatted Time

    func testFormattedTimeRemainingWithValue() {
        let config = TrainingConfig(groundId: "test", difficulty: 1, timeLimit: 125, trainingType: .aiming)
        let vm = TrainingViewModel(config: config)
        XCTAssertEqual(vm.formattedTimeRemaining, "2:05")
    }

    func testFormattedTimeRemainingNoLimit() {
        let vm = TrainingViewModel(config: TrainingConfig.aimingConfig(difficulty: 1))
        XCTAssertEqual(vm.formattedTimeRemaining, "--:--")
    }

    // MARK: - Calculate Final Result

    func testCalculateFinalResultBasic() {
        let config = TrainingConfig(groundId: "test", difficulty: 3, goalCount: 10, trainingType: .aiming)
        let vm = TrainingViewModel(config: config)
        vm.currentScore = 500
        vm.pocketedCount = 5
        vm.shotCount = 8

        let result = vm.calculateFinalResult()
        XCTAssertEqual(result.score, 500)
        XCTAssertEqual(result.pocketedCount, 5)
        XCTAssertEqual(result.totalShots, 8)
        XCTAssertGreaterThanOrEqual(result.stars, 1)
        XCTAssertLessThanOrEqual(result.stars, 5)
    }

    func testCalculateFinalResultPerfectScore() {
        let config = TrainingConfig(groundId: "test", difficulty: 1, goalCount: 10, trainingType: .aiming)
        let vm = TrainingViewModel(config: config)
        // Max possible score = goalCount * (100 + difficulty*10 + 100) = 10 * 210 = 2100
        vm.currentScore = 2100
        vm.pocketedCount = 10
        vm.shotCount = 10

        let result = vm.calculateFinalResult()
        XCTAssertEqual(result.stars, 5)
    }

    func testCalculateFinalResultLowScore() {
        let config = TrainingConfig(groundId: "test", difficulty: 1, goalCount: 10, trainingType: .aiming)
        let vm = TrainingViewModel(config: config)
        vm.currentScore = 100
        vm.pocketedCount = 1
        vm.shotCount = 20

        let result = vm.calculateFinalResult()
        XCTAssertEqual(result.stars, 1)
    }

    // MARK: - Pause / Resume

    func testPauseResume() {
        let vm = TrainingViewModel(config: TrainingConfig.aimingConfig(difficulty: 1))
        XCTAssertFalse(vm.isPaused)
        vm.pauseTraining()
        XCTAssertTrue(vm.isPaused)
        vm.resumeTraining()
        XCTAssertFalse(vm.isPaused)
    }

    // MARK: - End Training

    func testEndTraining() {
        let vm = TrainingViewModel(config: TrainingConfig.aimingConfig(difficulty: 1))
        vm.endTraining()
        XCTAssertTrue(vm.isTrainingComplete)
        XCTAssertTrue(vm.showResult)
    }

    // MARK: - Config Types

    func testAllConfigTypes() {
        let configs = [
            TrainingConfig.aimingConfig(difficulty: 1),
            TrainingConfig.spinConfig(difficulty: 2),
            TrainingConfig.bankShotConfig(difficulty: 3),
            TrainingConfig.kickShotConfig(difficulty: 4),
            TrainingConfig.diamondConfig(difficulty: 5),
        ]

        for config in configs {
            let vm = TrainingViewModel(config: config)
            XCTAssertEqual(vm.currentScore, 0)
            XCTAssertEqual(vm.remainingBalls, config.goalCount)
        }
    }
}
