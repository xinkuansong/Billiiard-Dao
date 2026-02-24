import XCTest
import SceneKit
@testable import BilliardTrainer

final class DiamondSystemTests: XCTestCase {

    let tableY = TablePhysics.height + BallPhysics.radius
    let halfLength = TablePhysics.innerLength / 2
    let halfWidth = TablePhysics.innerWidth / 2

    // MARK: - Diamond Position World Coordinates

    func testDiamondPositionTopEdge() {
        let diamond = DiamondSystemCalculator.DiamondPosition(edge: .top, number: 4)
        let pos = diamond.worldPosition
        XCTAssertEqual(pos.x, 0, accuracy: 0.01, "Diamond 4 on top edge should be at center X")
        XCTAssertEqual(pos.z, halfWidth, accuracy: 0.01, "Top edge should be at +halfWidth")
    }

    func testDiamondPositionBottomEdge() {
        let diamond = DiamondSystemCalculator.DiamondPosition(edge: .bottom, number: 0)
        let pos = diamond.worldPosition
        XCTAssertEqual(pos.x, -halfLength, accuracy: 0.01)
        XCTAssertEqual(pos.z, -halfWidth, accuracy: 0.01)
    }

    func testDiamondPositionLeftEdge() {
        let diamond = DiamondSystemCalculator.DiamondPosition(edge: .left, number: 2)
        let pos = diamond.worldPosition
        XCTAssertEqual(pos.x, -halfLength, accuracy: 0.01)
        XCTAssertEqual(pos.z, 0, accuracy: 0.01, "Diamond 2 on left edge should be at center Z")
    }

    func testDiamondPositionRightEdge() {
        let diamond = DiamondSystemCalculator.DiamondPosition(edge: .right, number: 4)
        let pos = diamond.worldPosition
        XCTAssertEqual(pos.x, halfLength, accuracy: 0.01)
        XCTAssertEqual(pos.z, halfWidth, accuracy: 0.01)
    }

    // MARK: - One Rail Calculation

    func testOneRailBankReturnsResult() {
        let cueBall = SCNVector3(0, tableY, 0.3)
        let targetPocket = SCNVector3(-halfLength - 0.04, tableY, -halfWidth - 0.04)

        let result = DiamondSystemCalculator.calculateOneRailBank(
            cueBall: cueBall, targetPocket: targetPocket
        )

        XCTAssertNotNil(result, "One rail calculation should return a result")
        if let r = result {
            XCTAssertFalse(r.formula.isEmpty, "Should have a formula description")
            XCTAssertTrue(r.recommendedPower > 0)
        }
    }

    // MARK: - Two Rail Calculation

    func testTwoRailKickReturnsResult() {
        let cueBall = SCNVector3(-0.5, tableY, 0.3)
        let targetBall = SCNVector3(0.5, tableY, -0.2)

        let result = DiamondSystemCalculator.calculateTwoRailKick(
            cueBall: cueBall, targetBall: targetBall, firstRailEdge: .top
        )

        XCTAssertNotNil(result)
        if let r = result {
            XCTAssertFalse(r.formula.isEmpty)
        }
    }

    // MARK: - Three Rail Calculation

    func testThreeRailPathReturnsResult() {
        let cueBall = SCNVector3(-0.5, tableY, 0.3)
        let targetBall = SCNVector3(0.5, tableY, -0.2)

        let result = DiamondSystemCalculator.calculateThreeRailPath(
            cueBall: cueBall, targetBall: targetBall
        )

        XCTAssertNotNil(result)
        if let r = result {
            XCTAssertFalse(r.formula.isEmpty)
            XCTAssertEqual(r.recommendedEnglish, -0.5, accuracy: 0.01,
                           "Three rail should recommend reverse english")
        }
    }

    // MARK: - English Correction

    func testEnglishCorrectionLargeAngle() {
        let correction = DiamondSystemCalculator.calculateEnglishCorrection(
            startDiamond: 6, targetDiamond: 1
        )
        XCTAssertEqual(correction, -0.5, accuracy: 0.01,
                       "Large angle should recommend reverse english")
    }

    func testEnglishCorrectionSmallAngle() {
        let correction = DiamondSystemCalculator.calculateEnglishCorrection(
            startDiamond: 3, targetDiamond: 2.5
        )
        XCTAssertEqual(correction, 0, accuracy: 0.01,
                       "Small angle should not need english")
    }

    // MARK: - Speed Correction

    func testSpeedCorrectionHighPower() {
        let correction = DiamondSystemCalculator.calculateSpeedCorrection(power: 0.8)
        XCTAssertLessThan(correction, 0, "High power should reduce diamond count")
    }

    func testSpeedCorrectionLowPower() {
        let correction = DiamondSystemCalculator.calculateSpeedCorrection(power: 0.2)
        XCTAssertGreaterThan(correction, 0, "Low power should increase diamond count")
    }

    func testSpeedCorrectionMediumPower() {
        let correction = DiamondSystemCalculator.calculateSpeedCorrection(power: 0.5)
        XCTAssertEqual(correction, 0, accuracy: 0.01)
    }

    // MARK: - Bank Shot Calculator

    func testBankShotCalculation() {
        let cueBall = SCNVector3(0, tableY, 0)
        let targetBall = SCNVector3(0.3, tableY, 0.2)
        let pocket = SCNVector3(halfLength + 0.04, tableY, halfWidth + 0.04)

        let bankPoint = BankShotCalculator.calculateBankShot(
            cueBall: cueBall, targetBall: targetBall,
            pocket: pocket, railEdge: .top
        )

        if let point = bankPoint {
            XCTAssertTrue(point.x.isFinite)
            XCTAssertTrue(point.z.isFinite)
            // Bank point should be on the top rail (z ≈ halfWidth)
            XCTAssertEqual(point.z, halfWidth, accuracy: 0.01)
        }
    }
}
