//
//  AimingController.swift
//  BilliardTrainer
//
//  瞄准控制器：水平滑动瞄准 + 动态灵敏度（有球/无球区域自适应）
//

import SceneKit

final class AimingController {

    private let cameraRig: CameraRig

    init(cameraRig: CameraRig) {
        self.cameraRig = cameraRig
    }

    // MARK: - Dynamic Sensitivity

    /// 根据瞄准方向前方是否有球，计算当前灵敏度
    func computeSensitivity(
        aimDirection: SCNVector3,
        cueBallPos: SCNVector3,
        targetBalls: [SCNVector3]
    ) -> Float {
        let high = TrainingCameraConfig.highSensitivity
        let low = TrainingCameraConfig.lowSensitivity
        let thresholdDeg = TrainingCameraConfig.sensitivityTransitionAngle
        let thresholdRad = thresholdDeg * .pi / 180

        guard !targetBalls.isEmpty else { return high }

        let aimNorm = SCNVector3(aimDirection.x, 0, aimDirection.z).normalized()
        guard aimNorm.length() > 0.0001 else { return high }

        var minAngle: Float = .pi

        for ballPos in targetBalls {
            let toBall = SCNVector3(ballPos.x - cueBallPos.x, 0, ballPos.z - cueBallPos.z)
            let dist = toBall.length()
            guard dist > 0.01 else { continue }

            let toBallNorm = toBall * (1.0 / dist)
            let dot = max(-1, min(1, aimNorm.dot(toBallNorm)))

            // 只考虑前方的球
            guard dot > 0 else { continue }

            let angle = acosf(dot)
            minAngle = min(minAngle, angle)
        }

        if minAngle >= thresholdRad {
            return high
        }

        let t = minAngle / thresholdRad
        return low + (high - low) * t
    }

    // MARK: - Horizontal Swipe Aiming

    /// 处理水平滑动瞄准，返回更新后的瞄准方向
    func handleHorizontalSwipe(
        delta: Float,
        currentAimDirection: SCNVector3,
        cueBallPos: SCNVector3,
        targetBalls: [SCNVector3]
    ) -> SCNVector3 {
        let sensitivity = computeSensitivity(
            aimDirection: currentAimDirection,
            cueBallPos: cueBallPos,
            targetBalls: targetBalls
        )

        cameraRig.handleHorizontalSwipe(delta: delta, sensitivity: sensitivity)

        return cameraRig.aimDirectionForCurrentYaw()
    }

    /// 将瞄准方向同步到相机 yaw
    func syncCameraToAimDirection(_ direction: SCNVector3) {
        cameraRig.setAimYaw(direction: direction)
    }

    /// 从相机当前 yaw 获取瞄准方向
    func aimDirectionFromCamera() -> SCNVector3 {
        cameraRig.aimDirectionForCurrentYaw()
    }
}
