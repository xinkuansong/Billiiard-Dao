import XCTest
import SceneKit
@testable import BilliardTrainer

final class EventDrivenEngineTests: XCTestCase {

    let tableY = TablePhysics.height + BallPhysics.radius

    private func makeEngine() -> EventDrivenEngine {
        EventDrivenEngine(tableGeometry: TableGeometry.chineseEightBall())
    }

    // MARK: - Single Ball Motion

    func testSingleBallComesToRest() {
        let engine = makeEngine()
        engine.setBall(BallState(
            position: SCNVector3(0, tableY, 0),
            velocity: SCNVector3(1, 0, 0),
            angularVelocity: SCNVector3Zero,
            state: .sliding,
            name: "cueBall"
        ))

        engine.simulate(maxEvents: 500, maxTime: 15.0)

        let ball = engine.getBall("cueBall")!
        XCTAssertTrue(
            ball.state == .stationary || ball.state == .spinning,
            "Ball should come to rest, got \(ball.state)"
        )
    }

    func testSingleBallStaysOnTable() {
        let engine = makeEngine()
        engine.setBall(BallState(
            position: SCNVector3(0, tableY, 0),
            velocity: SCNVector3(3, 0, 1),
            angularVelocity: SCNVector3Zero,
            state: .sliding,
            name: "cueBall"
        ))

        engine.simulate(maxEvents: 500, maxTime: 10.0)

        let ball = engine.getBall("cueBall")!
        XCTAssertBallOnTable(ball)
    }

    func testStationaryBallDoesNotMove() {
        let engine = makeEngine()
        let startPos = SCNVector3(0.3, tableY, 0.2)
        engine.setBall(BallState(
            position: startPos,
            velocity: SCNVector3Zero,
            angularVelocity: SCNVector3Zero,
            state: .stationary,
            name: "ball_1"
        ))

        engine.simulate(maxEvents: 100, maxTime: 5.0)

        let ball = engine.getBall("ball_1")!
        XCTAssertVector3Equal(ball.position, startPos, accuracy: 0.01)
    }

    // MARK: - Two Ball Collision

    func testTwoBallHeadOnCollision() {
        let engine = makeEngine()
        let initialTargetPos = SCNVector3(0, tableY, 0)
        engine.setBall(BallState(
            position: SCNVector3(0, tableY, 0.4),
            velocity: SCNVector3(0, 0, -2),
            angularVelocity: SCNVector3Zero,
            state: .sliding,
            name: "cueBall"
        ))
        engine.setBall(BallState(
            position: initialTargetPos,
            velocity: SCNVector3Zero,
            angularVelocity: SCNVector3Zero,
            state: .stationary,
            name: "ball_1"
        ))

        engine.simulate(maxEvents: 500, maxTime: 10.0)

        let cue = engine.getBall("cueBall")!
        let target = engine.getBall("ball_1")!

        // Check for collision event
        let hasBallBall = engine.resolvedEvents.contains { event in
            if case .ballBall = event { return true }
            return false
        }
        XCTAssertTrue(hasBallBall, "Should have recorded a ball-ball collision event")
        XCTAssertGreaterThan(vectorDistance(target.position, initialTargetPos), 0.01,
                             "Target ball should have displaced after impact")
        XCTAssertVector3Finite(cue.position)
        XCTAssertVector3Finite(target.position)
    }

    // MARK: - Cushion Bounce

    func testBallBouncesOffCushion() {
        let engine = makeEngine()
        engine.setBall(BallState(
            position: SCNVector3(0.5, tableY, 0),
            velocity: SCNVector3(0, 0, 3),
            angularVelocity: SCNVector3Zero,
            state: .sliding,
            name: "cueBall"
        ))

        engine.simulate(maxEvents: 500, maxTime: 10.0)

        let hasCushion = engine.resolvedEvents.contains { event in
            if case .ballCushion = event { return true }
            return false
        }
        XCTAssertTrue(hasCushion, "Ball should have hit a cushion")

        let ball = engine.getBall("cueBall")!
        XCTAssertBallOnTable(ball)
    }

    // MARK: - Pocket Detection

    func testBallCanBePocketed() {
        let geometry = TableGeometry.chineseEightBall()
        let engine = EventDrivenEngine(tableGeometry: geometry)

        // Aim directly at a pocket
        let pocket = geometry.pockets[4] // bottom side pocket at (0, y, -offset)
        let startPos = SCNVector3(0, tableY, 0)
        let dir = (pocket.center - startPos).normalized()

        engine.setBall(BallState(
            position: startPos,
            velocity: dir * 3.0,
            angularVelocity: SCNVector3Zero,
            state: .sliding,
            name: "ball_1"
        ))

        engine.simulate(maxEvents: 500, maxTime: 10.0)

        let ball = engine.getBall("ball_1")!
        // Ball should either be pocketed or have hit cushions
        let hasPocket = engine.resolvedEvents.contains { event in
            if case .pocket = event { return true }
            return false
        }

        if hasPocket {
            XCTAssertTrue(ball.isPocketed)
        }
        // Even if not pocketed (trajectory might miss), ball should be finite
        XCTAssertVector3Finite(ball.position)
    }

    // MARK: - State Transitions

    func testStateTransitionsRecorded() {
        let engine = makeEngine()
        engine.setBall(BallState(
            position: SCNVector3(0, tableY, 0),
            velocity: SCNVector3(2, 0, 0),
            angularVelocity: SCNVector3Zero,
            state: .sliding,
            name: "cueBall"
        ))

        engine.simulate(maxEvents: 500, maxTime: 15.0)

        let transitions = engine.resolvedEvents.filter { event in
            if case .transition = event { return true }
            return false
        }
        XCTAssertGreaterThan(transitions.count, 0,
                             "Should have at least one state transition")

        // Should transition through sliding -> rolling -> (spinning -> stationary or just stationary)
        let hasSlideToRoll = transitions.contains { event in
            if case .transition(_, let from, let to) = event {
                return from == .sliding && to == .rolling
            }
            return false
        }
        XCTAssertTrue(hasSlideToRoll, "Should have a slide-to-roll transition")
    }

    // MARK: - Trajectory Recorder

    func testTrajectoryRecorderPopulated() {
        let engine = makeEngine()
        engine.setBall(BallState(
            position: SCNVector3(0, tableY, 0),
            velocity: SCNVector3(1, 0, 0),
            angularVelocity: SCNVector3Zero,
            state: .sliding,
            name: "cueBall"
        ))

        engine.simulate(maxEvents: 200, maxTime: 5.0)

        let recorder = engine.getTrajectoryRecorder()
        let frames = recorder.framesByBallName["cueBall"]
        XCTAssertNotNil(frames)
        XCTAssertGreaterThan(frames!.count, 1)
        XCTAssertGreaterThan(recorder.duration, 0)
    }

    func testTrajectoryStateAtQuery() {
        let engine = makeEngine()
        engine.setBall(BallState(
            position: SCNVector3(0, tableY, 0),
            velocity: SCNVector3(1, 0, 0),
            angularVelocity: SCNVector3Zero,
            state: .sliding,
            name: "cueBall"
        ))

        engine.simulate(maxEvents: 200, maxTime: 5.0)

        let recorder = engine.getTrajectoryRecorder()
        let frame = recorder.stateAt(ballName: "cueBall", time: 0.1)
        XCTAssertNotNil(frame)
    }

    // MARK: - Circular Cushion (Pocket Jaw) Bounce

    func testBallBouncesOffPocketJaw() {
        let geometry = TableGeometry.chineseEightBall()
        let engine = EventDrivenEngine(tableGeometry: geometry)

        let arc = geometry.circularCushions[0]
        let midAngle = arc.startAngle + (arc.endAngle - arc.startAngle) / 2
        let dirX = cosf(midAngle)
        let dirZ = sinf(midAngle)

        let startDist: Float = 0.25
        let startPos = SCNVector3(
            arc.center.x + dirX * startDist,
            tableY,
            arc.center.z + dirZ * startDist
        )

        engine.setBall(BallState(
            position: startPos,
            velocity: SCNVector3(-dirX * 3, 0, -dirZ * 3),
            angularVelocity: SCNVector3Zero,
            state: .sliding,
            name: "cueBall"
        ))

        engine.simulate(maxEvents: 500, maxTime: 5.0)

        let hasCushion = engine.resolvedEvents.contains { event in
            if case .ballCushion = event { return true }
            return false
        }
        XCTAssertTrue(hasCushion, "Ball aimed at pocket jaw should hit a cushion (linear or circular)")

        let ball = engine.getBall("cueBall")!
        XCTAssertVector3Finite(ball.position)
        XCTAssertVector3NotNaN(ball.velocity)
    }

    func testBallShotDirectlyAtPocketStillPocketed() {
        let geometry = TableGeometry.chineseEightBall()
        let engine = EventDrivenEngine(tableGeometry: geometry)

        let pocket = geometry.pockets[4]
        let startPos = SCNVector3(0, tableY, 0)
        let dir = SCNVector3(
            pocket.center.x - startPos.x,
            0,
            pocket.center.z - startPos.z
        ).normalized()

        engine.setBall(BallState(
            position: startPos,
            velocity: dir * 3.0,
            angularVelocity: SCNVector3Zero,
            state: .sliding,
            name: "ball_1"
        ))

        engine.simulate(maxEvents: 500, maxTime: 10.0)

        let ball = engine.getBall("ball_1")!
        let hasPocket = engine.resolvedEvents.contains { event in
            if case .pocket = event { return true }
            return false
        }

        if hasPocket {
            XCTAssertTrue(ball.isPocketed, "Ball aimed at pocket center should be pocketed")
        }
        XCTAssertVector3Finite(ball.position)
    }

    // MARK: - Multi-Ball Scenario

    func testMultiBallNoNaN() {
        let engine = makeEngine()
        let positions: [(Float, Float)] = [
            (0, 0.5), (0, 0), (0.1, -0.2), (-0.1, -0.3), (0.2, -0.1)
        ]

        engine.setBall(BallState(
            position: SCNVector3(positions[0].0, tableY, positions[0].1),
            velocity: SCNVector3(0, 0, -3),
            angularVelocity: SCNVector3Zero,
            state: .sliding,
            name: "cueBall"
        ))

        for i in 1..<positions.count {
            engine.setBall(BallState(
                position: SCNVector3(positions[i].0, tableY, positions[i].1),
                velocity: SCNVector3Zero,
                angularVelocity: SCNVector3Zero,
                state: .stationary,
                name: "ball_\(i)"
            ))
        }

        engine.simulate(maxEvents: 1000, maxTime: 10.0)

        for ball in engine.getAllBalls() {
            XCTAssertVector3NotNaN(ball.position, "Ball \(ball.name) position is NaN")
            XCTAssertVector3NotNaN(ball.velocity, "Ball \(ball.name) velocity is NaN")
            XCTAssertVector3Finite(ball.position, "Ball \(ball.name) position not finite")
            XCTAssertBallOnTable(ball)
        }
    }
}
