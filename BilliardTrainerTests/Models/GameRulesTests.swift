import XCTest
@testable import BilliardTrainer

final class GameRulesTests: XCTestCase {

    // MARK: - Legal Shot

    func testLegalShotSolidsHitSolid() {
        let events: [GameEvent] = [
            .ballBallCollision(ball1: "cueBall", ball2: "ball_3", time: 0.1),
            .ballCushionCollision(ball: "ball_3", time: 0.3),
        ]
        let result = EightBallRules.isLegalShot(events: events, currentGroup: .solids)
        XCTAssertTrue(result.legal)
        XCTAssertTrue(result.fouls.isEmpty)
    }

    func testLegalShotStripesHitStripe() {
        let events: [GameEvent] = [
            .ballBallCollision(ball1: "cueBall", ball2: "ball_11", time: 0.1),
            .ballPocketed(ball: "ball_11", pocket: "pocket_0", time: 0.5),
        ]
        let result = EightBallRules.isLegalShot(events: events, currentGroup: .stripes)
        XCTAssertTrue(result.legal)
        XCTAssertTrue(result.fouls.isEmpty)
    }

    func testLegalShotOpenGroup() {
        let events: [GameEvent] = [
            .ballBallCollision(ball1: "cueBall", ball2: "ball_1", time: 0.1),
            .ballCushionCollision(ball: "cueBall", time: 0.3),
        ]
        let result = EightBallRules.isLegalShot(events: events, currentGroup: .open)
        XCTAssertTrue(result.legal)
    }

    // MARK: - Cue Ball Pocketed Foul

    func testCueBallPocketedIsFoul() {
        let events: [GameEvent] = [
            .ballBallCollision(ball1: "cueBall", ball2: "ball_3", time: 0.1),
            .ballCushionCollision(ball: "cueBall", time: 0.2),
            .cueBallPocketed(time: 0.5),
        ]
        let result = EightBallRules.isLegalShot(events: events, currentGroup: .solids)
        XCTAssertFalse(result.legal)
        XCTAssertTrue(result.fouls.contains(.cueBallPocketed))
    }

    // MARK: - Wrong First Hit Foul

    func testWrongFirstHitSolidsHitStripe() {
        let events: [GameEvent] = [
            .ballBallCollision(ball1: "cueBall", ball2: "ball_10", time: 0.1),
            .ballCushionCollision(ball: "ball_10", time: 0.3),
        ]
        let result = EightBallRules.isLegalShot(events: events, currentGroup: .solids)
        XCTAssertFalse(result.legal)
        XCTAssertTrue(result.fouls.contains(.wrongFirstHit))
    }

    func testWrongFirstHitStripesHitSolid() {
        let events: [GameEvent] = [
            .ballBallCollision(ball1: "cueBall", ball2: "ball_5", time: 0.1),
            .ballCushionCollision(ball: "ball_5", time: 0.3),
        ]
        let result = EightBallRules.isLegalShot(events: events, currentGroup: .stripes)
        XCTAssertFalse(result.legal)
        XCTAssertTrue(result.fouls.contains(.wrongFirstHit))
    }

    // MARK: - No Ball Hit Foul

    func testNoBallHitFoul() {
        let events: [GameEvent] = []
        let result = EightBallRules.isLegalShot(events: events, currentGroup: .solids)
        XCTAssertFalse(result.legal)
        XCTAssertTrue(result.fouls.contains(.noBallHit))
    }

    func testNoBallHitOnlyCushionContact() {
        let events: [GameEvent] = [
            .ballCushionCollision(ball: "cueBall", time: 0.2),
        ]
        let result = EightBallRules.isLegalShot(events: events, currentGroup: .solids)
        XCTAssertFalse(result.legal)
        XCTAssertTrue(result.fouls.contains(.noBallHit))
    }

    // MARK: - No Cushion After Contact Foul

    func testNoCushionAfterContactFoul() {
        let events: [GameEvent] = [
            .ballBallCollision(ball1: "cueBall", ball2: "ball_3", time: 0.1),
            // No cushion contact and no ball pocketed
        ]
        let result = EightBallRules.isLegalShot(events: events, currentGroup: .solids)
        XCTAssertFalse(result.legal)
        XCTAssertTrue(result.fouls.contains(.noCushionAfterContact))
    }

    func testNoCushionButBallPocketedIsLegal() {
        let events: [GameEvent] = [
            .ballBallCollision(ball1: "cueBall", ball2: "ball_3", time: 0.1),
            .ballPocketed(ball: "ball_3", pocket: "pocket_0", time: 0.5),
        ]
        let result = EightBallRules.isLegalShot(events: events, currentGroup: .solids)
        XCTAssertTrue(result.legal, "Pocketing a ball should satisfy the cushion requirement")
    }

    // MARK: - Multiple Fouls

    func testMultipleFoulsAtOnce() {
        let events: [GameEvent] = [
            .ballBallCollision(ball1: "cueBall", ball2: "ball_10", time: 0.1),
            .cueBallPocketed(time: 0.5),
        ]
        let result = EightBallRules.isLegalShot(events: events, currentGroup: .solids)
        XCTAssertFalse(result.legal)
        XCTAssertTrue(result.fouls.contains(.cueBallPocketed))
        XCTAssertTrue(result.fouls.contains(.wrongFirstHit))
        XCTAssertTrue(result.fouls.contains(.noCushionAfterContact))
    }

    // MARK: - Edge Cases

    func testBall8FirstHitSolids() {
        let events: [GameEvent] = [
            .ballBallCollision(ball1: "cueBall", ball2: "ball_8", time: 0.1),
            .ballCushionCollision(ball: "ball_8", time: 0.3),
        ]
        let result = EightBallRules.isLegalShot(events: events, currentGroup: .solids)
        // 8 ball is neither solid (1-7) nor stripe (9-15), so wrongFirstHit
        XCTAssertFalse(result.legal)
        XCTAssertTrue(result.fouls.contains(.wrongFirstHit))
    }

    func testUSDZBallNameFormat() {
        let events: [GameEvent] = [
            .ballBallCollision(ball1: "cueBall", ball2: "_3", time: 0.1),
            .ballCushionCollision(ball: "_3", time: 0.3),
        ]
        let result = EightBallRules.isLegalShot(events: events, currentGroup: .solids)
        XCTAssertTrue(result.legal, "Should support USDZ ball name format _N")
    }
}
