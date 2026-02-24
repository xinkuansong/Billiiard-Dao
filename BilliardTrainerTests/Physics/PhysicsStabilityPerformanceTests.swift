import XCTest
import SceneKit
@testable import BilliardTrainer

final class PhysicsStabilityPerformanceTests: XCTestCase {
    private let tableY = TablePhysics.height + BallPhysics.radius

    private struct SeededRNG {
        private var state: UInt64

        init(seed: UInt64) {
            self.state = seed == 0 ? 0xDEADBEEF : seed
        }

        mutating func nextUnit() -> Float {
            state = 6364136223846793005 &* state &+ 1
            let upper = UInt32((state >> 32) & 0xFFFF_FFFF)
            return Float(upper) / Float(UInt32.max)
        }

        mutating func next(in range: ClosedRange<Float>) -> Float {
            return range.lowerBound + (range.upperBound - range.lowerBound) * nextUnit()
        }
    }

    private func makeEngine() -> EventDrivenEngine {
        EventDrivenEngine(tableGeometry: TableGeometry.chineseEightBall())
    }

    func testRandomizedStabilityNoNaNNoExplosion() {
        var rng = SeededRNG(seed: 20260224)
        let runs = 20

        for _ in 0..<runs {
            let engine = makeEngine()
            let count = 6
            var placed: [SCNVector3] = []

            for i in 0..<count {
                var pos = SCNVector3Zero
                var accepted = false

                for _ in 0..<80 {
                    pos = SCNVector3(
                        rng.next(in: -0.75...0.75),
                        tableY,
                        rng.next(in: -0.28...0.28)
                    )
                    let ok = placed.allSatisfy { vectorDistance($0, pos) > 2.2 * BallPhysics.radius }
                    if ok {
                        accepted = true
                        break
                    }
                }
                XCTAssertTrue(accepted, "Failed to place non-overlapping ball")
                placed.append(pos)

                let moving = i == 0
                let velocity = moving
                    ? SCNVector3(rng.next(in: -2.5...2.5), 0, rng.next(in: -3.5 ... -1.2))
                    : SCNVector3Zero
                let angular = moving
                    ? SCNVector3(rng.next(in: -30...30), rng.next(in: -90...90), rng.next(in: -30...30))
                    : SCNVector3Zero

                engine.setBall(BallState(
                    position: pos,
                    velocity: velocity,
                    angularVelocity: angular,
                    state: moving ? .sliding : .stationary,
                    name: i == 0 ? "cueBall" : "ball_\(i)"
                ))
            }

            engine.simulate(maxEvents: 1500, maxTime: 8.0)

            for ball in engine.getAllBalls() {
                XCTAssertVector3Finite(ball.position, "Random stability: invalid position for \(ball.name)")
                XCTAssertVector3Finite(ball.velocity, "Random stability: invalid velocity for \(ball.name)")
                XCTAssertBallOnTable(ball)
                XCTAssertLessThan(ball.velocity.length(), 20.0, "Velocity explosion for \(ball.name)")
            }
        }
    }

    func testBreakScenarioPerformance() {
        measure {
            let engine = makeEngine()
            let positions: [(String, Float, Float)] = [
                ("cueBall", 0, 0.6),
                ("ball_1", 0, 0),
                ("ball_2", 0.06, -0.06),
                ("ball_3", -0.06, -0.06),
                ("ball_4", 0.12, -0.12),
                ("ball_5", 0, -0.12),
                ("ball_6", -0.12, -0.12)
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

            engine.simulate(maxEvents: 2000, maxTime: 10.0)
            XCTAssertGreaterThan(engine.resolvedEvents.count, 0)
        }
    }
}

