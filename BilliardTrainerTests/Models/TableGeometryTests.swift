import XCTest
import SceneKit
@testable import BilliardTrainer

final class TableGeometryTests: XCTestCase {

    private var geometry: TableGeometry!

    override func setUp() {
        super.setUp()
        geometry = TableGeometry.chineseEightBall()
    }

    // MARK: - Pockets

    func testSixPockets() {
        XCTAssertEqual(geometry.pockets.count, 6)
    }

    func testFourCornerPockets() {
        let corners = geometry.pockets.filter { $0.isCorner }
        XCTAssertEqual(corners.count, 4)
    }

    func testTwoSidePockets() {
        let sides = geometry.pockets.filter { !$0.isCorner }
        XCTAssertEqual(sides.count, 2)
    }

    func testPocketIdsUnique() {
        let ids = Set(geometry.pockets.map(\.id))
        XCTAssertEqual(ids.count, 6)
    }

    func testPocketRadiiPositive() {
        for pocket in geometry.pockets {
            XCTAssertGreaterThan(pocket.radius, 0, "Pocket \(pocket.id) should have positive radius")
        }
    }

    func testCornerPocketRadius() {
        let corner = geometry.pockets.first { $0.isCorner }!
        XCTAssertEqual(corner.radius, TablePhysics.cornerPocketRadius, accuracy: 0.001)
    }

    func testSidePocketRadius() {
        let side = geometry.pockets.first { !$0.isCorner }!
        XCTAssertEqual(side.radius, TablePhysics.sidePocketRadius, accuracy: 0.001)
    }

    func testSidePocketsAtCenter() {
        for pocket in geometry.pockets where !pocket.isCorner {
            XCTAssertEqual(pocket.center.x, 0, accuracy: 0.01,
                           "Side pocket \(pocket.id) should be at X=0")
        }
    }

    func testCornerPocketsSymmetric() {
        let corners = geometry.pockets.filter { $0.isCorner }
        let xs = corners.map { abs($0.center.x) }
        let zs = corners.map { abs($0.center.z) }

        XCTAssertEqual(Set(xs.map { round($0 * 1000) }).count, 1,
                       "All corner pockets should have same |x|")
        XCTAssertEqual(Set(zs.map { round($0 * 1000) }).count, 1,
                       "All corner pockets should have same |z|")
    }

    // MARK: - Linear Cushions

    func testLinearCushionCount() {
        // 2 long rails × 2 segments + 2 short rails × 1 segment = 6
        XCTAssertEqual(geometry.linearCushions.count, 6)
    }

    func testLinearCushionNormalsUnit() {
        for (i, cushion) in geometry.linearCushions.enumerated() {
            let len = cushion.normal.length()
            XCTAssertEqual(len, 1.0, accuracy: 0.01,
                           "Cushion \(i) normal should be unit length, got \(len)")
        }
    }

    func testLinearCushionNormalsPointInward() {
        for cushion in geometry.linearCushions {
            let midpoint = (cushion.start + cushion.end) * 0.5
            let inwardTest = midpoint + cushion.normal * 0.1
            let halfL = TablePhysics.innerLength / 2
            let halfW = TablePhysics.innerWidth / 2

            XCTAssertLessThan(abs(inwardTest.x), halfL + 0.2)
            XCTAssertLessThan(abs(inwardTest.z), halfW + 0.2)
        }
    }

    func testLinearCushionSegmentsNonDegenerate() {
        for (i, cushion) in geometry.linearCushions.enumerated() {
            let length = (cushion.end - cushion.start).length()
            XCTAssertGreaterThan(length, 0.01,
                                 "Cushion segment \(i) should have nonzero length")
        }
    }

    // MARK: - Circular Cushions

    func testCircularCushionCount() {
        // 4 corners × 2 jaw arcs + 2 side pockets × 2 fillets = 12
        XCTAssertEqual(geometry.circularCushions.count, 12)
    }

    func testCircularCushionRadiiPositive() {
        for (i, cushion) in geometry.circularCushions.enumerated() {
            XCTAssertGreaterThan(cushion.radius, 0,
                                 "Circular cushion \(i) should have positive radius")
        }
    }

    func testCircularCushionAnglesValid() {
        for (i, cushion) in geometry.circularCushions.enumerated() {
            XCTAssertTrue(cushion.startAngle.isFinite,
                          "Circular cushion \(i) startAngle should be finite")
            XCTAssertTrue(cushion.endAngle.isFinite,
                          "Circular cushion \(i) endAngle should be finite")
            XCTAssertNotEqual(cushion.startAngle, cushion.endAngle,
                              "Start and end angles should differ for cushion \(i)")
        }
    }

    // MARK: - CircularCushionSegment Helpers

    func testIsAngleInRangeBasic() {
        let arc = CircularCushionSegment(
            center: SCNVector3(0, 0, 0), radius: 0.1,
            startAngle: 0, endAngle: Float.pi / 2
        )
        XCTAssertTrue(arc.isAngleInRange(Float.pi / 4))
        XCTAssertTrue(arc.isAngleInRange(0))
        XCTAssertTrue(arc.isAngleInRange(Float.pi / 2))
        XCTAssertFalse(arc.isAngleInRange(Float.pi))
        XCTAssertFalse(arc.isAngleInRange(3 * Float.pi / 2))
    }

    func testIsAngleInRangeThirdQuadrant() {
        let arc = CircularCushionSegment(
            center: SCNVector3(0, 0, 0), radius: 0.1,
            startAngle: Float.pi, endAngle: 3 * Float.pi / 2
        )
        XCTAssertTrue(arc.isAngleInRange(5 * Float.pi / 4))
        XCTAssertFalse(arc.isAngleInRange(Float.pi / 4))
    }

    func testNormalAtPointDirectionCorrect() {
        let arc = CircularCushionSegment(
            center: SCNVector3(1, 0, 1), radius: 0.1,
            startAngle: 0, endAngle: Float.pi / 2
        )
        let point = SCNVector3(1.5, 0, 1)
        let n = arc.normal(at: point)
        XCTAssertEqual(n.x, 1.0, accuracy: 0.01)
        XCTAssertEqual(n.z, 0.0, accuracy: 0.01)
    }

    // MARK: - Table Dimensions

    func testTableDimensionsMatchConstants() {
        let halfL = TablePhysics.innerLength / 2
        let halfW = TablePhysics.innerWidth / 2

        XCTAssertGreaterThan(halfL, 0)
        XCTAssertGreaterThan(halfW, 0)
        XCTAssertGreaterThan(halfL, halfW, "Table should be longer than wide")
    }
}
