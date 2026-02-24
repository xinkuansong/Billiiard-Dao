import XCTest
import SceneKit
@testable import BilliardTrainer

// MARK: - Shared Tolerance Profile

struct PhysicsTestTolerance {
    static let position: Float = 1e-3
    static let velocity: Float = 5e-3
    static let angularVelocity: Float = 5e-2
    static let eventTimeCritical: Float = 1e-4
    static let eventTimeGeneral: Float = 5e-4
    static let scalarLoose: Float = 1e-2
}

// MARK: - SCNVector3 Assertions

func XCTAssertVector3Equal(
    _ a: SCNVector3,
    _ b: SCNVector3,
    accuracy: Float = 0.01,
    _ message: String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let dx = abs(a.x - b.x)
    let dy = abs(a.y - b.y)
    let dz = abs(a.z - b.z)
    let maxDiff = max(dx, max(dy, dz))
    if maxDiff > accuracy {
        XCTFail(
            "XCTAssertVector3Equal failed: (\(a.x), \(a.y), \(a.z)) vs (\(b.x), \(b.y), \(b.z)), " +
            "maxDiff=\(maxDiff) > accuracy=\(accuracy). \(message)",
            file: file,
            line: line
        )
    }
}

func XCTAssertVector3NotNaN(
    _ v: SCNVector3,
    _ message: String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertFalse(v.x.isNaN || v.y.isNaN || v.z.isNaN,
                   "Vector contains NaN: (\(v.x), \(v.y), \(v.z)). \(message)",
                   file: file, line: line)
}

func XCTAssertVector3Finite(
    _ v: SCNVector3,
    _ message: String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertTrue(v.x.isFinite && v.y.isFinite && v.z.isFinite,
                  "Vector is not finite: (\(v.x), \(v.y), \(v.z)). \(message)",
                  file: file, line: line)
}

func vectorDistance(_ a: SCNVector3, _ b: SCNVector3) -> Float {
    return (a - b).length()
}

func XCTAssertVector3DistanceLessThanOrEqual(
    _ a: SCNVector3,
    _ b: SCNVector3,
    tolerance: Float,
    _ message: String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let distance = vectorDistance(a, b)
    XCTAssertLessThanOrEqual(
        distance,
        tolerance,
        "Vector distance \(distance) exceeds tolerance \(tolerance). \(message)",
        file: file,
        line: line
    )
}

func kineticEnergy(velocity: SCNVector3, mass: Float = BallPhysics.mass) -> Float {
    return 0.5 * mass * velocity.dot(velocity)
}

func XCTAssertEnergyNotIncreased(
    initialVelocity: SCNVector3,
    finalVelocity: SCNVector3,
    mass: Float = BallPhysics.mass,
    tolerance: Float = 1e-4,
    _ message: String = "",
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let e0 = kineticEnergy(velocity: initialVelocity, mass: mass)
    let e1 = kineticEnergy(velocity: finalVelocity, mass: mass)
    XCTAssertLessThanOrEqual(
        e1,
        e0 + tolerance,
        "Energy increased unexpectedly: e0=\(e0), e1=\(e1). \(message)",
        file: file,
        line: line
    )
}

// MARK: - Standard Scene Factories

/// Create a straight shot scenario: cue ball hits target ball directly toward a pocket
func standardStraightShot(
    cueBallX: Float = 0,
    cueBallZ: Float = 0.4,
    targetX: Float = 0,
    targetZ: Float = 0,
    velocity: Float = 3.0,
    spinX: Float = 0,
    spinY: Float = 0
) -> EventDrivenEngine {
    let geometry = TableGeometry.chineseEightBall()
    let engine = EventDrivenEngine(tableGeometry: geometry)
    let tableY = TablePhysics.height + BallPhysics.radius

    let aimDir = SCNVector3(targetX - cueBallX, 0, targetZ - cueBallZ).normalized()
    let strike = CueBallStrike.executeStrike(
        aimDirection: aimDir,
        velocity: velocity,
        spinX: spinX,
        spinY: spinY
    )

    engine.setBall(BallState(
        position: SCNVector3(cueBallX, tableY, cueBallZ),
        velocity: strike.velocity,
        angularVelocity: strike.angularVelocity,
        state: .sliding,
        name: "cueBall"
    ))

    engine.setBall(BallState(
        position: SCNVector3(targetX, tableY, targetZ),
        velocity: SCNVector3Zero,
        angularVelocity: SCNVector3Zero,
        state: .stationary,
        name: "ball_1"
    ))

    return engine
}

/// Create an angle shot scenario
func standardAngleShot(
    degrees: Float,
    velocity: Float = 3.0
) -> EventDrivenEngine {
    let radians = degrees * .pi / 180
    let targetZ = 0.5 * sin(radians)
    return standardStraightShot(
        cueBallX: -0.5,
        cueBallZ: 0,
        targetX: 0,
        targetZ: targetZ,
        velocity: velocity
    )
}

/// Assert that a ball's final position is within the table boundaries
func XCTAssertBallOnTable(
    _ ball: BallState,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    guard !ball.isPocketed else { return }
    let halfL = TablePhysics.innerLength / 2 + BallPhysics.radius
    let halfW = TablePhysics.innerWidth / 2 + BallPhysics.radius
    XCTAssertTrue(
        abs(ball.position.x) <= halfL && abs(ball.position.z) <= halfW,
        "Ball '\(ball.name)' out of bounds: (\(ball.position.x), \(ball.position.z))",
        file: file, line: line
    )
}
