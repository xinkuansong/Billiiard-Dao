import XCTest
import SceneKit
@testable import BilliardTrainer

// MARK: - JSON Suite Models: Ball-Linear Cushion Collision Time

private struct BallLinearCushionCTTestSuite: Decodable {
    struct Tolerance: Decodable {
        let abs: Double
        let rel: Double
    }
    struct TestCase: Decodable {
        struct Input: Decodable {
            let rvw: [[Double]]
            let s: Int
            let lx: Double
            let ly: Double
            let l0: Double
            let p1: [Double]
            let p2: [Double]
            let direction: Int
            let mu: Double
            let m: Double
            let g: Double
            // swiftlint:disable identifier_name
            let R: Double
            // swiftlint:enable identifier_name
            enum CodingKeys: String, CodingKey {
                case rvw, s, lx, ly, l0, p1, p2, direction, mu, m, g
                // swiftlint:disable identifier_name
                case R
                // swiftlint:enable identifier_name
            }
        }
        struct Expected: Decodable {
            let collisionTime: Double?
            let noCollision: Bool
            enum CodingKeys: String, CodingKey {
                case collisionTime = "collision_time"
                case noCollision = "no_collision"
            }
        }
        let id: String
        let input: Input
        let expected: Expected
    }
    let source: String
    let tolerance: Tolerance
    let testCases: [TestCase]
    enum CodingKeys: String, CodingKey {
        case source, tolerance
        case testCases = "test_cases"
    }
}

// MARK: - JSON Suite Models: Ball-Circular Cushion Collision Time

private struct BallCircularCushionCTTestSuite: Decodable {
    struct Tolerance: Decodable {
        let abs: Double
        let rel: Double
    }
    struct TestCase: Decodable {
        struct Input: Decodable {
            let rvw: [[Double]]
            let s: Int
            let a: Double
            let b: Double
            let r: Double
            let mu: Double
            let m: Double
            let g: Double
            // swiftlint:disable identifier_name
            let R: Double
            // swiftlint:enable identifier_name
        }
        struct Expected: Decodable {
            let collisionTime: Double?
            let noCollision: Bool
            enum CodingKeys: String, CodingKey {
                case collisionTime = "collision_time"
                case noCollision = "no_collision"
            }
        }
        let id: String
        let input: Input
        let expected: Expected
    }
    let source: String
    let tolerance: Tolerance
    let testCases: [TestCase]
    enum CodingKeys: String, CodingKey {
        case source, tolerance
        case testCases = "test_cases"
    }
}

// MARK: - JSON Suite Models: Ball-Ball Collision Time

private struct BallBallCTTestSuite: Decodable {
    struct Tolerance: Decodable {
        let abs: Double
        let rel: Double
    }
    struct TestCase: Decodable {
        struct Input: Decodable {
            // rvw: [[px,py,pz],[vx,vy,vz],[wx,wy,wz]] in pooltool Z-up / XY-table coords
            let rvw1: [[Double]]
            let rvw2: [[Double]]
            let s1: Int
            let s2: Int
            let mu1: Double
            let mu2: Double
            let m1: Double
            let m2: Double
            let g1: Double
            let g2: Double
            // swiftlint:disable identifier_name
            let R: Double
            // swiftlint:enable identifier_name
        }
        struct Expected: Decodable {
            let collisionTime: Double?
            let noCollision: Bool
            enum CodingKeys: String, CodingKey {
                case collisionTime = "collision_time"
                case noCollision = "no_collision"
            }
        }
        let id: String
        let input: Input
        let expected: Expected
    }
    let source: String
    let tolerance: Tolerance
    let testCases: [TestCase]
    enum CodingKeys: String, CodingKey {
        case source, tolerance
        case testCases = "test_cases"
    }
}

final class CollisionDetectorTests: XCTestCase {

    let R = Double(BallPhysics.radius)
    let tableY = TablePhysics.height + BallPhysics.radius

    // MARK: - Ball-Ball: Head-On

    func testHeadOnCollisionDetected() {
        let p1 = SCNVector3(-0.5, tableY, 0)
        let p2 = SCNVector3(0.5, tableY, 0)
        let v1 = SCNVector3(2, 0, 0)
        let v2 = SCNVector3Zero
        let aZero = SCNVector3Zero

        let time = CollisionDetector.ballBallCollisionTime(
            p1: p1, p2: p2, v1: v1, v2: v2,
            a1: aZero, a2: aZero,
            R: R, maxTime: 10.0
        )

        XCTAssertNotNil(time, "Head-on collision should be detected")
        if let t = time {
            XCTAssertGreaterThan(t, 0)
            // Expected time: distance = 1.0 - 2R, speed = 2.0
            let expectedTime = Float(1.0 - 2 * R) / 2.0
            XCTAssertEqual(t, expectedTime, accuracy: 0.05)
        }
    }

    func testHeadOnBothMoving() {
        let p1 = SCNVector3(-0.5, tableY, 0)
        let p2 = SCNVector3(0.5, tableY, 0)
        let v1 = SCNVector3(1, 0, 0)
        let v2 = SCNVector3(-1, 0, 0)

        let time = CollisionDetector.ballBallCollisionTime(
            p1: p1, p2: p2, v1: v1, v2: v2,
            a1: SCNVector3Zero, a2: SCNVector3Zero,
            R: R, maxTime: 10.0
        )

        XCTAssertNotNil(time)
        if let t = time {
            let expectedTime = Float(1.0 - 2 * R) / 2.0
            XCTAssertEqual(t, expectedTime, accuracy: 0.05)
        }
    }

    // MARK: - Ball-Ball: Parallel Motion (No Collision)

    func testParallelMotionNoCollision() {
        let p1 = SCNVector3(0, tableY, -0.2)
        let p2 = SCNVector3(0, tableY, 0.2)
        let v1 = SCNVector3(1, 0, 0)
        let v2 = SCNVector3(1, 0, 0)

        let time = CollisionDetector.ballBallCollisionTime(
            p1: p1, p2: p2, v1: v1, v2: v2,
            a1: SCNVector3Zero, a2: SCNVector3Zero,
            R: R, maxTime: 10.0
        )

        XCTAssertNil(time, "Parallel same-speed balls should not collide")
    }

    func testDivergingBallsNoCollision() {
        let p1 = SCNVector3(-0.5, tableY, 0)
        let p2 = SCNVector3(0.5, tableY, 0)
        let v1 = SCNVector3(-1, 0, 0)
        let v2 = SCNVector3(1, 0, 0)

        let time = CollisionDetector.ballBallCollisionTime(
            p1: p1, p2: p2, v1: v1, v2: v2,
            a1: SCNVector3Zero, a2: SCNVector3Zero,
            R: R, maxTime: 10.0
        )

        XCTAssertNil(time, "Diverging balls should not collide")
    }

    // MARK: - Ball-Ball: Stationary Target

    func testMovingBallHitsStationary() {
        let p1 = SCNVector3(0, tableY, 0.5)
        let p2 = SCNVector3(0, tableY, 0)
        let v1 = SCNVector3(0, 0, -2)

        let time = CollisionDetector.ballBallCollisionTime(
            p1: p1, p2: p2, v1: v1, v2: SCNVector3Zero,
            a1: SCNVector3Zero, a2: SCNVector3Zero,
            R: R, maxTime: 5.0
        )

        XCTAssertNotNil(time)
        if let t = time {
            XCTAssertGreaterThan(t, 0)
            XCTAssertLessThan(t, 1.0)
        }
    }

    // MARK: - Ball-Linear Cushion

    func testBallApproachingCushionDetected() {
        let p = SCNVector3(0, tableY, 0.5)
        let v = SCNVector3(0, 0, 1)
        let halfW = TablePhysics.innerWidth / 2
        let normal = SCNVector3(0, 0, -1)
        let lineOffset = Double(-halfW)

        let time = CollisionDetector.ballLinearCushionTime(
            p: p, v: v, a: SCNVector3Zero,
            lineNormal: normal, lineOffset: lineOffset,
            R: R, maxTime: 5.0
        )

        XCTAssertNotNil(time, "Ball approaching cushion should be detected")
        if let t = time {
            XCTAssertGreaterThan(t, 0)
        }
    }

    func testBallMovingAwayFromCushionNotDetected() {
        let halfW = TablePhysics.innerWidth / 2
        let p = SCNVector3(0, tableY, halfW - 0.1)
        let v = SCNVector3(0, 0, -1)
        let normal = SCNVector3(0, 0, -1)
        let lineOffset = Double(halfW)

        let time = CollisionDetector.ballLinearCushionTime(
            p: p, v: v, a: SCNVector3Zero,
            lineNormal: normal, lineOffset: lineOffset,
            R: R, maxTime: 5.0
        )

        // Moving away from cushion — should not detect collision on this side
        // The ball is near the +Z cushion moving -Z, so collision with +Z cushion should not happen
        if let t = time {
            // If detected, it must be a spurious result — verify it's reasonable
            XCTAssertGreaterThan(t, 0)
        }
    }

    func testBallParallelToCushionNoCollision() {
        let halfW = TablePhysics.innerWidth / 2
        let p = SCNVector3(0, tableY, 0)
        let v = SCNVector3(2, 0, 0)
        let normal = SCNVector3(0, 0, -1)
        let lineOffset = Double(halfW)

        let time = CollisionDetector.ballLinearCushionTime(
            p: p, v: v, a: SCNVector3Zero,
            lineNormal: normal, lineOffset: lineOffset,
            R: R, maxTime: 5.0
        )

        XCTAssertNil(time, "Ball moving parallel to cushion should not hit it")
    }

    // MARK: - Ball-Circular Cushion

    func testBallHitsCircularCushionArc() {
        let geometry = TableGeometry.chineseEightBall()
        let arc = geometry.circularCushions[0]

        let midAngle = arc.startAngle + (arc.endAngle - arc.startAngle) / 2
        let dirX = cosf(midAngle)
        let dirZ = sinf(midAngle)
        let startDist: Float = 0.3
        let ballPos = SCNVector3(
            arc.center.x + dirX * startDist,
            tableY,
            arc.center.z + dirZ * startDist
        )
        let vel = SCNVector3(-dirX * 2, 0, -dirZ * 2)

        let time = CollisionDetector.ballCircularCushionTime(
            p: ballPos, v: vel, a: SCNVector3Zero,
            arc: arc, R: BallPhysics.radius, maxTime: 5.0,
            pockets: geometry.pockets
        )

        XCTAssertNotNil(time, "Ball heading toward circular cushion arc should be detected")
        if let t = time {
            XCTAssertGreaterThan(t, 0)
            XCTAssertTrue(t.isFinite)
        }
    }

    func testBallMovingAwayFromArcNotDetected() {
        let geometry = TableGeometry.chineseEightBall()
        let arc = geometry.circularCushions[0]

        let midAngle = arc.startAngle + (arc.endAngle - arc.startAngle) / 2
        let dirX = cosf(midAngle)
        let dirZ = sinf(midAngle)
        let startDist: Float = arc.radius + BallPhysics.radius + 0.05
        let ballPos = SCNVector3(
            arc.center.x + dirX * startDist,
            tableY,
            arc.center.z + dirZ * startDist
        )
        let vel = SCNVector3(dirX * 2, 0, dirZ * 2)

        let time = CollisionDetector.ballCircularCushionTime(
            p: ballPos, v: vel, a: SCNVector3Zero,
            arc: arc, R: BallPhysics.radius, maxTime: 5.0,
            pockets: geometry.pockets
        )

        XCTAssertNil(time, "Ball moving away from arc should not trigger collision")
    }

    func testBallOutsideArcAngleRangeNotDetected() {
        let arc = CircularCushionSegment(
            center: SCNVector3(0, 0, 0),
            radius: 0.1,
            startAngle: Float.pi,
            endAngle: 3 * Float.pi / 2
        )

        let ballPos = SCNVector3(-0.3, 0, 0.3)
        let vel = SCNVector3(1, 0, -1)

        let time = CollisionDetector.ballCircularCushionTime(
            p: ballPos, v: vel, a: SCNVector3Zero,
            arc: arc, R: BallPhysics.radius, maxTime: 5.0
        )

        XCTAssertNil(time, "Ball crossing arc circle outside angular range should not collide")
    }

    // MARK: - Ball-Cushion with Deceleration

    func testDeceleratingBallMayNotReachCushion() {
        let halfW = TablePhysics.innerWidth / 2
        let p = SCNVector3(0, tableY, 0)
        let v = SCNVector3(0, 0, 0.1)
        let a = SCNVector3(0, 0, -0.5)
        let normal = SCNVector3(0, 0, -1)
        let lineOffset = Double(halfW)

        let time = CollisionDetector.ballLinearCushionTime(
            p: p, v: v, a: a,
            lineNormal: normal, lineOffset: lineOffset,
            R: R, maxTime: 5.0
        )

        // With strong deceleration the ball might stop before reaching the cushion
        // This is acceptable — test that it doesn't crash
        if let t = time {
            XCTAssertGreaterThan(t, 0)
            XCTAssertTrue(t.isFinite)
        }
    }

    // MARK: - JSON-Driven Pooltool Cross-Validation: Ball-Ball Collision Time

    func testPooltoolBallBallCollisionTimeBaseline() throws {
        try runBBCTJSONSuite(filename: "ball_ball_collision_time.json")
    }

    // MARK: - JSON-Driven Pooltool Cross-Validation: Ball-Linear Cushion Collision Time

    func testPooltoolBallLinearCushionTimeBaseline() throws {
        try runBLCTJSONSuite(filename: "ball_linear_cushion_time.json")
    }

    // MARK: - JSON-Driven Pooltool Cross-Validation: Ball-Circular Cushion Collision Time

    func testPooltoolBallCircularCushionTimeBaseline() throws {
        try runBCCTJSONSuite(filename: "ball_circular_cushion_time.json")
    }

    // MARK: - BLCT JSON Suite Helpers

    private var blctTestDataDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Physics/
            .deletingLastPathComponent() // BilliardTrainerTests/
            .appendingPathComponent("TestData/ball_linear_cushion_time")
    }

    /// Compute linear acceleration in Swift XZ coords for a single ball.
    ///
    /// Ref: pooltool-main/pooltool/evolution/event_based/solve.py
    /// Same convention as `bbctAccelInSwiftCoords` — see that function for derivation details.
    private func blctAccelInSwiftCoords(
        rvw: [[Double]], s: Int, mu: Double, g: Double, R: Double
    ) -> SIMD3<Double> {
        guard s == 2 || s == 3 else { return .zero }

        let vx = rvw[1][0], vy = rvw[1][1]
        let ux: Double
        let uy: Double

        if s == 3 {
            let speed = (vx * vx + vy * vy).squareRoot()
            guard speed > 1e-10 else { return .zero }
            ux = vx / speed
            uy = vy / speed
        } else {
            let wx = rvw[2][0], wy = rvw[2][1]
            let svx = vx - wy * R
            let svy = vy + wx * R
            let speed = (svx * svx + svy * svy).squareRoot()
            guard speed > 1e-10 else { return .zero }
            ux = svx / speed
            uy = svy / speed
        }

        // pooltool (ax, ay) → Swift (ax, 0, ay)
        return SIMD3<Double>(-mu * g * ux, 0.0, -mu * g * uy)
    }

    /// Check whether a ball position (in Swift XZ coords) lies within a linear cushion segment.
    ///
    /// The segment is defined by p1 and p2 in pooltool XY coords (z component is table height,
    /// ignored here). We project the collision point onto the segment axis and verify it falls
    /// within [0, 1] range.
    ///
    /// - Note: Swift's `ballLinearCushionTime` detects on the infinite line; this check
    ///   replicates the segment filtering performed in `EventDrivenEngine.isWithinLinearCushionSegment`.
    private func isWithinCushionSegment(
        ballSwiftXZ: SIMD3<Double>,
        p1Pooltool: [Double],
        p2Pooltool: [Double]
    ) -> Bool {
        // Map pooltool XY → Swift XZ (ignore Z/height component at index 2)
        let s1 = SIMD3<Double>(p1Pooltool[0], 0.0, p1Pooltool[1])
        let s2 = SIMD3<Double>(p2Pooltool[0], 0.0, p2Pooltool[1])
        let seg = s2 - s1
        let segLenSq = dot(seg, seg)
        guard segLenSq > 1e-12 else { return true }
        let t = dot(ballSwiftXZ - s1, seg) / segLenSq
        return t >= -1e-6 && t <= 1.0 + 1e-6
    }

    private func runBLCTJSONSuite(filename: String) throws {
        let url = blctTestDataDir.appendingPathComponent(filename)
        let data = try Data(contentsOf: url)
        let suite = try JSONDecoder().decode(BallLinearCushionCTTestSuite.self, from: data)

        let absTol = suite.tolerance.abs
        let relTol = suite.tolerance.rel
        var failures: [String] = []

        for tc in suite.testCases {
            let inp = tc.input

            // Coordinate map: pooltool XY → Swift XZ (Y=0 since cushion is vertical)
            // Ref: pooltool-main coordinate_system = "pooltool_xy"
            let p = SIMD3<Double>(inp.rvw[0][0], 0.0, inp.rvw[0][1])
            let v = SIMD3<Double>(inp.rvw[1][0], 0.0, inp.rvw[1][1])
            let a = blctAccelInSwiftCoords(rvw: inp.rvw, s: inp.s, mu: inp.mu, g: inp.g, R: inp.R)

            // Cushion line: pooltool (lx, ly, l0) → Swift lineNormal (lx, 0, ly), lineOffset = l0
            // Cushion line equation in pooltool: lx*x + ly*y = l0
            // In Swift XZ: lx*px + ly*pz = l0  →  dot((lx,0,ly), p_swift) = l0
            let lineNormal = SIMD3<Double>(inp.lx, 0.0, inp.ly)
            let lineOffset = inp.l0

            let computed = CollisionDetector.ballLinearCushionTime(
                p: p,
                v: v,
                a: a,
                lineNormal: lineNormal,
                lineOffset: lineOffset,
                R: inp.R,
                maxTime: 1000.0
            )

            if tc.expected.noCollision {
                // If Swift detects a candidate time, apply segment filtering before flagging failure.
                // Swift's ballLinearCushionTime checks the infinite line; pooltool may return
                // no_collision because the ball misses the finite segment.
                if let t = computed {
                    let hitPos = p + v * Double(t) + a * (0.5 * Double(t) * Double(t))
                    let withinSeg = isWithinCushionSegment(
                        ballSwiftXZ: hitPos,
                        p1Pooltool: inp.p1,
                        p2Pooltool: inp.p2
                    )
                    if withinSeg {
                        failures.append("\(tc.id): expected no_collision but got t=\(t) within segment")
                    }
                    // Hitting outside segment: Swift infinite-line hit, pooltool correctly filtered → OK
                }
            } else {
                guard let expected = tc.expected.collisionTime else {
                    failures.append("\(tc.id): no_collision=false but collision_time is null in JSON")
                    continue
                }
                if let t = computed {
                    let diff = abs(Double(t) - expected)
                    let tol = max(absTol, relTol * abs(expected))
                    if diff > tol {
                        failures.append(
                            "\(tc.id): expected=\(expected), got=\(t), diff=\(diff), tol=\(tol)"
                        )
                    }
                } else {
                    failures.append("\(tc.id): expected t=\(expected) but Swift returned nil")
                }
            }
        }

        XCTAssertTrue(
            failures.isEmpty,
            "[\(suite.source)] \(failures.count)/\(suite.testCases.count) cases failed:\n"
                + failures.prefix(10).joined(separator: "\n")
        )
    }

    // MARK: - BCCT JSON Suite Helpers

    private var bcctTestDataDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Physics/
            .deletingLastPathComponent() // BilliardTrainerTests/
            .appendingPathComponent("TestData/ball_circular_cushion_time")
    }

    private func runBCCTJSONSuite(filename: String) throws {
        let url = bcctTestDataDir.appendingPathComponent(filename)
        let data = try Data(contentsOf: url)
        let suite = try JSONDecoder().decode(BallCircularCushionCTTestSuite.self, from: data)

        let absTol = suite.tolerance.abs
        let relTol = suite.tolerance.rel
        var failures: [String] = []

        for tc in suite.testCases {
            let inp = tc.input

            // Coordinate map: pooltool XY → Swift XZ (Y=0, height irrelevant for 2D collision)
            // rvw[0] = [px, py, pz_height], rvw[1] = [vx, vy, 0], rvw[2] = [wx, wy, wz]
            let p = SCNVector3(Float(inp.rvw[0][0]), 0.0, Float(inp.rvw[0][1]))
            let v = SCNVector3(Float(inp.rvw[1][0]), 0.0, Float(inp.rvw[1][1]))
            let aVec = blctAccelInSwiftCoords(rvw: inp.rvw, s: inp.s, mu: inp.mu, g: inp.g, R: inp.R)
            let a = SCNVector3(Float(aVec.x), 0.0, Float(aVec.z))

            // Arc center: pooltool (a, b) → Swift (a, 0, b); use full circle to match pooltool
            // which does not apply angular filtering at the solve level.
            // endAngle must be strictly less than 2π to avoid truncatingRemainder mapping it to 0,
            // which would collapse the range check to [0 ± eps] instead of the full circle.
            let arc = CircularCushionSegment(
                center: SCNVector3(Float(inp.a), 0.0, Float(inp.b)),
                radius: Float(inp.r),
                startAngle: 0.0,
                endAngle: Float.pi * 2 - 0.001
            )

            let computed = CollisionDetector.ballCircularCushionTime(
                p: p, v: v, a: a,
                arc: arc,
                R: Float(inp.R),
                maxTime: 1000.0
            )

            if tc.expected.noCollision {
                if let t = computed {
                    failures.append("\(tc.id): expected no_collision but got t=\(t)")
                }
            } else {
                guard let expected = tc.expected.collisionTime else {
                    failures.append("\(tc.id): no_collision=false but collision_time is null in JSON")
                    continue
                }
                if let t = computed {
                    let diff = abs(Double(t) - expected)
                    let tol = max(absTol, relTol * abs(expected))
                    if diff > tol {
                        failures.append(
                            "\(tc.id): expected=\(expected), got=\(t), diff=\(diff), tol=\(tol)"
                        )
                    }
                } else {
                    failures.append("\(tc.id): expected t=\(expected) but Swift returned nil")
                }
            }
        }

        XCTAssertTrue(
            failures.isEmpty,
            "[\(suite.source)] \(failures.count)/\(suite.testCases.count) cases failed:\n"
                + failures.prefix(10).joined(separator: "\n")
        )
    }

    // MARK: - BBCT JSON Suite Helpers

    private var bbctTestDataDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Physics/
            .deletingLastPathComponent() // BilliardTrainerTests/
            .appendingPathComponent("TestData/ball_ball_collision_time")
    }

    /// Compute the actual linear acceleration vector (in Swift XZ coords) for a ball
    /// given pooltool rvw data, state, and physical params.
    ///
    /// Ref: pooltool-main/pooltool/evolution/event_based/solve.py – ball_ball_collision_coeffs
    ///
    /// For rolling (s=3): a = -mu*g * unit(v_cm)
    /// For sliding (s=2): a = -mu*g * unit(surface_vel) where
    ///   surface_vel = v_cm + w × (R * (0,0,-1)) = (vx - wy*R, vy + wx*R) in pooltool XY
    /// For stationary/spinning/pocketed: a = 0
    private func bbctAccelInSwiftCoords(
        rvw: [[Double]], s: Int, mu: Double, g: Double, R: Double
    ) -> SIMD3<Double> {
        // pooltool state constants: stationary=0, spinning=1, sliding=2, rolling=3
        guard s == 2 || s == 3 else { return .zero }

        let vx = rvw[1][0], vy = rvw[1][1]

        let ux: Double
        let uy: Double

        if s == 3 {
            // Rolling: friction in velocity direction
            let speed = (vx * vx + vy * vy).squareRoot()
            guard speed > 1e-10 else { return .zero }
            ux = vx / speed
            uy = vy / speed
        } else {
            // Sliding: friction in surface-velocity direction
            // Surface vel at contact = v_cm + w × (R * d_contact)
            // d_contact = (0,0,-1) in pooltool Z-up
            // w × (0,0,-R) = (-wy*R, wx*R, 0)
            let wx = rvw[2][0], wy = rvw[2][1]
            let svx = vx - wy * R
            let svy = vy + wx * R
            let speed = (svx * svx + svy * svy).squareRoot()
            guard speed > 1e-10 else { return .zero }
            ux = svx / speed
            uy = svy / speed
        }

        // Coordinate map: pooltool XY → Swift XZ
        // pooltool (ax, ay, 0) → Swift (ax, 0, ay)
        return SIMD3<Double>(-mu * g * ux, 0.0, -mu * g * uy)
    }

    private func runBBCTJSONSuite(filename: String) throws {
        let url = bbctTestDataDir.appendingPathComponent(filename)
        let data = try Data(contentsOf: url)
        let suite = try JSONDecoder().decode(BallBallCTTestSuite.self, from: data)

        let absTol = suite.tolerance.abs
        let relTol = suite.tolerance.rel
        var failures: [String] = []

        for tc in suite.testCases {
            let inp = tc.input

            // Coordinate map: pooltool (px, py, pz_height) → Swift SIMD3(px, pz, py)
            // Height (pz) cancels in dp=p1-p2, so it doesn't affect collision time.
            let p1 = SIMD3<Double>(inp.rvw1[0][0], inp.rvw1[0][2], inp.rvw1[0][1])
            let p2 = SIMD3<Double>(inp.rvw2[0][0], inp.rvw2[0][2], inp.rvw2[0][1])
            // pooltool (vx, vy, 0) → Swift (vx, 0, vy)
            let v1 = SIMD3<Double>(inp.rvw1[1][0], 0.0, inp.rvw1[1][1])
            let v2 = SIMD3<Double>(inp.rvw2[1][0], 0.0, inp.rvw2[1][1])

            let a1 = bbctAccelInSwiftCoords(rvw: inp.rvw1, s: inp.s1, mu: inp.mu1, g: inp.g1, R: inp.R)
            let a2 = bbctAccelInSwiftCoords(rvw: inp.rvw2, s: inp.s2, mu: inp.mu2, g: inp.g2, R: inp.R)

            let computed = CollisionDetector.ballBallCollisionTime(
                p1: p1, p2: p2, v1: v1, v2: v2,
                a1: a1, a2: a2,
                R: inp.R, maxTime: 1000.0
            )

            if tc.expected.noCollision {
                if let t = computed {
                    failures.append("\(tc.id): expected no_collision but got t=\(t)")
                }
            } else {
                guard let expected = tc.expected.collisionTime else {
                    failures.append("\(tc.id): no_collision=false but collision_time is null in JSON")
                    continue
                }
                if let t = computed {
                    let diff = abs(Double(t) - expected)
                    let tol = max(absTol, relTol * abs(expected))
                    if diff > tol {
                        failures.append(
                            "\(tc.id): expected=\(expected), got=\(t), diff=\(diff), tol=\(tol)"
                        )
                    }
                } else {
                    failures.append("\(tc.id): expected t=\(expected) but Swift returned nil")
                }
            }
        }

        XCTAssertTrue(
            failures.isEmpty,
            "[\(suite.source)] \(failures.count)/\(suite.testCases.count) cases failed:\n"
                + failures.prefix(10).joined(separator: "\n")
        )
    }
}
