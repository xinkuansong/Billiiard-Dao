import XCTest
import SceneKit
@testable import BilliardTrainer

// MARK: - JSON Suite Models: Transition Time

private struct TransitionTimeTestSuite: Decodable {
    struct Tolerance: Decodable {
        let abs: Double
        let rel: Double
    }
    struct TestCase: Decodable {
        struct Input: Decodable {
            let state: Int
            let rvw: [[Double]]
            // swiftlint:disable identifier_name
            let R: Double
            // swiftlint:enable identifier_name
            let u_s: Double?
            let u_r: Double?
            let u_sp: Double?
            let g: Double
        }
        struct Expected: Decodable {
            let time: Double
        }
        let id: String
        let input: Input
        let expected: Expected
    }
    let module: String
    let source: String
    let tolerance: Tolerance
    let testCases: [TestCase]
    enum CodingKeys: String, CodingKey {
        case module, source, tolerance
        case testCases = "test_cases"
    }
}

// MARK: - JSON Suite Models: Evolve

private struct EvolveTestSuite: Decodable {
    struct Tolerance: Decodable {
        let abs: Double
        let rel: Double
    }
    struct TestCase: Decodable {
        struct Input: Decodable {
            let state: Int
            let rvw: [[Double]]
            // swiftlint:disable identifier_name
            let R: Double
            let m: Double
            // swiftlint:enable identifier_name
            let u_s: Double
            let u_sp: Double
            let u_r: Double
            let g: Double
            let t: Double
        }
        struct Expected: Decodable {
            let rvw: [[Double]]
            let state: Int
        }
        let id: String
        let input: Input
        let expected: Expected
    }
    let module: String
    let source: String
    let tolerance: Tolerance
    let testCases: [TestCase]
    enum CodingKeys: String, CodingKey {
        case module, source, tolerance
        case testCases = "test_cases"
    }
}

final class AnalyticalMotionTests: XCTestCase {

    let tableY = TablePhysics.height + BallPhysics.radius

    // MARK: - Surface Velocity

    func testSurfaceVelocityPureRolling() {
        let R = BallPhysics.radius
        let v = SCNVector3(1, 0, 0)
        // Rolling condition: v + omega x r = 0 at contact
        // r = (0, -R, 0), omega x r = (omega_z*R, 0, -omega_x*R)
        // For v = (1,0,0): need 1 + omega_z*R = 0, so omega_z = -1/R
        let omega = SCNVector3(0, 0, -1.0 / R)
        let surfVel = AnalyticalMotion.surfaceVelocity(linear: v, angular: omega, radius: R)
        // Should be near zero for pure rolling
        XCTAssertLessThan(surfVel.length(), 0.01, "Surface velocity should be ~0 for pure rolling")
    }

    func testSurfaceVelocitySliding() {
        let R = BallPhysics.radius
        let v = SCNVector3(2, 0, 0)
        let omega = SCNVector3Zero
        let surfVel = AnalyticalMotion.surfaceVelocity(linear: v, angular: omega, radius: R)
        XCTAssertGreaterThan(surfVel.length(), 1.0, "Sliding ball should have nonzero surface velocity")
    }

    // MARK: - Sliding Evolution

    func testEvolveSlidingDeceleratesVelocity() {
        let pos = SCNVector3(0, tableY, 0)
        let vel = SCNVector3(2, 0, 0)
        let omega = SCNVector3Zero
        let dt: Float = 0.1

        let result = AnalyticalMotion.evolveSliding(
            position: pos, velocity: vel, angularVelocity: omega, dt: dt
        )

        XCTAssertLessThan(result.velocity.length(), vel.length(),
                          "Sliding should decelerate")
        XCTAssertGreaterThan(result.position.x, pos.x,
                             "Ball should move forward")
    }

    func testEvolveSlidingZeroVelocityUnchanged() {
        let pos = SCNVector3(0, tableY, 0)
        let vel = SCNVector3Zero
        let omega = SCNVector3Zero

        let result = AnalyticalMotion.evolveSliding(
            position: pos, velocity: vel, angularVelocity: omega, dt: 0.1
        )

        XCTAssertVector3Equal(result.position, pos)
        XCTAssertVector3Equal(result.velocity, vel)
    }

    func testEvolveSlidingProducesFiniteResults() {
        let pos = SCNVector3(0, tableY, 0)
        let vel = SCNVector3(5, 0, -3)
        let omega = SCNVector3(10, 5, -10)

        let result = AnalyticalMotion.evolveSliding(
            position: pos, velocity: vel, angularVelocity: omega, dt: 0.05
        )

        XCTAssertVector3Finite(result.position)
        XCTAssertVector3Finite(result.velocity)
        XCTAssertVector3Finite(result.angularVelocity)
    }

    // MARK: - Rolling Evolution

    func testEvolveRollingDecelerates() {
        let pos = SCNVector3(0, tableY, 0)
        let vel = SCNVector3(1, 0, 0)
        let R = BallPhysics.radius
        let omega = SCNVector3(0, 0, -1.0 / R)

        let result = AnalyticalMotion.evolveRolling(
            position: pos, velocity: vel, angularVelocity: omega, dt: 0.5
        )

        XCTAssertLessThan(result.velocity.length(), vel.length())
        XCTAssertGreaterThan(result.position.x, pos.x)
    }

    func testEvolveRollingZeroVelocityUnchanged() {
        let pos = SCNVector3(0, tableY, 0)
        let result = AnalyticalMotion.evolveRolling(
            position: pos, velocity: SCNVector3Zero, angularVelocity: SCNVector3Zero, dt: 0.5
        )
        XCTAssertVector3Equal(result.position, pos)
    }

    // MARK: - Spinning Evolution

    func testEvolveSpinningDecaysYComponent() {
        let pos = SCNVector3(0, tableY, 0)
        let omega = SCNVector3(0, 50, 0)

        let result = AnalyticalMotion.evolveSpinning(
            position: pos, angularVelocity: omega, dt: 0.1
        )

        XCTAssertVector3Equal(result.position, pos, accuracy: 0.001,
                              "Position should not change during spinning")
        XCTAssertLessThan(abs(result.angularVelocity.y), abs(omega.y),
                          "Spin should decay")
    }

    func testEvolveSpinningNearZeroStops() {
        let pos = SCNVector3(0, tableY, 0)
        let omega = SCNVector3(0, 0.00005, 0)

        let result = AnalyticalMotion.evolveSpinning(
            position: pos, angularVelocity: omega, dt: 0.01
        )

        XCTAssertEqual(result.angularVelocity.y, 0, accuracy: 0.001)
    }

    // MARK: - Transition Times

    func testSlideToRollTimePositive() {
        let vel = SCNVector3(2, 0, 0)
        let omega = SCNVector3Zero
        let t = AnalyticalMotion.slideToRollTime(velocity: vel, angularVelocity: omega)
        XCTAssertGreaterThan(t, 0)
        XCTAssertLessThan(t, 10, "Transition should happen in reasonable time")
    }

    func testSlideToRollTimeAlreadyRolling() {
        let vel = SCNVector3(1, 0, 0)
        let R = BallPhysics.radius
        let omega = SCNVector3(0, 0, -1.0 / R)
        let t = AnalyticalMotion.slideToRollTime(velocity: vel, angularVelocity: omega)
        XCTAssertEqual(t, 0, accuracy: 0.01)
    }

    func testRollToSpinTimePositive() {
        let vel = SCNVector3(1, 0, 0)
        let t = AnalyticalMotion.rollToSpinTime(velocity: vel)
        XCTAssertGreaterThan(t, 0)
        XCTAssertLessThan(t, 60, "Ball should stop rolling within a minute")
    }

    func testRollToSpinTimeZeroVelocity() {
        let t = AnalyticalMotion.rollToSpinTime(velocity: SCNVector3Zero)
        XCTAssertEqual(t, 0, accuracy: 0.001)
    }

    func testSpinToStationaryTimePositive() {
        let omega = SCNVector3(0, 30, 0)
        let t = AnalyticalMotion.spinToStationaryTime(angularVelocity: omega)
        XCTAssertGreaterThan(t, 0)
    }

    func testSpinToStationaryTimeZeroSpin() {
        let t = AnalyticalMotion.spinToStationaryTime(angularVelocity: SCNVector3Zero)
        XCTAssertEqual(t, 0, accuracy: 0.001)
    }

    // MARK: - Spin Decay

    func testDecaySpinReducesY() {
        let omega = SCNVector3(0, 20, 0)
        let result = AnalyticalMotion.decaySpin(angularVelocity: omega, dt: 0.1)
        XCTAssertLessThan(abs(result.y), abs(omega.y))
    }

    func testDecaySpinPreservesXZ() {
        let omega = SCNVector3(5, 20, -3)
        let result = AnalyticalMotion.decaySpin(angularVelocity: omega, dt: 0.1)
        XCTAssertEqual(result.x, omega.x, accuracy: 0.001)
        XCTAssertEqual(result.z, omega.z, accuracy: 0.001)
    }

    // MARK: - JSON-Driven Pooltool Cross-Validation: Transition Time

    func testPooltoolTransitionTimeBaseline() throws {
        try runTransitionTimeJSONSuite(filename: "transition_time.json")
    }

    // MARK: - Transition Time JSON Suite Helpers

    private var transitionTimeTestDataDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Physics/
            .deletingLastPathComponent() // BilliardTrainerTests/
            .appendingPathComponent("TestData/transition_time")
    }

    private func runTransitionTimeJSONSuite(filename: String) throws {
        let url = transitionTimeTestDataDir.appendingPathComponent(filename)
        let data = try Data(contentsOf: url)
        let suite = try JSONDecoder().decode(TransitionTimeTestSuite.self, from: data)

        let absTol = Float(suite.tolerance.abs)
        let relTol = Float(suite.tolerance.rel)
        var failures: [String] = []

        for tc in suite.testCases {
            let inp = tc.input

            let vel   = evolveVelToSwift(inp.rvw[1])
            let omega = evolveAngVelToSwift(inp.rvw[2])
            // swiftlint:disable identifier_name
            let R     = Float(inp.R)
            // swiftlint:enable identifier_name
            let g     = Float(inp.g)
            let expTime = Float(tc.expected.time)

            let gotTime: Float

            switch inp.state {
            case 2: // sliding → rolling
                let uS = Float(inp.u_s ?? Double(SpinPhysics.slidingFriction))
                gotTime = AnalyticalMotion.slideToRollTime(
                    velocity: vel, angularVelocity: omega,
                    radius: R, slidingFriction: uS, gravity: g
                )
            case 3: // rolling → spinning
                let uR = Float(inp.u_r ?? Double(SpinPhysics.rollingFriction))
                gotTime = AnalyticalMotion.rollToSpinTime(
                    velocity: vel, rollingFriction: uR, gravity: g
                )
            case 1: // spinning → stationary
                let uSp = Float(inp.u_sp ?? Double(SpinPhysics.spinFriction))
                gotTime = AnalyticalMotion.spinToStationaryTime(
                    angularVelocity: omega, radius: R, spinFriction: uSp, gravity: g
                )
            default:
                failures.append("\(tc.id): unsupported pooltool state \(inp.state)")
                continue
            }

            let diff = abs(gotTime - expTime)
            let tol = max(absTol, relTol * abs(expTime))
            if diff > tol {
                failures.append(
                    "\(tc.id): expected=\(expTime), got=\(gotTime), diff=\(diff), tol=\(tol)"
                )
            }
        }

        XCTAssertTrue(
            failures.isEmpty,
            "[\(suite.source)] \(failures.count) case(s) failed:\n"
                + failures.joined(separator: "\n")
        )
    }

    // MARK: - JSON-Driven Pooltool Cross-Validation: Evolve

    func testPooltoolEvolveBaseline() throws {
        try runEvolveJSONSuite(filename: "evolve.json")
    }

    // MARK: - Evolve JSON Suite Helpers

    private var evolveTestDataDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Physics/
            .deletingLastPathComponent() // BilliardTrainerTests/
            .appendingPathComponent("TestData/evolve")
    }

    /// Convert pooltool position [px, py, pz_height] → Swift SCNVector3(px, pz_height, py)
    private func evolvePosToSwift(_ r: [Double]) -> SCNVector3 {
        SCNVector3(Float(r[0]), Float(r[2]), Float(r[1]))
    }

    /// Convert pooltool velocity [vx, vy, 0] → Swift SCNVector3(vx, 0, vy)
    private func evolveVelToSwift(_ v: [Double]) -> SCNVector3 {
        SCNVector3(Float(v[0]), 0.0, Float(v[1]))
    }

    /// Convert pooltool angular velocity [wx, wy, wz] → Swift SCNVector3(wx, wz, -wy)
    ///
    /// Axis mapping: pooltool X→Swift X (same), pooltool Z (vertical spin) → Swift Y (same direction).
    /// Sign flip on wy: in pooltool (Z-up), rolling in +x requires ωy = +v/R; in Swift (Y-up),
    /// rolling in +x requires ωz = -v/R. This chirality difference requires negating wy when
    /// mapping to Swift's Z axis.
    private func evolveAngVelToSwift(_ w: [Double]) -> SCNVector3 {
        SCNVector3(Float(w[0]), Float(w[2]), -Float(w[1]))
    }

    private func runEvolveJSONSuite(filename: String) throws {
        let url = evolveTestDataDir.appendingPathComponent(filename)
        let data = try Data(contentsOf: url)
        let suite = try JSONDecoder().decode(EvolveTestSuite.self, from: data)

        let absTol = Float(suite.tolerance.abs)
        let relTol = Float(suite.tolerance.rel)
        var failures: [String] = []

        for tc in suite.testCases {
            let inp = tc.input

            let pos    = evolvePosToSwift(inp.rvw[0])
            let vel    = evolveVelToSwift(inp.rvw[1])
            let omega  = evolveAngVelToSwift(inp.rvw[2])
            let dt     = Float(inp.t)
            // swiftlint:disable identifier_name
            let R      = Float(inp.R)
            // swiftlint:enable identifier_name
            let uS     = Float(inp.u_s)
            let uSp    = Float(inp.u_sp)
            let uR     = Float(inp.u_r)
            let g      = Float(inp.g)

            let expPos   = evolvePosToSwift(tc.expected.rvw[0])
            let expVel   = evolveVelToSwift(tc.expected.rvw[1])
            let expOmega = evolveAngVelToSwift(tc.expected.rvw[2])

            let gotPos: SCNVector3
            let gotVel: SCNVector3
            let gotOmega: SCNVector3

            switch inp.state {
            case 2: // sliding
                let result = AnalyticalMotion.evolveSliding(
                    position: pos, velocity: vel, angularVelocity: omega,
                    dt: dt, radius: R, slidingFriction: uS, spinFriction: uSp, gravity: g
                )
                gotPos   = result.position
                gotVel   = result.velocity
                gotOmega = result.angularVelocity

            case 3: // rolling
                let result = AnalyticalMotion.evolveRolling(
                    position: pos, velocity: vel, angularVelocity: omega,
                    dt: dt, radius: R, rollingFriction: uR, spinFriction: uSp, gravity: g
                )
                gotPos   = result.position
                gotVel   = result.velocity
                gotOmega = result.angularVelocity

            case 1: // spinning (linear velocity and position unchanged)
                let result = AnalyticalMotion.evolveSpinning(
                    position: pos, angularVelocity: omega,
                    dt: dt, radius: R, spinFriction: uSp, gravity: g
                )
                gotPos   = result.position
                gotVel   = vel
                gotOmega = result.angularVelocity

            default:
                failures.append("\(tc.id): unsupported pooltool state \(inp.state)")
                continue
            }

            let checks: [(got: SCNVector3, exp: SCNVector3, label: String)] = [
                (gotPos,   expPos,   "position"),
                (gotVel,   expVel,   "velocity"),
                (gotOmega, expOmega, "angularVelocity"),
            ]

            for check in checks {
                let components: [(String, Float, Float)] = [
                    ("x", check.got.x, check.exp.x),
                    ("y", check.got.y, check.exp.y),
                    ("z", check.got.z, check.exp.z),
                ]
                for (axis, got, exp) in components {
                    let diff = abs(got - exp)
                    let tol = max(absTol, relTol * abs(exp))
                    if diff > tol {
                        failures.append(
                            "\(tc.id) \(check.label).\(axis): expected=\(exp), got=\(got), " +
                            "diff=\(diff), tol=\(tol)"
                        )
                    }
                }
            }
        }

        XCTAssertTrue(
            failures.isEmpty,
            "[\(suite.source)] \(failures.count) component(s) failed:\n"
                + failures.prefix(20).joined(separator: "\n")
        )
    }
}
