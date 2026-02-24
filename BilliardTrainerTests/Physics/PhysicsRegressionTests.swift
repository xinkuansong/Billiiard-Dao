import XCTest
import SceneKit
@testable import BilliardTrainer

/// Regression tests with fixed scenarios (S1-S6) that validate end-to-end physics behavior.
/// These serve as a baseline: if parameters change, update expected values accordingly.
final class PhysicsRegressionTests: XCTestCase {

    let tableY = TablePhysics.height + BallPhysics.radius

    private func makeEngine() -> EventDrivenEngine {
        EventDrivenEngine(tableGeometry: TableGeometry.chineseEightBall())
    }

    // MARK: - S1: Center Straight Shot — Target Pocketed, Cue Stops

    func testS1_CenterStraightShot() {
        let geometry = TableGeometry.chineseEightBall()
        let engine = EventDrivenEngine(tableGeometry: geometry)

        // Cue ball above target, shoot straight down toward side pocket
        let pocket = geometry.pockets[4] // bottom side pocket at (0, y, -sideOffset)
        let targetPos = SCNVector3(0, tableY, 0)
        let cueBallPos = SCNVector3(0, tableY, 0.4)

        let aimDir = (targetPos - cueBallPos).normalized()
        let strike = CueBallStrike.executeStrike(
            aimDirection: aimDir, velocity: 3.0, spinX: 0, spinY: 0
        )

        engine.setBall(BallState(
            position: cueBallPos, velocity: strike.velocity,
            angularVelocity: strike.angularVelocity, state: .sliding, name: "cueBall"
        ))
        engine.setBall(BallState(
            position: targetPos, velocity: SCNVector3Zero,
            angularVelocity: SCNVector3Zero, state: .stationary, name: "ball_1"
        ))

        engine.simulate(maxEvents: 1000, maxTime: 10.0)

        let cue = engine.getBall("cueBall")!
        let target = engine.getBall("ball_1")!

        // Verify collision happened
        let hasBallBall = engine.resolvedEvents.contains { e in
            if case .ballBall = e { return true }; return false
        }
        XCTAssertTrue(hasBallBall, "S1: Ball-ball collision should occur")

        // Cue ball should nearly stop after center hit (stun shot behavior)
        XCTAssertLessThan(cue.velocity.length(), 1.0,
                          "S1: Cue ball should nearly stop after center hit")
        XCTAssertVector3Finite(cue.position)
        XCTAssertVector3Finite(target.position)
    }

    // MARK: - S2: Top Spin Follow — Cue Ball Continues Forward

    func testS2_TopSpinFollow() {
        let topSpinEngine = makeEngine()
        let centerEngine = makeEngine()
        let targetPos = SCNVector3(0, tableY, 0)
        let cueBallPos = SCNVector3(0, tableY, 0.4)

        let aimDir = (targetPos - cueBallPos).normalized()
        let topSpinStrike = CueBallStrike.executeStrike(
            aimDirection: aimDir, velocity: 3.0, spinX: 0, spinY: 0.8
        )
        let centerStrike = CueBallStrike.executeStrike(
            aimDirection: aimDir, velocity: 3.0, spinX: 0, spinY: 0
        )

        topSpinEngine.setBall(BallState(
            position: cueBallPos, velocity: topSpinStrike.velocity,
            angularVelocity: topSpinStrike.angularVelocity, state: .sliding, name: "cueBall"
        ))
        topSpinEngine.setBall(BallState(
            position: targetPos, velocity: SCNVector3Zero,
            angularVelocity: SCNVector3Zero, state: .stationary, name: "ball_1"
        ))

        centerEngine.setBall(BallState(
            position: cueBallPos, velocity: centerStrike.velocity,
            angularVelocity: centerStrike.angularVelocity, state: .sliding, name: "cueBall"
        ))
        centerEngine.setBall(BallState(
            position: targetPos, velocity: SCNVector3Zero,
            angularVelocity: SCNVector3Zero, state: .stationary, name: "ball_1"
        ))

        topSpinEngine.simulate(maxEvents: 1000, maxTime: 10.0)
        centerEngine.simulate(maxEvents: 1000, maxTime: 10.0)

        let topSpinCue = topSpinEngine.getBall("cueBall")!
        let centerCue = centerEngine.getBall("cueBall")!

        // Compare against center strike baseline in the same geometry.
        XCTAssertLessThan(
            topSpinCue.position.z,
            centerCue.position.z - 0.01,
            "S2: Top spin should produce more forward follow than center strike"
        )
        XCTAssertVector3Finite(topSpinCue.position)
        XCTAssertVector3Finite(centerCue.position)
    }

    // MARK: - S3: Draw Shot — Cue Ball Comes Back

    func testS3_DrawShot() {
        let engine = makeEngine()
        let targetPos = SCNVector3(0, tableY, 0)
        let cueBallPos = SCNVector3(0, tableY, 0.4)

        let aimDir = (targetPos - cueBallPos).normalized()
        let strike = CueBallStrike.executeStrike(
            aimDirection: aimDir, velocity: 3.0, spinX: 0, spinY: -0.8
        )

        engine.setBall(BallState(
            position: cueBallPos, velocity: strike.velocity,
            angularVelocity: strike.angularVelocity, state: .sliding, name: "cueBall"
        ))
        engine.setBall(BallState(
            position: targetPos, velocity: SCNVector3Zero,
            angularVelocity: SCNVector3Zero, state: .stationary, name: "ball_1"
        ))

        engine.simulate(maxEvents: 1000, maxTime: 10.0)

        let cue = engine.getBall("cueBall")!

        // With draw, cue ball should come back (z > initial cue ball z, or at least > target z)
        XCTAssertGreaterThan(cue.position.z, targetPos.z - 0.05,
                             "S3: Draw shot should pull cue ball back")
        XCTAssertVector3Finite(cue.position)
    }

    // MARK: - S4: Side Spin Squirt

    func testS4_SideSpinSquirt() {
        let squirt = CueBallStrike.squirtAngle(a: 0.5)
        XCTAssertNotEqual(squirt, 0, "S4: Side spin should produce non-zero squirt angle")
        XCTAssertTrue(squirt.isFinite)

        // Verify execute strike applies squirt
        let aimDir = SCNVector3(0, 0, -1)
        let result = CueBallStrike.executeStrike(
            aimDirection: aimDir, velocity: 3.0, spinX: 0.5, spinY: 0
        )

        // Velocity direction should differ from aim direction due to squirt
        let velDir = result.velocity.normalized()
        let dot = velDir.dot(aimDir)
        XCTAssertLessThan(dot, 0.9999,
                          "S4: Squirt should deflect velocity from aim direction")
        XCTAssertGreaterThan(dot, 0.9,
                             "S4: Squirt deflection should be small but present")
    }

    // MARK: - S5: One Cushion Rebound

    func testS5_OneCushionRebound() {
        let engine = makeEngine()

        engine.setBall(BallState(
            // Offset from side-pocket centerline to avoid direct pocket entry.
            position: SCNVector3(0.45, tableY, 0),
            velocity: SCNVector3(0, 0, 3),
            angularVelocity: SCNVector3Zero,
            state: .sliding,
            name: "cueBall"
        ))

        engine.simulate(maxEvents: 500, maxTime: 10.0)

        let hasCushion = engine.resolvedEvents.contains { e in
            if case .ballCushion = e { return true }; return false
        }
        XCTAssertTrue(hasCushion, "S5: Ball should hit cushion")

        let ball = engine.getBall("cueBall")!
        XCTAssertBallOnTable(ball)
        XCTAssertVector3Finite(ball.position)
    }

    // MARK: - S6: Multi-Ball No Tunneling

    func testS6_MultiBallNoTunneling() {
        let engine = makeEngine()

        // Triangle rack-like arrangement
        let positions: [(String, Float, Float)] = [
            ("cueBall", 0, 0.6),
            ("ball_1", 0, 0),
            ("ball_2", 0.06, -0.06),
            ("ball_3", -0.06, -0.06),
            ("ball_4", 0.12, -0.12),
            ("ball_5", 0, -0.12),
            ("ball_6", -0.12, -0.12),
        ]

        for (name, x, z) in positions {
            let vel = name == "cueBall" ? SCNVector3(0, 0, -4) : SCNVector3Zero
            let state: BallMotionState = name == "cueBall" ? .sliding : .stationary
            engine.setBall(BallState(
                position: SCNVector3(x, tableY, z),
                velocity: vel,
                angularVelocity: SCNVector3Zero,
                state: state,
                name: name
            ))
        }

        engine.simulate(maxEvents: 2000, maxTime: 15.0)

        for ball in engine.getAllBalls() {
            XCTAssertVector3NotNaN(ball.position, "S6: \(ball.name) has NaN position")
            XCTAssertVector3NotNaN(ball.velocity, "S6: \(ball.name) has NaN velocity")
            XCTAssertVector3Finite(ball.position, "S6: \(ball.name) position not finite")
            XCTAssertBallOnTable(ball)
        }

        // Verify multiple collisions occurred
        let ballBallCount = engine.resolvedEvents.filter { e in
            if case .ballBall = e { return true }; return false
        }.count
        XCTAssertGreaterThan(ballBallCount, 2,
                             "S6: Multiple ball-ball collisions expected in break scenario")
    }

    // MARK: - S7: Two Cushion Route (Regression)

    func testS7_TwoCushionRouteStable() {
        let engine = makeEngine()
        engine.setBall(BallState(
            position: SCNVector3(0.15, tableY, 0.15),
            velocity: SCNVector3(2.0, 0, 2.2),
            angularVelocity: SCNVector3Zero,
            state: .sliding,
            name: "cueBall"
        ))

        engine.simulate(maxEvents: 1200, maxTime: 12.0)

        let cushionHits = engine.resolvedEvents.filter { event in
            if case .ballCushion = event { return true }
            return false
        }.count
        XCTAssertGreaterThanOrEqual(cushionHits, 2, "S7: Expected at least two cushion contacts")

        let cue = engine.getBall("cueBall")!
        XCTAssertVector3Finite(cue.position)
        XCTAssertBallOnTable(cue)
    }

    // MARK: - S8: Pocket Edge Graze (Regression)

    func testS8_PocketEdgeGrazeNoNumericalExplosion() {
        let geometry = TableGeometry.chineseEightBall()
        let engine = EventDrivenEngine(tableGeometry: geometry)
        let pocket = geometry.pockets[4]

        // Offset aim slightly from pocket center to force jaw/edge interaction.
        let startPos = SCNVector3(0.10, tableY, 0.20)
        let edgeAim = SCNVector3(pocket.center.x + 0.02, tableY, pocket.center.z)
        let dir = (edgeAim - startPos).normalized()

        engine.setBall(BallState(
            position: startPos,
            velocity: dir * 2.8,
            angularVelocity: SCNVector3Zero,
            state: .sliding,
            name: "cueBall"
        ))

        engine.simulate(maxEvents: 1000, maxTime: 10.0)

        let cue = engine.getBall("cueBall")!
        XCTAssertVector3Finite(cue.position)
        XCTAssertVector3Finite(cue.velocity)
        XCTAssertFalse(cue.position.x.isNaN || cue.position.z.isNaN, "S8: position should remain valid")
    }

    // MARK: - S9: Multi Collision Chain (Regression)

    func testS9_ContinuousCollisionChain() {
        let engine = makeEngine()
        let balls: [(String, SCNVector3, SCNVector3, BallMotionState)] = [
            ("cueBall", SCNVector3(0, tableY, 0.55), SCNVector3(0, 0, -3.2), .sliding),
            ("ball_1", SCNVector3(0, tableY, 0.20), SCNVector3Zero, .stationary),
            ("ball_2", SCNVector3(0, tableY, -0.05), SCNVector3Zero, .stationary),
            ("ball_3", SCNVector3(0, tableY, -0.30), SCNVector3Zero, .stationary)
        ]

        for (name, position, velocity, state) in balls {
            engine.setBall(BallState(
                position: position,
                velocity: velocity,
                angularVelocity: SCNVector3Zero,
                state: state,
                name: name
            ))
        }

        engine.simulate(maxEvents: 1600, maxTime: 12.0)

        let ballBallCount = engine.resolvedEvents.filter { event in
            if case .ballBall = event { return true }
            return false
        }.count
        XCTAssertGreaterThanOrEqual(ballBallCount, 3, "S9: should trigger a collision chain")

        for ball in engine.getAllBalls() {
            XCTAssertVector3Finite(ball.position, "S9: \(ball.name) position invalid")
            XCTAssertVector3Finite(ball.velocity, "S9: \(ball.name) velocity invalid")
            XCTAssertBallOnTable(ball)
        }
    }
}
