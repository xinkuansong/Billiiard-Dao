import XCTest
@testable import BilliardTrainer

// MARK: - JSON Suite Models: Cushion Resolve

private struct CushionResolveTestSuite: Decodable {
    struct Tolerance: Decodable {
        let abs: Double
        let rel: Double
    }
    struct Params: Decodable {
        // swiftlint:disable identifier_name
        let R: Double
        let M: Double
        let h: Double
        let ee: Double
        let mu_s: Double
        let mu_w: Double
        // swiftlint:enable identifier_name
    }
    struct ModelState: Decodable {
        let vx: Double
        let vy: Double
        let omega_x: Double
        let omega_y: Double
        let omega_z: Double
    }
    struct MathvanModel: Decodable {
        let params: Params
        let input: ModelState
        let expected: ModelState
    }
    struct TestCase: Decodable {
        let id: String
        let mathavan_model: MathvanModel
        enum CodingKeys: String, CodingKey {
            case id
            case mathavan_model = "mathavan_model"
        }
    }
    let source: String
    let tolerance: Tolerance
    let testCases: [TestCase]
    enum CodingKeys: String, CodingKey {
        case source, tolerance
        case testCases = "test_cases"
    }
}

final class CushionCollisionModelTests: XCTestCase {

    let R = BallPhysics.radius
    let M = BallPhysics.mass
    let mu_s = TablePhysics.clothFriction
    let mu_w = TablePhysics.cushionFriction
    let ee = TablePhysics.cushionRestitution
    let h = TablePhysics.cushionHeight

    private var cushionResolveTestDataDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("TestData/cushion_resolve")
    }

    // MARK: - JSON-Driven Pooltool Cross-Validation: Cushion Resolve

    /// 加载 pooltool 生成的库边碰撞响应测试数据，在 Mathavan 模型坐标系下直接比对
    /// 输入/输出均为模型坐标系（vx=切向，vy=法向，vy>0=趋近）。
    /// Ref: pooltool physics/resolve/ball_cushion/mathavan_2010/model.py::solve_mathavan
    func testPooltoolCushionResolveBaseline() throws {
        try runCushionResolveJSONSuite(filename: "cushion_resolve.json")
    }

    private func runCushionResolveJSONSuite(filename: String) throws {
        let url = cushionResolveTestDataDir.appendingPathComponent(filename)
        let data = try Data(contentsOf: url)
        let suite = try JSONDecoder().decode(CushionResolveTestSuite.self, from: data)

        let absTol = Float(suite.tolerance.abs)
        let relTol = Float(suite.tolerance.rel)
        var failures: [String] = []

        for tc in suite.testCases {
            let m = tc.mathavan_model
            let p = m.params
            let inp = m.input
            let exp = m.expected

            // 使用 JSON 中的 pooltool 物理常量，以隔离算法差异（而非参数差异）
            let result = CushionCollisionModel.solve(
                vx: Float(inp.vx),
                vy: Float(inp.vy),
                omega_x: Float(inp.omega_x),
                omega_y: Float(inp.omega_y),
                omega_z: Float(inp.omega_z),
                mu_s: Float(p.mu_s),
                mu_w: Float(p.mu_w),
                ee: Float(p.ee),
                h: Float(p.h),
                R: Float(p.R),
                M: Float(p.M)
            )

            func withinTol(_ actual: Float, _ expected: Float, label: String) -> String? {
                let diff = abs(Double(actual) - Double(expected))
                let tol = max(Double(absTol), Double(relTol) * abs(Double(expected)) + 1e-10)
                if diff > tol {
                    return "\(tc.id) \(label): actual=\(actual) expected=\(expected) diff=\(diff) tol=\(tol)"
                }
                return nil
            }

            if let msg = withinTol(result.vx,      Float(exp.vx),      label: "vx")      { failures.append(msg) }
            if let msg = withinTol(result.vy,      Float(exp.vy),      label: "vy")      { failures.append(msg) }
            if let msg = withinTol(result.omega_x, Float(exp.omega_x), label: "omega_x") { failures.append(msg) }
            if let msg = withinTol(result.omega_y, Float(exp.omega_y), label: "omega_y") { failures.append(msg) }
            if let msg = withinTol(result.omega_z, Float(exp.omega_z), label: "omega_z") { failures.append(msg) }
        }

        XCTAssertTrue(
            failures.isEmpty,
            "[\(suite.source)] \(failures.count) failures:\n"
                + failures.prefix(15).joined(separator: "\n")
        )
    }

    // MARK: - Basic Reflection

    func testPerpendicularApproachBounces() {
        let result = CushionCollisionModel.solve(
            vx: 0, vy: 2.0,
            omega_x: 0, omega_y: 0, omega_z: 0,
            mu_s: mu_s, mu_w: mu_w, ee: ee,
            h: h, R: R, M: M
        )

        XCTAssertLessThan(result.vy, 0,
                          "Ball should bounce back (negative vy)")
        XCTAssertTrue(result.vx.isFinite)
        XCTAssertTrue(result.vy.isFinite)
    }

    func testPerpendicularBounceEnergyLoss() {
        let vy_in: Float = 3.0
        let result = CushionCollisionModel.solve(
            vx: 0, vy: vy_in,
            omega_x: 0, omega_y: 0, omega_z: 0,
            mu_s: mu_s, mu_w: mu_w, ee: ee,
            h: h, R: R, M: M
        )

        XCTAssertLessThan(abs(result.vy), vy_in,
                          "Rebound speed should be less than approach speed")
    }

    // MARK: - Symmetric Behavior (No Spin)

    func testNoSpinSymmetricRebound() {
        let result1 = CushionCollisionModel.solve(
            vx: 1.0, vy: 2.0,
            omega_x: 0, omega_y: 0, omega_z: 0,
            mu_s: mu_s, mu_w: mu_w, ee: ee,
            h: h, R: R, M: M
        )

        let result2 = CushionCollisionModel.solve(
            vx: -1.0, vy: 2.0,
            omega_x: 0, omega_y: 0, omega_z: 0,
            mu_s: mu_s, mu_w: mu_w, ee: ee,
            h: h, R: R, M: M
        )

        // Tangential velocities should be symmetric (opposite sign)
        XCTAssertEqual(abs(result1.vx), abs(result2.vx), accuracy: 0.05,
                       "No-spin rebound should be symmetric")
        XCTAssertEqual(result1.vy, result2.vy, accuracy: 0.05)
    }

    // MARK: - Side Spin Effects

    func testSideSpinAffectsRebound() {
        let resultNoSpin = CushionCollisionModel.solve(
            vx: 1.0, vy: 2.0,
            omega_x: 0, omega_y: 0, omega_z: 0,
            mu_s: mu_s, mu_w: mu_w, ee: ee,
            h: h, R: R, M: M
        )

        let resultWithSpin = CushionCollisionModel.solve(
            vx: 1.0, vy: 2.0,
            omega_x: 0, omega_y: 0, omega_z: 20.0,
            mu_s: mu_s, mu_w: mu_w, ee: ee,
            h: h, R: R, M: M
        )

        // Side spin should modify the rebound angle
        let diff = abs(resultNoSpin.vx - resultWithSpin.vx)
        XCTAssertGreaterThan(diff, 0.01,
                             "Side spin should affect tangential rebound velocity")
    }

    // MARK: - Output Validity

    func testOutputsAreFinite() {
        let velocities: [(Float, Float)] = [
            (0, 1), (1, 1), (3, 5), (0.1, 0.1), (5, 0.5)
        ]
        let spins: [(Float, Float, Float)] = [
            (0, 0, 0), (10, 0, 0), (0, 10, 0), (0, 0, 10), (5, 5, 5)
        ]

        for (vx, vy) in velocities {
            for (ox, oy, oz) in spins {
                let result = CushionCollisionModel.solve(
                    vx: vx, vy: vy,
                    omega_x: ox, omega_y: oy, omega_z: oz,
                    mu_s: mu_s, mu_w: mu_w, ee: ee,
                    h: h, R: R, M: M
                )
                XCTAssertTrue(result.vx.isFinite, "vx not finite for input vx=\(vx) vy=\(vy)")
                XCTAssertTrue(result.vy.isFinite, "vy not finite for input vx=\(vx) vy=\(vy)")
                XCTAssertTrue(result.omega_x.isFinite)
                XCTAssertTrue(result.omega_y.isFinite)
                XCTAssertTrue(result.omega_z.isFinite)
            }
        }
    }

    func testOutputsNotNaN() {
        let result = CushionCollisionModel.solve(
            vx: 0, vy: 0.001,
            omega_x: 0, omega_y: 0, omega_z: 0,
            mu_s: mu_s, mu_w: mu_w, ee: ee,
            h: h, R: R, M: M
        )
        XCTAssertFalse(result.vx.isNaN)
        XCTAssertFalse(result.vy.isNaN)
    }

    // MARK: - Restitution Coefficient

    func testHigherRestitutionMoreBounce() {
        let resultLow = CushionCollisionModel.solve(
            vx: 0, vy: 2.0,
            omega_x: 0, omega_y: 0, omega_z: 0,
            mu_s: mu_s, mu_w: mu_w, ee: 0.5,
            h: h, R: R, M: M
        )

        let resultHigh = CushionCollisionModel.solve(
            vx: 0, vy: 2.0,
            omega_x: 0, omega_y: 0, omega_z: 0,
            mu_s: mu_s, mu_w: mu_w, ee: 0.95,
            h: h, R: R, M: M
        )

        XCTAssertGreaterThan(abs(resultHigh.vy), abs(resultLow.vy),
                             "Higher restitution should produce faster rebound")
    }
}
