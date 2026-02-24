import XCTest
import SceneKit
@testable import BilliardTrainer

final class TrajectoryPlaybackTests: XCTestCase {
    private let tableY = TablePhysics.height + BallPhysics.radius

    private func makeRecorderForBoundaryChecks() -> TrajectoryRecorder {
        let recorder = TrajectoryRecorder()
        recorder.recordFrame(ballName: "cueBall", frame: BallFrame(
            time: 0.0,
            position: SCNVector3(0, tableY, 0),
            velocity: SCNVector3(1.0, 0, 0),
            angularVelocity: SCNVector4(0, 0, 0, 0),
            state: .sliding
        ))
        recorder.recordFrame(ballName: "cueBall", frame: BallFrame(
            time: 0.5,
            position: SCNVector3(0.45, tableY, 0),
            velocity: SCNVector3(0.8, 0, 0),
            angularVelocity: SCNVector4(0, 2, 0, 0),
            state: .rolling
        ))
        recorder.recordFrame(ballName: "cueBall", frame: BallFrame(
            time: 1.0,
            position: SCNVector3(0.75, tableY, 0),
            velocity: SCNVector3Zero,
            angularVelocity: SCNVector4(0, 0, 0, 0),
            state: .stationary
        ))
        return recorder
    }

    func testStateAtHandlesBoundaryTimes() {
        let playback = TrajectoryPlayback(recorder: makeRecorderForBoundaryChecks(), surfaceY: tableY)

        let beforeStart = playback.stateAt(ballName: "cueBall", time: -0.5)
        XCTAssertNotNil(beforeStart)
        XCTAssertVector3DistanceLessThanOrEqual(
            beforeStart!.position,
            SCNVector3(0, tableY, 0),
            tolerance: PhysicsTestTolerance.position
        )

        let midState = playback.stateAt(ballName: "cueBall", time: 0.25)
        XCTAssertNotNil(midState)
        XCTAssertTrue(midState!.position.x > 0)
        XCTAssertEqual(midState!.position.y, tableY, accuracy: PhysicsTestTolerance.position)
        XCTAssertVector3Finite(midState!.position)

        let beyondEnd = playback.stateAt(ballName: "cueBall", time: 10.0)
        XCTAssertNotNil(beyondEnd)
        XCTAssertEqual(beyondEnd!.motionState, .stationary)
        XCTAssertVector3DistanceLessThanOrEqual(
            beyondEnd!.position,
            SCNVector3(0.75, tableY, 0),
            tolerance: PhysicsTestTolerance.position
        )
    }

    func testStateAtMatchesSnapshotsAtEventTimes() {
        let recorder = makeRecorderForBoundaryChecks()
        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: tableY)
        let frames = recorder.framesByBallName["cueBall"]!

        for frame in frames {
            let state = playback.stateAt(ballName: "cueBall", time: frame.time)
            XCTAssertNotNil(state)
            XCTAssertEqual(state!.motionState, frame.state)
            XCTAssertVector3DistanceLessThanOrEqual(
                state!.position,
                SCNVector3(frame.position.x, tableY, frame.position.z),
                tolerance: PhysicsTestTolerance.position
            )
        }
    }

    func testPocketFadeLifecycle() {
        let recorder = TrajectoryRecorder()
        recorder.recordFrame(ballName: "ball_1", frame: BallFrame(
            time: 0,
            position: SCNVector3(0, tableY, 0),
            velocity: SCNVector3(0, 0, -1),
            angularVelocity: SCNVector4(0, 0, 0, 0),
            state: .rolling
        ))
        recorder.recordFrame(ballName: "ball_1", frame: BallFrame(
            time: 0.4,
            position: SCNVector3(0, tableY, -0.2),
            velocity: SCNVector3Zero,
            angularVelocity: SCNVector4(0, 0, 0, 0),
            state: .pocketed
        ))

        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: tableY)
        XCTAssertTrue(playback.willBePocketed("ball_1"))

        playback.markPocketed("ball_1", at: 0.4)
        XCTAssertEqual(playback.opacity(for: "ball_1", at: 0.4), 1.0, accuracy: 1e-6)

        let half = playback.opacity(for: "ball_1", at: 0.525)
        XCTAssertEqual(half, 0.5, accuracy: 0.05)

        let done = playback.opacity(for: "ball_1", at: 1.0)
        XCTAssertEqual(done, 0.0, accuracy: 1e-6)
    }

    func testPlaybackOnRecordedEngineTrajectory() {
        let engine = EventDrivenEngine(tableGeometry: TableGeometry.chineseEightBall())
        engine.setBall(BallState(
            position: SCNVector3(0, tableY, 0.4),
            velocity: SCNVector3(0, 0, -2.2),
            angularVelocity: SCNVector3Zero,
            state: .sliding,
            name: "cueBall"
        ))
        engine.simulate(maxEvents: 500, maxTime: 4.0)

        let recorder = engine.getTrajectoryRecorder()
        let frames = recorder.framesByBallName["cueBall"] ?? []
        XCTAssertGreaterThan(frames.count, 1)

        let playback = TrajectoryPlayback(recorder: recorder, surfaceY: tableY)
        for frame in frames.prefix(16) {
            let state = playback.stateAt(ballName: "cueBall", time: frame.time)
            XCTAssertNotNil(state)
            XCTAssertVector3Finite(state!.position)
            XCTAssertVector3Finite(state!.velocity)
            XCTAssertEqual(state!.position.y, tableY, accuracy: PhysicsTestTolerance.position)
        }
    }
}

