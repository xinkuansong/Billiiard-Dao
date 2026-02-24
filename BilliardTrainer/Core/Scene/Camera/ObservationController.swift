//
//  ObservationController.swift
//  BilliardTrainer
//
//  观察视角控制器：击球后斜俯视观察 + 球停回归瞄准态
//

import SceneKit

final class ObservationController {

    private let cameraRig: CameraRig

    init(cameraRig: CameraRig) {
        self.cameraRig = cameraRig
    }

    // MARK: - Enter Observation

    /// 进入观察视角（击球后调用）
    /// 从当前瞄准位置平滑过渡到球桌长边侧视：
    /// yaw 旋转到最近的 ±π/2，pivot 移至球桌中心，zoom 升至站立姿态
    /// CameraRig 阻尼插值自动完成平滑过渡
    func enterObservation(cueBallPosition: SCNVector3, aimDirection: SCNVector3) {
        guard TrainingCameraConfig.observationViewEnabled else { return }

        let tableSurfaceY = TablePhysics.height
        cameraRig.targetPivot = SCNVector3(0, tableSurfaceY, 0)

        cameraRig.targetYaw = bestObservationYaw(
            cueBallPosition: cueBallPosition,
            aimDirection: aimDirection
        )

        cameraRig.pushToObservation(animated: true)
        cameraRig.beginConstantSpeedTransition()
    }

    /// 根据击球反方向和白球到四边的距离，选择最自然的观察边
    /// 优先选择击球反方向所对应的最近库边，实现"自然后退"的观察感
    private func bestObservationYaw(cueBallPosition: SCNVector3, aimDirection: SCNVector3) -> Float {
        let halfL = TablePhysics.innerLength / 2
        let halfW = TablePhysics.innerWidth / 2

        // 四个候选边：yaw 角度、白球到该边的垂直距离、从该边看向球桌中心的方向向量
        struct EdgeCandidate {
            let yaw: Float
            let distFromCueBall: Float
            let edgeNormalX: Float
            let edgeNormalZ: Float
        }

        let candidates: [EdgeCandidate] = [
            // +Z 长边 (yaw = π/2)：相机在 +Z 侧看向 -Z
            EdgeCandidate(yaw: .pi / 2,  distFromCueBall: halfW - cueBallPosition.z, edgeNormalX: 0, edgeNormalZ: -1),
            // -Z 长边 (yaw = -π/2)：相机在 -Z 侧看向 +Z
            EdgeCandidate(yaw: -.pi / 2, distFromCueBall: halfW + cueBallPosition.z, edgeNormalX: 0, edgeNormalZ: 1),
            // +X 短边 (yaw = π)：相机在 +X 侧看向 -X
            EdgeCandidate(yaw: .pi,      distFromCueBall: halfL - cueBallPosition.x, edgeNormalX: -1, edgeNormalZ: 0),
            // -X 短边 (yaw = 0)：相机在 -X 侧看向 +X
            EdgeCandidate(yaw: 0,        distFromCueBall: halfL + cueBallPosition.x, edgeNormalX: 1, edgeNormalZ: 0),
        ]

        let aim = SCNVector3(aimDirection.x, 0, aimDirection.z).normalized()
        let reverseAimX = -aim.x
        let reverseAimZ = -aim.z

        var bestYaw: Float = candidates[0].yaw
        var bestScore: Float = -.greatestFiniteMagnitude

        for edge in candidates {
            // 击球反方向与该边法线的点积：值越大表示该边越"在身后"
            let directionAlignment = reverseAimX * edge.edgeNormalX + reverseAimZ * edge.edgeNormalZ
            // 白球越靠近该边，从该边观察越自然（距离近 = 分数高）
            let proximityScore = 1.0 / max(0.1, edge.distFromCueBall)
            // 综合评分：方向对齐为主（权重 0.7），距离为辅（权重 0.3）
            let score = directionAlignment * 0.7 + proximityScore * 0.3

            if score > bestScore {
                bestScore = score
                bestYaw = edge.yaw
            }
        }

        return bestYaw
    }

    // MARK: - Observation Update

    /// 观察态每帧更新：pivot 固定在球桌中心，不跟随白球
    func updateObservation(cueBallPosition: SCNVector3) {
    }

    private func shortestAngleDelta(from: Float, to: Float) -> Float {
        var delta = to - from
        while delta > .pi { delta -= 2 * .pi }
        while delta < -.pi { delta += 2 * .pi }
        return delta
    }

    /// 观察态中用户手动旋转
    func handleObservationPan(deltaX: Float, deltaY: Float) {
        cameraRig.handleHorizontalSwipe(delta: deltaX, sensitivity: nil)
        cameraRig.handleVerticalSwipe(delta: -deltaY)
    }

    /// 观察态中用户手动缩放
    func handleObservationPinch(scale: Float) {
        cameraRig.handlePinch(scale: scale)
    }

    // MARK: - Return To Aim

    /// 开始回归瞄准态（球停后调用）
    func beginReturnToAim(
        cueBallPosition: SCNVector3,
        savedZoom: Float,
        targetYaw: Float
    ) {
        let tableSurfaceY = TablePhysics.height
        cameraRig.targetPivot = SCNVector3(
            cueBallPosition.x,
            tableSurfaceY,
            cueBallPosition.z
        )
        cameraRig.returnToAim(zoom: savedZoom, animated: true)
        cameraRig.targetYaw = targetYaw
        cameraRig.beginConstantSpeedTransition()
    }
}
