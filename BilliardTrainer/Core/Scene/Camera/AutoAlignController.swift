//
//  AutoAlignController.swift
//  BilliardTrainer
//
//  自动对齐控制器：球停后自动对齐最近可击打球方向（可关闭）
//

import SceneKit

final class AutoAlignController {

    private let cameraRig: CameraRig

    init(cameraRig: CameraRig) {
        self.cameraRig = cameraRig
    }

    /// 计算自动对齐的目标 yaw
    /// 返回 nil 表示不需要对齐（功能关闭或无可击打球）
    func computeAlignYaw(
        cueBallPos: SCNVector3,
        targetBalls: [SCNVector3],
        fallbackDirection: SCNVector3
    ) -> Float {
        guard TrainingCameraConfig.autoAlignEnabled, !targetBalls.isEmpty else {
            return yawFromDirection(fallbackDirection)
        }

        var closestDist: Float = .greatestFiniteMagnitude
        var closestBallPos: SCNVector3?

        for ballPos in targetBalls {
            let dx = ballPos.x - cueBallPos.x
            let dz = ballPos.z - cueBallPos.z
            let dist = sqrtf(dx * dx + dz * dz)
            if dist > 0.01 && dist < closestDist {
                closestDist = dist
                closestBallPos = ballPos
            }
        }

        guard let nearest = closestBallPos else {
            return yawFromDirection(fallbackDirection)
        }

        let direction = SCNVector3(
            nearest.x - cueBallPos.x,
            0,
            nearest.z - cueBallPos.z
        ).normalized()

        return yawFromDirection(direction)
    }

    /// 从方向向量计算 yaw 角度
    func yawFromDirection(_ direction: SCNVector3) -> Float {
        let flat = SCNVector3(direction.x, 0, direction.z).normalized()
        guard flat.length() > 0.0001 else { return 0 }
        return atan2f(-flat.z, -flat.x)
    }

    /// 从 yaw 角度计算方向向量
    func directionFromYaw(_ yaw: Float) -> SCNVector3 {
        SCNVector3(-cosf(yaw), 0, -sinf(yaw)).normalized()
    }
}
