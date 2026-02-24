import XCTest
import SceneKit
@testable import BilliardTrainer

private struct CrossEngineInput: Decodable {
    struct Metadata: Decodable {
        let id: String
        let description: String
    }

    struct Simulation: Decodable {
        let maxEvents: Int
        let maxTime: Float
    }

    struct Ball: Decodable {
        let id: String
        let position: [Float]
        let velocity: [Float]
        let angularVelocity: [Float]
        let state: String
    }

    let metadata: Metadata
    let simulation: Simulation
    let balls: [Ball]
}

private struct CrossEngineOutput: Decodable {
    struct Metadata: Decodable {
        let id: String
        let engine: String
    }

    struct BallState: Decodable {
        let position: [Float]
        let velocity: [Float]
        let angularVelocity: [Float]
        let motionState: String
    }

    struct EventSummary: Decodable {
        let type: String
        let time: Float?
        let ids: [String]
    }

    let metadata: Metadata
    let events: [EventSummary]
    let finalState: [String: BallState]
}

private struct CrossEngineComparisonReport {
    let positionMaxError: Float
    let velocityMaxError: Float
    let angularMaxError: Float
    let stateMatchRate: Float
    let eventTypeMatchRate: Float
    let passed: Bool
}

final class CrossEngineComparisonTests: XCTestCase {
    private var fixturesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Physics
            .deletingLastPathComponent() // BilliardTrainerTests
            .appendingPathComponent("Fixtures/CrossEngine")
    }

    func testCoreFixturesAgainstPooltoolBaselines() throws {
        let decoder = JSONDecoder()
        let inputURLs = try FileManager.default.contentsOfDirectory(
            at: fixturesDir,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasSuffix(".input.json") }.sorted { $0.lastPathComponent < $1.lastPathComponent }

        XCTAssertEqual(inputURLs.count, 5, "Core fixtures should contain exactly 5 golden input cases")

        for inputURL in inputURLs {
            let inputData = try Data(contentsOf: inputURL)
            let input = try decoder.decode(CrossEngineInput.self, from: inputData)
            let swiftOutput = runSwiftEngine(input: input)

            let baselineURL = fixturesDir.appendingPathComponent(
                inputURL.lastPathComponent.replacingOccurrences(of: ".input.json", with: ".pooltool-output.json")
            )
            guard FileManager.default.fileExists(atPath: baselineURL.path) else {
                throw XCTSkip("Missing pooltool baseline for \(input.metadata.id). Generate via scripts/physics/export_pooltool_baseline.py")
            }

            let baselineData = try Data(contentsOf: baselineURL)
            let pooltoolOutput = try decoder.decode(CrossEngineOutput.self, from: baselineData)
            if pooltoolOutput.metadata.engine != "pooltool" {
                throw XCTSkip("Baseline for \(input.metadata.id) is fallback (\(pooltoolOutput.metadata.engine)); run export with real pooltool environment")
            }
            let report = compare(swift: swiftOutput, pooltool: pooltoolOutput)

            XCTAssertTrue(report.passed, """
                Cross-engine mismatch for \(input.metadata.id)
                positionMaxError=\(report.positionMaxError)
                velocityMaxError=\(report.velocityMaxError)
                angularMaxError=\(report.angularMaxError)
                stateMatchRate=\(report.stateMatchRate)
                eventTypeMatchRate=\(report.eventTypeMatchRate)
                """)
        }
    }

    // MARK: - Swift Engine Runner

    private func runSwiftEngine(input: CrossEngineInput) -> CrossEngineOutput {
        let engine = EventDrivenEngine(tableGeometry: TableGeometry.chineseEightBall())

        for ball in input.balls {
            engine.setBall(BallState(
                position: vector3(from: ball.position),
                velocity: vector3(from: ball.velocity),
                angularVelocity: vector3(from: ball.angularVelocity),
                state: motionState(from: ball.state),
                name: ball.id
            ))
        }

        engine.simulate(maxEvents: input.simulation.maxEvents, maxTime: input.simulation.maxTime)

        let events = engine.resolvedEvents.map { event in
            switch event {
            case .ballBall(let a, let b):
                return CrossEngineOutput.EventSummary(type: "BALL_BALL", time: nil, ids: [a, b])
            case .ballCushion(let ball, _, _):
                return CrossEngineOutput.EventSummary(type: "BALL_CUSHION", time: nil, ids: [ball])
            case .transition(let ball, let from, let to):
                return CrossEngineOutput.EventSummary(type: "TRANSITION_\(from)_\(to)", time: nil, ids: [ball])
            case .pocket(let ball, let pocketId):
                return CrossEngineOutput.EventSummary(type: "BALL_POCKET", time: nil, ids: [ball, pocketId])
            }
        }

        var finalState: [String: CrossEngineOutput.BallState] = [:]
        for ball in engine.getAllBalls() {
            finalState[ball.name] = CrossEngineOutput.BallState(
                position: [ball.position.x, ball.position.y, ball.position.z],
                velocity: [ball.velocity.x, ball.velocity.y, ball.velocity.z],
                angularVelocity: [ball.angularVelocity.x, ball.angularVelocity.y, ball.angularVelocity.z],
                motionState: motionStateName(ball.state)
            )
        }

        return CrossEngineOutput(
            metadata: .init(id: input.metadata.id, engine: "swift"),
            events: events,
            finalState: finalState
        )
    }

    // MARK: - Comparator

    private func compare(swift: CrossEngineOutput, pooltool: CrossEngineOutput) -> CrossEngineComparisonReport {
        var comparedBalls = 0
        var stateMatches = 0
        var positionMax: Float = 0
        var velocityMax: Float = 0
        var angularMax: Float = 0

        let sharedBallIds = Set(swift.finalState.keys).intersection(Set(pooltool.finalState.keys))
        for ballId in sharedBallIds {
            guard let s = swift.finalState[ballId], let p = pooltool.finalState[ballId] else { continue }
            comparedBalls += 1

            let positionError = vectorDistance(vector3(from: s.position), vector3(from: p.position))
            let velocityError = vectorDistance(vector3(from: s.velocity), vector3(from: p.velocity))
            let angularError = vectorDistance(vector3(from: s.angularVelocity), vector3(from: p.angularVelocity))

            positionMax = max(positionMax, positionError)
            velocityMax = max(velocityMax, velocityError)
            angularMax = max(angularMax, angularError)

            if s.motionState == p.motionState {
                stateMatches += 1
            }
        }

        let statesRate = comparedBalls > 0 ? Float(stateMatches) / Float(comparedBalls) : 0
        let eventTypeRate = eventSequenceMatchRate(lhs: swift.events.map(\.type), rhs: pooltool.events.map(\.type))

        let passed =
            positionMax <= PhysicsTestTolerance.position &&
            velocityMax <= PhysicsTestTolerance.velocity &&
            angularMax <= PhysicsTestTolerance.angularVelocity &&
            statesRate >= 0.98 &&
            eventTypeRate >= 0.95

        return CrossEngineComparisonReport(
            positionMaxError: positionMax,
            velocityMaxError: velocityMax,
            angularMaxError: angularMax,
            stateMatchRate: statesRate,
            eventTypeMatchRate: eventTypeRate,
            passed: passed
        )
    }

    private func eventSequenceMatchRate(lhs: [String], rhs: [String]) -> Float {
        guard !lhs.isEmpty || !rhs.isEmpty else { return 1.0 }
        let common = min(lhs.count, rhs.count)
        guard common > 0 else { return 0 }
        var matches = 0
        for i in 0..<common where lhs[i] == rhs[i] {
            matches += 1
        }
        return Float(matches) / Float(max(lhs.count, rhs.count))
    }

    // MARK: - Helpers

    private func vector3(from array: [Float]) -> SCNVector3 {
        let x = array.count > 0 ? array[0] : 0
        let y = array.count > 1 ? array[1] : 0
        let z = array.count > 2 ? array[2] : 0
        return SCNVector3(x, y, z)
    }

    private func motionState(from raw: String) -> BallMotionState {
        switch raw {
        case "stationary":
            return .stationary
        case "spinning":
            return .spinning
        case "rolling":
            return .rolling
        case "pocketed":
            return .pocketed
        default:
            return .sliding
        }
    }

    private func motionStateName(_ state: BallMotionState) -> String {
        switch state {
        case .stationary:
            return "stationary"
        case .spinning:
            return "spinning"
        case .sliding:
            return "sliding"
        case .rolling:
            return "rolling"
        case .pocketed:
            return "pocketed"
        }
    }
}

