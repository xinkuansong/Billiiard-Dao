import XCTest
@testable import BilliardTrainer

final class CushionCollisionModelTests: XCTestCase {

    let R = BallPhysics.radius
    let M = BallPhysics.mass
    let mu_s = TablePhysics.clothFriction
    let mu_w = TablePhysics.cushionFriction
    let ee = TablePhysics.cushionRestitution
    let h = TablePhysics.cushionHeight

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
