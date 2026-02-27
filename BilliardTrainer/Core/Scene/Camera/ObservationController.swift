//
//  ObservationController.swift
//  BilliardTrainer
//
//  观察视角控制器：击球后斜俯视观察 + 球停回归瞄准态
//

import SceneKit

final class ObservationController {

    private let cameraRig: CameraRig
    private let softClampFactor: Float = 0.2
    private var userHasTakenOverCamera: Bool = false

    init(cameraRig: CameraRig) {
        self.cameraRig = cameraRig
    }

    // MARK: - Enter Observation

    /// 进入观察视角（击球后调用）
    /// 与“观察按钮”保持一致：pivot=白球，yaw=当前瞄准方向
    func enterObservation(cueBallPosition: SCNVector3, aimDirection: SCNVector3) {
        guard TrainingCameraConfig.observationViewEnabled else { return }

        userHasTakenOverCamera = false
        applyObservationLikeToggle(cueBallPosition: cueBallPosition, aimDirection: aimDirection)
    }

    // MARK: - Observation Update

    /// 观察态每帧更新：读取 CameraContext 策略并输出目标 pose
    func updateObservation(context: CameraContext, cueBallPosition _: SCNVector3) {
        if !userHasTakenOverCamera {
            cameraRig.targetPivot = softClampPivot(cameraRig.targetPivot)
        }

        let isInteractionLocked = context.interaction == .rotatingCamera
        let isTransitionLocked = context.transition?.isActive == true || cameraRig.isTransitioning
        if isInteractionLocked || isTransitionLocked || userHasTakenOverCamera {
            return
        }

        // 击球后不再自动跟随/自动重构图：保持当前观察镜头。
    }

    private func applyObservationLikeToggle(cueBallPosition: SCNVector3, aimDirection: SCNVector3) {
        let tableY = TablePhysics.height
        cameraRig.disableSmoothPoseControl()
        cameraRig.targetPivot = SCNVector3(cueBallPosition.x, tableY, cueBallPosition.z)
        let flatAim = SCNVector3(aimDirection.x, 0, aimDirection.z).normalized()
        if flatAim.length() > 0.0001 {
            cameraRig.targetYaw = atan2f(-flatAim.z, -flatAim.x)
        }
        cameraRig.pushToObservation(animated: true)
        cameraRig.beginConstantSpeedTransition(speed: TrainingCameraConfig.cameraTransitionSpeed)
    }

    private func softClampPivot(_ pivot: SCNVector3) -> SCNVector3 {
        let margin = BallPhysics.radius * 1.2
        let halfLength = TablePhysics.innerLength * 0.5 - margin
        let halfWidth = TablePhysics.innerWidth * 0.5 - margin
        let clamped = SCNVector3(
            max(-halfLength, min(halfLength, pivot.x)),
            TablePhysics.height,
            max(-halfWidth, min(halfWidth, pivot.z))
        )
        return SCNVector3(
            lerp(pivot.x, clamped.x, t: softClampFactor),
            TablePhysics.height,
            lerp(pivot.z, clamped.z, t: softClampFactor)
        )
    }

    private func lerp(_ a: Float, _ b: Float, t: Float) -> Float {
        a + (b - a) * clamp(t, min: 0, max: 1)
    }

    private func clamp(_ value: Float, min lower: Float, max upper: Float) -> Float {
        max(lower, min(upper, value))
    }

    /// 观察态中用户手动旋转
    func handleObservationPan(deltaX: Float, deltaY: Float) {
        userHasTakenOverCamera = true
        cameraRig.handleHorizontalSwipe(delta: deltaX, sensitivity: nil)
        cameraRig.handleVerticalSwipe(delta: -deltaY)
    }

    /// 观察态中用户手动缩放
    func handleObservationPinch(scale: Float) {
        userHasTakenOverCamera = true
        cameraRig.handlePinch(scale: scale)
    }

    /// 目标球切换后的显式重构图：旋转到球杆与瞄准线居中的观察视角
    func focusOnSelection(
        cueBallPosition: SCNVector3,
        targetPosition: SCNVector3,
        aimDirection: SCNVector3
    ) {
        userHasTakenOverCamera = false
        _ = targetPosition
        applyObservationLikeToggle(cueBallPosition: cueBallPosition, aimDirection: aimDirection)
    }

    // MARK: - Return To Aim

    /// 开始回归瞄准态（球停后调用）
    func beginReturnToAim(
        cueBallPosition: SCNVector3,
        savedZoom: Float,
        targetYaw: Float
    ) {
        userHasTakenOverCamera = false
        let tableSurfaceY = TablePhysics.height
        cameraRig.targetPivot = SCNVector3(
            cueBallPosition.x,
            tableSurfaceY,
            cueBallPosition.z
        )
        cameraRig.returnToAim(zoom: savedZoom, animated: true)
        cameraRig.targetYaw = targetYaw
        cameraRig.beginConstantSpeedTransition(speed: TrainingCameraConfig.cameraTransitionSpeed)
    }
}
