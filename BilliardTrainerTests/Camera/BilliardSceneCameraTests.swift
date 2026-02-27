import XCTest
import SceneKit
@testable import BilliardTrainer

final class BilliardSceneCameraTests: XCTestCase {

    private var scene: BilliardScene!

    override func setUp() {
        super.setUp()
        scene = BilliardScene()
    }

    override func tearDown() {
        scene = nil
        super.tearDown()
    }

    // MARK: - CameraMode 基础测试

    func testDefaultCameraModeIsAim() {
        XCTAssertEqual(scene.currentCameraMode, .aim)
    }

    func testSetCameraModeChangesMode() {
        let modes: [BilliardScene.CameraMode] = [.topDown2D, .action, .aim]
        for mode in modes {
            scene.setCameraMode(mode, animated: false)
            if mode == .action {
                XCTAssertEqual(scene.currentCameraMode, .aim, "Action should be folded into aim mode")
            } else {
                XCTAssertEqual(scene.currentCameraMode, mode, "Expected mode \(mode)")
            }
        }
    }

    func testCameraModeChangedCallback() {
        var receivedMode: BilliardScene.CameraMode?
        scene.onCameraModeChanged = { mode in
            receivedMode = mode
        }

        scene.setCameraMode(.topDown2D, animated: false)
        XCTAssertEqual(receivedMode, .topDown2D)
    }

    func testCameraModeCallbackNotFiredForSameMode() {
        scene.setCameraMode(.topDown2D, animated: false)

        var callbackCount = 0
        scene.onCameraModeChanged = { _ in callbackCount += 1 }

        scene.setCameraMode(.topDown2D, animated: false)
        XCTAssertEqual(callbackCount, 0, "Callback should not fire when mode doesn't change")
    }

    // MARK: - 相机投影与约束

    func testTopDown2DCameraPositionAndProjection() {
        scene.setCameraMode(.topDown2D, animated: false)
        let pos = scene.cameraNode.position
        XCTAssertEqual(pos.y, 4.0, accuracy: 0.01)
        XCTAssertEqual(pos.x, 0.0, accuracy: 0.01)
        XCTAssertTrue(scene.cameraNode.camera?.usesOrthographicProjection == true)
    }

    func testAimModeUsesPerspectiveProjection() {
        scene.setCameraMode(.aim, animated: false)
        XCTAssertFalse(scene.cameraNode.camera?.usesOrthographicProjection == true)
    }

    // MARK: - CameraRig 行为

    func testSetCameraPostShotKeepsAimModeWithObservingPhase() {
        scene.setCameraMode(.aim, animated: false)
        let cueBallPos = SCNVector3(0, TablePhysics.height + BallPhysics.radius, 0)
        let aimDir = SCNVector3(1, 0, 0)

        scene.setCameraPostShot(cueBallPosition: cueBallPos, aimDirection: aimDir)
        XCTAssertEqual(scene.currentCameraMode, .aim)
    }

    func testApplyCameraPanAffectsAimDirection() {
        scene.setCameraMode(.aim, animated: false)
        scene.setAimDirectionForCamera(SCNVector3(-1, 0, 0))
        let cuePos = scene.cueBallNode?.position ?? SCNVector3(0, TablePhysics.height + BallPhysics.radius, 0)

        let before = scene.currentAimDirectionFromCamera()
        scene.applyCameraPan(deltaX: 80, deltaY: 0)
        for _ in 0..<20 {
            scene.updateCameraRig(deltaTime: 1.0 / 60.0, cueBallPosition: cuePos)
        }
        let after = scene.currentAimDirectionFromCamera()

        XCTAssertGreaterThan(abs(after.x - before.x) + abs(after.z - before.z), 0.01,
                             "Horizontal pan should change camera yaw/aim direction")
    }

    func testApplyCameraPanPansInTopDown() {
        scene.setCameraMode(.topDown2D, animated: false)
        let posBefore = scene.cameraNode.position
        scene.applyCameraPan(deltaX: 200, deltaY: 200)
        XCTAssertGreaterThan(abs(scene.cameraNode.position.x - posBefore.x) + abs(scene.cameraNode.position.z - posBefore.z), 0.001)
    }

    func testApplyCameraPinchAffectsZoomInAim() {
        scene.setCameraMode(.aim, animated: false)
        let cuePos = scene.cueBallNode?.position ?? SCNVector3(0, TablePhysics.height + BallPhysics.radius, 0)

        scene.applyCameraPan(deltaX: 0, deltaY: -120) // 先把 zoom 拉到 > 0
        for _ in 0..<15 {
            scene.updateCameraRig(deltaTime: 1.0 / 60.0, cueBallPosition: cuePos)
        }
        let zoomBefore = scene.currentCameraZoom

        scene.applyCameraPinch(scale: 2.0) // 近一点（zoom 减小）
        for _ in 0..<15 {
            scene.updateCameraRig(deltaTime: 1.0 / 60.0, cueBallPosition: cuePos)
        }
        let zoomAfter = scene.currentCameraZoom

        XCTAssertLessThan(zoomAfter, zoomBefore, "Pinch-in should reduce rig zoom")
    }

    func testApplyCameraPinchDoesNotChangeOrthographicInTopDown() {
        scene.setCameraMode(.topDown2D, animated: false)
        let scaleBefore = scene.cameraNode.camera?.orthographicScale ?? 1.0
        scene.applyCameraPinch(scale: 2.0)
        let scaleAfter = scene.cameraNode.camera?.orthographicScale ?? 1.0

        XCTAssertEqual(scaleAfter, scaleBefore, accuracy: 0.0001,
                       "TopDown orthographic scale is controlled by area zoom path, not generic pinch")
    }

    func testObservingModeDoesNotFollowCueBallByDefault() {
        scene.setCameraMode(.aim, animated: false)
        let cuePos = scene.cueBallNode?.position ?? SCNVector3(0, TablePhysics.height + BallPhysics.radius, 0)

        scene.cameraStateMachine.saveAimContext(aimDirection: SCNVector3(-1, 0, 0), zoom: 0)
        scene.cameraStateMachine.handleEvent(.shotFired)
        scene.cameraStateMachine.handleEvent(.ballsStartedMoving)
        scene.setCameraPostShot(cueBallPosition: cuePos, aimDirection: SCNVector3(-1, 0, 0))

        for _ in 0..<120 {
            scene.updateCameraRig(deltaTime: 1.0 / 60.0, cueBallPosition: cuePos)
        }
        let stablePos = scene.cameraNode.position

        let movedCue = cuePos + SCNVector3(0.8, 0, 0.6)
        for _ in 0..<120 {
            scene.updateCameraRig(deltaTime: 1.0 / 60.0, cueBallPosition: movedCue)
        }
        XCTAssertVector3Equal(scene.cameraNode.position, stablePos, accuracy: 0.10,
                              "Observing mode should not auto-follow cue ball by default")
    }

    func testReturnCameraToAimSwitchesMode() {
        scene.setCameraMode(.action, animated: false)
        scene.returnCameraToAim(animated: false)
        XCTAssertEqual(scene.currentCameraMode, .aim)
    }

    func testAnchoredOrbitLockDoesNotCrash() {
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 1000, height: 600))
        view.scene = scene
        view.pointOfView = scene.cameraNode

        scene.setCameraMode(.aim, animated: false)
        scene.cameraStateMachine.forceState(.aiming)
        let cueWorld = scene.cueBallNode?.position ?? SCNVector3(0, TablePhysics.height + BallPhysics.radius, 0)

        scene.applyCameraPan(deltaX: 120, deltaY: 0)
        for _ in 0..<60 {
            scene.updateCameraRig(deltaTime: 1.0 / 60.0, cueBallPosition: cueWorld)
            scene.lockCueBallScreenAnchor(
                in: view,
                cueBallWorld: cueWorld,
                anchorNormalized: CGPoint(x: 0.5, y: 0.5)
            )
        }

        let projected = view.projectPoint(cueWorld)
        XCTAssertTrue(projected.z.isFinite || projected.z == 0,
                      "Projection Z should be finite or zero")
    }

    // MARK: - Roll Lock

    func testCameraRollAlwaysZero() {
        let modes: [BilliardScene.CameraMode] = [.aim, .topDown2D, .action]
        for mode in modes {
            scene.setCameraMode(mode, animated: false)
            if let cuePos = scene.cueBallNode?.position {
                scene.updateCameraRig(deltaTime: 1.0 / 60.0, cueBallPosition: cuePos)
            }
            XCTAssertEqual(scene.cameraNode.eulerAngles.z, 0, accuracy: 0.001,
                           "Roll should always be 0 (mode: \(mode))")
        }
    }

    // MARK: - 相机常量验证

    func testCameraRigConfigReasonableValues() {
        XCTAssertEqual(TrainingCameraConfig.fov, TrainingCameraConfig.standFov, accuracy: 0.1)
        XCTAssertEqual(TrainingCameraConfig.aimFov, 40, accuracy: 0.1)
        XCTAssertGreaterThanOrEqual(TrainingCameraConfig.minZoom, 0)
        XCTAssertLessThanOrEqual(TrainingCameraConfig.maxZoom, 1)
        XCTAssertLessThan(TrainingCameraConfig.aimRadius, TrainingCameraConfig.standRadius)
        XCTAssertLessThan(TrainingCameraConfig.aimHeight, TrainingCameraConfig.standHeight)
        XCTAssertLessThan(TrainingCameraConfig.standPitchRad, TrainingCameraConfig.aimPitchRad)
        XCTAssertGreaterThan(TrainingCameraConfig.transitionDuration, 0)
        XCTAssertEqual(TrainingCameraConfig.minDistance, 0.3, accuracy: 0.001)
    }
}
