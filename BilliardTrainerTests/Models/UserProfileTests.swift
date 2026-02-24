import XCTest
import SwiftData
@testable import BilliardTrainer

final class UserProfileTests: XCTestCase {

    // MARK: - Initialization

    func testDefaultValues() {
        let profile = UserProfile()
        XCTAssertEqual(profile.nickname, "新玩家")
        XCTAssertEqual(profile.level, 1)
        XCTAssertEqual(profile.experience, 0)
        XCTAssertTrue(profile.soundEnabled)
        XCTAssertTrue(profile.hapticEnabled)
        XCTAssertTrue(profile.aimLineEnabled)
        XCTAssertFalse(profile.trajectoryEnabled)
        XCTAssertTrue(profile.purchasedProducts.isEmpty)
    }

    func testCustomNickname() {
        let profile = UserProfile(nickname: "台球高手")
        XCTAssertEqual(profile.nickname, "台球高手")
    }

    // MARK: - Level System

    func testLevelNameMapping() {
        let names = [(1, "新手"), (2, "入门"), (3, "进阶"), (4, "熟练"), (5, "专家"), (6, "大师")]
        for (level, name) in names {
            let profile = UserProfile(level: level)
            XCTAssertEqual(profile.levelName, name,
                           "Level \(level) should be \(name)")
        }
    }

    func testExperienceToNextLevel() {
        let expected = [(1, 500), (2, 1500), (3, 4000), (4, 10000), (5, 10000)]
        for (level, exp) in expected {
            let profile = UserProfile(level: level)
            XCTAssertEqual(profile.experienceToNextLevel, exp)
        }
    }

    func testAddExperienceWithoutLevelUp() {
        let profile = UserProfile()
        profile.addExperience(100)
        XCTAssertEqual(profile.experience, 100)
        XCTAssertEqual(profile.level, 1)
    }

    func testAddExperienceTriggersLevelUp() {
        let profile = UserProfile()
        profile.addExperience(500)
        XCTAssertEqual(profile.level, 2)
        XCTAssertEqual(profile.experience, 0)
    }

    func testAddExperienceMultipleLevelUps() {
        let profile = UserProfile()
        profile.addExperience(2100)
        // 500 -> level 2 (remaining 1600), 1500 -> level 3 (remaining 100)
        XCTAssertEqual(profile.level, 3)
        XCTAssertEqual(profile.experience, 100)
    }

    func testLevelCapAtFive() {
        let profile = UserProfile()
        profile.addExperience(100000)
        XCTAssertEqual(profile.level, 5)
    }

    // MARK: - Purchases

    func testHasPurchasedInitiallyFalse() {
        let profile = UserProfile()
        XCTAssertFalse(profile.hasPurchased("premium"))
    }

    func testAddPurchase() {
        let profile = UserProfile()
        profile.addPurchase("course_pack_1")
        XCTAssertTrue(profile.hasPurchased("course_pack_1"))
    }

    func testDuplicatePurchaseNotAdded() {
        let profile = UserProfile()
        profile.addPurchase("premium")
        profile.addPurchase("premium")
        XCTAssertEqual(profile.purchasedProducts.count, 1)
    }
}

// MARK: - UserStatistics Tests

final class UserStatisticsTests: XCTestCase {

    // MARK: - Initialization

    func testInitialValues() {
        let stats = UserStatistics(userId: UUID())
        XCTAssertEqual(stats.totalShots, 0)
        XCTAssertEqual(stats.totalPocketed, 0)
        XCTAssertEqual(stats.totalPracticeTime, 0)
        XCTAssertEqual(stats.consecutiveDays, 0)
    }

    // MARK: - Accuracy

    func testOverallAccuracyZeroShots() {
        let stats = UserStatistics(userId: UUID())
        XCTAssertEqual(stats.overallAccuracy, 0)
    }

    func testOverallAccuracy() {
        let stats = UserStatistics(userId: UUID())
        stats.recordShot(type: .straight, made: true)
        stats.recordShot(type: .straight, made: true)
        stats.recordShot(type: .straight, made: false)
        XCTAssertEqual(stats.overallAccuracy, 2.0 / 3.0, accuracy: 0.001)
    }

    func testStraightShotAccuracy() {
        let stats = UserStatistics(userId: UUID())
        stats.recordShot(type: .straight, made: true)
        stats.recordShot(type: .straight, made: false)
        XCTAssertEqual(stats.straightShotAccuracy, 0.5, accuracy: 0.001)
        XCTAssertEqual(stats.straightShotsAttempted, 2)
        XCTAssertEqual(stats.straightShotsMade, 1)
    }

    func testAngle30Accuracy() {
        let stats = UserStatistics(userId: UUID())
        stats.recordShot(type: .angle30, made: true)
        stats.recordShot(type: .angle30, made: true)
        stats.recordShot(type: .angle30, made: false)
        XCTAssertEqual(stats.angle30Accuracy, 2.0 / 3.0, accuracy: 0.001)
    }

    func testAngle45Accuracy() {
        let stats = UserStatistics(userId: UUID())
        stats.recordShot(type: .angle45, made: false)
        stats.recordShot(type: .angle45, made: true)
        XCTAssertEqual(stats.angle45Accuracy, 0.5, accuracy: 0.001)
    }

    func testAngle60Accuracy() {
        let stats = UserStatistics(userId: UUID())
        stats.recordShot(type: .angle60, made: true)
        XCTAssertEqual(stats.angle60Accuracy, 1.0, accuracy: 0.001)
    }

    // MARK: - Spin Recording

    func testRecordSpin() {
        let stats = UserStatistics(userId: UUID())
        stats.recordSpin(type: .center)
        stats.recordSpin(type: .top)
        stats.recordSpin(type: .draw)
        stats.recordSpin(type: .left)
        stats.recordSpin(type: .right)
        XCTAssertEqual(stats.centerShotCount, 1)
        XCTAssertEqual(stats.topSpinCount, 1)
        XCTAssertEqual(stats.drawShotCount, 1)
        XCTAssertEqual(stats.leftEnglishCount, 1)
        XCTAssertEqual(stats.rightEnglishCount, 1)
    }

    // MARK: - Practice Time

    func testAddPracticeTime() {
        let stats = UserStatistics(userId: UUID())
        stats.addPracticeTime(300)
        XCTAssertEqual(stats.totalPracticeTime, 300)
        stats.addPracticeTime(200)
        XCTAssertEqual(stats.totalPracticeTime, 500)
    }

    func testFormattedPracticeTimeMinutesOnly() {
        let stats = UserStatistics(userId: UUID())
        stats.addPracticeTime(1500) // 25 minutes
        XCTAssertEqual(stats.formattedPracticeTime, "25分钟")
    }

    func testFormattedPracticeTimeWithHours() {
        let stats = UserStatistics(userId: UUID())
        stats.addPracticeTime(3900) // 1h 5min
        XCTAssertEqual(stats.formattedPracticeTime, "1小时5分钟")
    }

    // MARK: - Check-in

    func testFirstCheckIn() {
        let stats = UserStatistics(userId: UUID())
        stats.updateCheckIn()
        XCTAssertEqual(stats.consecutiveDays, 1)
        XCTAssertNotNil(stats.lastPracticeDate)
    }

    func testSameDayCheckInDoesNotIncrement() {
        let stats = UserStatistics(userId: UUID())
        stats.updateCheckIn()
        let firstDays = stats.consecutiveDays
        stats.updateCheckIn()
        XCTAssertEqual(stats.consecutiveDays, firstDays)
    }
}

// MARK: - CourseProgress Tests

final class CourseProgressTests: XCTestCase {

    func testInitialState() {
        let progress = CourseProgress(userId: UUID(), courseId: 1)
        XCTAssertFalse(progress.isCompleted)
        XCTAssertNil(progress.completedAt)
        XCTAssertEqual(progress.bestScore, 0)
        XCTAssertEqual(progress.practiceCount, 0)
    }

    func testMarkCompleted() {
        let progress = CourseProgress(userId: UUID(), courseId: 1)
        progress.markCompleted(score: 85)
        XCTAssertTrue(progress.isCompleted)
        XCTAssertNotNil(progress.completedAt)
        XCTAssertEqual(progress.bestScore, 85)
        XCTAssertEqual(progress.practiceCount, 1)
    }

    func testBestScoreOnlyIncreases() {
        let progress = CourseProgress(userId: UUID(), courseId: 1)
        progress.markCompleted(score: 85)
        progress.markCompleted(score: 70)
        XCTAssertEqual(progress.bestScore, 85)
        progress.markCompleted(score: 95)
        XCTAssertEqual(progress.bestScore, 95)
    }

    func testPracticeCountIncrements() {
        let progress = CourseProgress(userId: UUID(), courseId: 1)
        progress.markCompleted(score: 80)
        progress.markCompleted(score: 90)
        progress.markCompleted(score: 70)
        XCTAssertEqual(progress.practiceCount, 3)
    }
}

// MARK: - TrainingSession Tests

final class TrainingSessionTests: XCTestCase {

    func testInitialState() {
        let session = TrainingSession(userId: UUID(), trainingType: "aiming")
        XCTAssertEqual(session.totalShots, 0)
        XCTAssertEqual(session.pocketedCount, 0)
        XCTAssertEqual(session.score, 0)
        XCTAssertNil(session.endTime)
    }

    func testAccuracyZeroShots() {
        let session = TrainingSession(userId: UUID(), trainingType: "aiming")
        XCTAssertEqual(session.accuracy, 0)
    }

    func testAccuracy() {
        let session = TrainingSession(userId: UUID(), trainingType: "aiming")
        session.totalShots = 10
        session.pocketedCount = 7
        XCTAssertEqual(session.accuracy, 0.7, accuracy: 0.001)
    }

    func testEndSession() {
        let session = TrainingSession(userId: UUID(), trainingType: "aiming")
        XCTAssertNil(session.endTime)
        session.endSession()
        XCTAssertNotNil(session.endTime)
    }

    func testDuration() {
        let session = TrainingSession(userId: UUID(), trainingType: "aiming")
        // Duration should be > 0 since startTime is slightly in the past
        let dur = session.duration
        XCTAssertGreaterThanOrEqual(dur, 0)
    }
}
