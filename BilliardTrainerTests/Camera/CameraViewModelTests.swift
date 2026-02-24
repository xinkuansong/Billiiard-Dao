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
}
