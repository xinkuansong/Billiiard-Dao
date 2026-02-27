import XCTest
import SceneKit
@testable import BilliardTrainer

final class CameraViewModelTests: XCTestCase {

    private var viewModel: BilliardSceneViewModel!

    override func setUp() {
        super.setUp()
        viewModel = BilliardSceneViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }

    // MARK: - 初始状态

    func testInitialCameraStateIsAim() {
        XCTAssertEqual(viewModel.cameraState, .aim)
    }

    func testInitialPitchAngle() {
        XCTAssertEqual(viewModel.pitchAngle, CameraRigConfig.aimPitchRad, accuracy: 0.001)
    }

    func testInitialSceneModeIsAim() {
        XCTAssertEqual(viewModel.scene.currentCameraMode, .aim)
    }

    // MARK: - 模式切换

    func testCycleFromAimToTopDown() {
        XCTAssertEqual(viewModel.scene.currentCameraMode, .aim)

        viewModel.cycleNextCameraMode()

        XCTAssertEqual(viewModel.scene.currentCameraMode, .topDown2D)
        XCTAssertEqual(viewModel.cameraState, .topDown2D)
    }

    func testCycleBackToAim() {
        viewModel.cycleNextCameraMode() // -> topDown2D
        viewModel.cycleNextCameraMode() // -> aim
        XCTAssertEqual(viewModel.scene.currentCameraMode, .aim)
        XCTAssertEqual(viewModel.cameraState, .aim)
    }

    func testCycleUpdatesIsTopDownView() {
        viewModel.cycleNextCameraMode()
        XCTAssertTrue(viewModel.isTopDownView, "Should be topDown after first cycle")

        viewModel.cycleNextCameraMode()
        XCTAssertFalse(viewModel.isTopDownView, "Should not be topDown after second cycle")
    }

    // MARK: - 2D/3D 切换 (toggleViewMode)

    func testToggleToTopDown() {
        XCTAssertFalse(viewModel.isTopDownView)

        viewModel.toggleViewMode()

        XCTAssertTrue(viewModel.isTopDownView)
        XCTAssertEqual(viewModel.scene.currentCameraMode, .topDown2D)
        XCTAssertEqual(viewModel.cameraState, .topDown2D)
    }

    func testToggleBackToAim() {
        viewModel.toggleViewMode()
        XCTAssertTrue(viewModel.isTopDownView)

        viewModel.toggleViewMode()
        XCTAssertFalse(viewModel.isTopDownView)
        XCTAssertEqual(viewModel.scene.currentCameraMode, .aim)
        XCTAssertEqual(viewModel.cameraState, .aim)
    }

    // MARK: - 预设/快捷操作（当前为兼容空实现）

    func testApplyCameraPresetNoOpKeepsCameraStable() {
        let modeBefore = viewModel.scene.currentCameraMode
        let posBefore = viewModel.scene.cameraNode.position

        viewModel.applyCameraPreset("fullTable")

        XCTAssertEqual(viewModel.scene.currentCameraMode, modeBefore)
        XCTAssertVector3Equal(viewModel.scene.cameraNode.position, posBefore, accuracy: 0.001)
    }

    func testSaveAndLoadCameraPresetNoCrash() {
        let posBefore = viewModel.scene.cameraNode.position
        viewModel.saveCameraPreset(slot: 3)
        viewModel.loadCameraPreset(slot: 3)
        XCTAssertVector3Equal(viewModel.scene.cameraNode.position, posBefore, accuracy: 0.001)
    }

    // MARK: - 快速重置

    func testQuickResetPlanningCamera() {
        viewModel.quickResetPlanningCamera()

        XCTAssertEqual(viewModel.cameraState, .topDown2D)
        XCTAssertEqual(viewModel.scene.currentCameraMode, .topDown2D)
    }

    func testQuickResetFromTopDown() {
        viewModel.toggleViewMode()
        XCTAssertEqual(viewModel.scene.currentCameraMode, .topDown2D)

        viewModel.quickResetPlanningCamera()

        XCTAssertEqual(viewModel.scene.currentCameraMode, .aim,
                       "Quick reset from topDown should switch back to aim")
    }

    // MARK: - placing / aiming

    func testEnterPlacingModeKeepsAimModeWhenNotTopDown() {
        viewModel.enterPlacingMode()
        XCTAssertEqual(viewModel.gameState, .placing)
        XCTAssertEqual(viewModel.scene.currentCameraMode, .aim)
    }

    func testConfirmCueBallPlacementReturnsToAiming() {
        viewModel.enterPlacingMode()
        viewModel.confirmCueBallPlacement()
        XCTAssertEqual(viewModel.gameState, .aiming)
        XCTAssertEqual(viewModel.scene.currentCameraMode, .aim)
    }

    // MARK: - InputRouter v1

    func testInputRouterTapSelectsTargetInAiming() {
        let router = InputRouter()
        var context = CameraContext.default
        context.mode = .aim3D
        context.phase = .aiming

        let hit = HitResult(isUI: false, isBall: true, isCueBall: false, isTargetBall: true, ballId: "ball_3")
        let intent = router.routeTap(hit: hit, context: context)

        XCTAssertEqual(intent, .selectTarget("ball_3"))
    }

    func testInputRouterTapIgnoredWhenTransitionLocksInput() {
        let router = InputRouter()
        var context = CameraContext.default
        context.phase = .aiming
        context.transition = TransitionState(isActive: true, locksCameraInput: true)

        let hit = HitResult(isUI: false, isBall: true, isCueBall: false, isTargetBall: true, ballId: "ball_9")
        XCTAssertEqual(router.routeTap(hit: hit, context: context), .none)
    }

    func testInputRouterPanDragsCueBallOnlyInBallPlacement() {
        let router = InputRouter()
        var context = CameraContext.default
        context.mode = .aim3D
        context.phase = .ballPlacement

        let cueHit = HitResult(isUI: false, isBall: true, isCueBall: true, isTargetBall: false, ballId: nil)
        let intent = router.routePan(
            startHit: cueHit,
            input: PanGestureInput(deltaX: 10, deltaY: 5),
            context: context
        )
        XCTAssertEqual(intent, .dragCueBall)
    }

    func testInputRouterPanOnBallDoesNotRotateCamera() {
        let router = InputRouter()
        var context = CameraContext.default
        context.mode = .observe3D
        context.phase = .aiming

        let targetHit = HitResult(isUI: false, isBall: true, isCueBall: false, isTargetBall: true, ballId: "ball_5")
        let intent = router.routePan(
            startHit: targetHit,
            input: PanGestureInput(deltaX: 20, deltaY: 10),
            context: context
        )
        XCTAssertEqual(intent, .none)
    }

    func testInputRouterPanBlankAreaRoutesByMode() {
        let router = InputRouter()
        let blank = HitResult.none

        var aimContext = CameraContext.default
        aimContext.mode = .aim3D
        aimContext.phase = .aiming
        let aimIntent = router.routePan(
            startHit: blank,
            input: PanGestureInput(deltaX: 12, deltaY: 7),
            context: aimContext
        )
        XCTAssertEqual(aimIntent, .rotateYaw(12))

        var observeContext = CameraContext.default
        observeContext.mode = .observe3D
        observeContext.phase = .postShot
        let observeIntent = router.routePan(
            startHit: blank,
            input: PanGestureInput(deltaX: 12, deltaY: 7),
            context: observeContext
        )
        XCTAssertEqual(observeIntent, .rotateYawPitch(deltaX: 12, deltaY: 7))

        var topContext = CameraContext.default
        topContext.mode = .topDown2D
        let topIntent = router.routePan(
            startHit: blank,
            input: PanGestureInput(deltaX: 12, deltaY: 7),
            context: topContext
        )
        XCTAssertEqual(topIntent, .panTopDown(deltaX: 12, deltaY: 7))
    }

    func testCameraContextFollowsStateMachineTransition() {
        viewModel.scene.cameraStateMachine.forceState(.observing)
        XCTAssertEqual(viewModel.cameraContext.mode, .observe3D)
        XCTAssertEqual(viewModel.cameraContext.phase, .shotRunning)

        viewModel.scene.cameraStateMachine.forceState(.aiming)
        XCTAssertEqual(viewModel.cameraContext.mode, .aim3D)
        XCTAssertEqual(viewModel.cameraContext.phase, .aiming)
    }
}
