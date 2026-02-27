//
//  CameraRig.swift
//  BilliardTrainer
//
//  统一 CameraRig：zoom(0~1) 驱动人体姿态参数联动
//  zoom=0 俯身瞄准（第一人称），zoom=1 站立观察（第三人称）
//

import SceneKit

final class CameraRig {
    struct SmoothPose {
        var yaw: Float
        var pitch: Float
        var radius: Float
        var pivot: SCNVector3
        var fov: CGFloat
    }

    struct Config {
        let aimFov: CGFloat
        let standFov: CGFloat
        let minRadius: Float
        let maxRadius: Float
        let minHeight: Float
        let maxHeight: Float
        let aimPitchRad: Float
        let standPitchRad: Float
        let aimYawSensitivity: Float
        let standYawSensitivity: Float
        let dampingFactor: Float
        let minPitchRad: Float
        let maxPitchRad: Float
        let minHeightAboveTable: Float
        let minDistance: Float
        let zoomSwipeSensitivity: Float
        let zoomPinchSensitivity: Float

        var fov: CGFloat { standFov }

        static let `default` = Config(
            aimFov: TrainingCameraConfig.aimFov,
            standFov: TrainingCameraConfig.standFov,
            minRadius: TrainingCameraConfig.aimRadius,
            maxRadius: TrainingCameraConfig.standRadius,
            minHeight: TrainingCameraConfig.aimHeight,
            maxHeight: TrainingCameraConfig.standHeight,
            aimPitchRad: TrainingCameraConfig.aimPitchRad,
            standPitchRad: TrainingCameraConfig.standPitchRad,
            aimYawSensitivity: TrainingCameraConfig.aimYawSensitivity,
            standYawSensitivity: TrainingCameraConfig.standYawSensitivity,
            dampingFactor: TrainingCameraConfig.dampingFactor,
            minPitchRad: TrainingCameraConfig.minPitchRad,
            maxPitchRad: TrainingCameraConfig.maxPitchRad,
            minHeightAboveTable: TrainingCameraConfig.minHeightAboveTable,
            minDistance: TrainingCameraConfig.minDistance,
            zoomSwipeSensitivity: TrainingCameraConfig.zoomSwipeSensitivity,
            zoomPinchSensitivity: TrainingCameraConfig.zoomPinchSensitivity
        )
    }

    private let cameraNode: SCNNode
    private let tableSurfaceY: Float
    private let config: Config

    var targetPivot: SCNVector3
    var targetZoom: Float
    var targetYaw: Float

    private(set) var currentPivot: SCNVector3
    private(set) var currentZoom: Float
    private(set) var currentYaw: Float

    // MARK: - 固定速度过渡系统

    private struct Transition {
        let startPivot: SCNVector3
        let startZoom: Float
        let startYaw: Float
        let endPivot: SCNVector3
        let endZoom: Float
        let endYaw: Float
        let duration: Float
        var elapsed: Float = 0
    }

    private var activeTransition: Transition?
    private struct SmoothTransition {
        let start: SmoothPose
        let end: SmoothPose
        let duration: Float
        var elapsed: Float = 0
    }
    private var currentSmoothPose: SmoothPose?
    private var targetSmoothPose: SmoothPose?
    private var activeSmoothTransition: SmoothTransition?

    /// 是否有正在进行的过渡动画
    var isTransitioning: Bool { activeTransition != nil || activeSmoothTransition != nil }

    init(cameraNode: SCNNode, tableSurfaceY: Float, config: Config = .default) {
        self.cameraNode = cameraNode
        self.tableSurfaceY = tableSurfaceY
        self.config = config

        targetPivot = SCNVector3(0, tableSurfaceY, 0)
        targetZoom = 0
        targetYaw = .pi
        currentPivot = targetPivot
        currentZoom = targetZoom
        currentYaw = targetYaw

        cameraNode.camera?.fieldOfView = config.aimFov
        applyCameraTransform()
    }

    var zoom: Float { currentZoom }
    var yaw: Float { currentYaw }
    var pitch: Float {
        if let pose = currentSmoothPose {
            return pose.pitch
        }
        let clampedZoom = clampZoom(currentZoom)
        let easedZoom = clampedZoom * clampedZoom
        var p = lerp(config.aimPitchRad, config.standPitchRad, easedZoom)
        p = max(config.minPitchRad, min(config.maxPitchRad, p))
        return p
    }
    var radius: Float {
        if let pose = currentSmoothPose {
            return pose.radius
        }
        return radiusForZoom(currentZoom)
    }

    func setTargetZoom(_ zoom: Float) {
        disableSmoothPoseControl()
        targetZoom = clampZoom(zoom)
    }

    func handleVerticalSwipe(delta: Float) {
        let newZoom = clampZoom(targetZoom + delta * config.zoomSwipeSensitivity)
        targetZoom = newZoom
        // 拖动期间直接同步当前值，避免“抬手后才明显生效”的滞后感
        currentZoom = newZoom
    }

    /// 使用指定灵敏度处理水平滑动（由 AimingController 提供动态灵敏度）
    func handleHorizontalSwipe(delta: Float, sensitivity: Float? = nil) {
        disableSmoothPoseControl()
        let sens = sensitivity ?? lerp(config.aimYawSensitivity, config.standYawSensitivity, currentZoom)
        let yawDelta = delta * sens
        targetYaw += yawDelta
        // 拖动期间直接同步当前值，提升跟手性；后续仍由 target 维持一致性
        currentYaw += yawDelta
    }

    func handlePinch(scale: Float) {
        disableSmoothPoseControl()
        let pinchDelta = (1 - max(0.01, scale)) * config.zoomPinchSensitivity
        setTargetZoom(targetZoom + pinchDelta)
    }

    func setAimYaw(direction: SCNVector3) {
        disableSmoothPoseControl()
        let flat = SCNVector3(direction.x, 0, direction.z).normalized()
        guard flat.length() > 0.0001 else { return }
        targetYaw = atan2f(-flat.z, -flat.x)
    }

    func pushToObservation(animated: Bool) {
        disableSmoothPoseControl()
        targetZoom = TrainingCameraConfig.observationZoom
        if !animated {
            currentZoom = targetZoom
        }
    }

    func returnToAim(zoom: Float, animated: Bool) {
        disableSmoothPoseControl()
        targetZoom = clampZoom(zoom)
        if !animated {
            currentZoom = targetZoom
        }
    }

    /// 启动固定速度过渡：从当前位置线性移动到 target 值
    /// speed 为摄像机 3D 移动速度（米/秒），duration 由距离自动计算
    func beginConstantSpeedTransition(speed: Float = TrainingCameraConfig.cameraTransitionSpeed) {
        disableSmoothPoseControl()
        let startPos = cameraWorldPosition(pivot: currentPivot, zoom: currentZoom, yaw: currentYaw)
        let endPos = cameraWorldPosition(pivot: targetPivot, zoom: targetZoom, yaw: targetYaw)
        let dist = (endPos - startPos).length()
        let duration = max(0.3, dist / max(0.01, speed))

        activeTransition = Transition(
            startPivot: currentPivot,
            startZoom: currentZoom,
            startYaw: currentYaw,
            endPivot: targetPivot,
            endZoom: targetZoom,
            endYaw: targetYaw,
            duration: duration
        )
    }

    func smoothToPose(_ pose: SmoothPose, duration: Float) {
        let normalizedDuration = max(0.01, duration)
        let startPose = currentSmoothPose ?? SmoothPose(
            yaw: currentYaw,
            pitch: pitch,
            radius: radiusForZoom(currentZoom),
            pivot: currentPivot,
            fov: cameraNode.camera?.fieldOfView ?? config.aimFov
        )
        activeTransition = nil
        targetSmoothPose = pose
        activeSmoothTransition = SmoothTransition(
            start: startPose,
            end: pose,
            duration: normalizedDuration
        )
    }

    func disableSmoothPoseControl() {
        targetSmoothPose = nil
        currentSmoothPose = nil
        activeSmoothTransition = nil
    }

    /// 计算给定参数下的摄像机世界坐标（用于距离估算）
    private func cameraWorldPosition(pivot: SCNVector3, zoom: Float, yaw: Float) -> SCNVector3 {
        let z = clampZoom(zoom)
        let radius = max(config.minDistance, lerp(config.minRadius, config.maxRadius, z))
        let height = lerp(config.minHeight, config.maxHeight, z)
        let cameraY = max(tableSurfaceY + config.minHeightAboveTable, tableSurfaceY + height)
        let fwd = SCNVector3(-cosf(yaw), 0, -sinf(yaw))
        return SCNVector3(
            pivot.x - fwd.x * radius,
            cameraY,
            pivot.z - fwd.z * radius
        )
    }

    func aimDirectionForCurrentYaw() -> SCNVector3 {
        let dir = SCNVector3(-cosf(targetYaw), 0, -sinf(targetYaw))
        return dir.normalized()
    }

    func update(deltaTime: Float) {
        if var transition = activeSmoothTransition {
            transition.elapsed += deltaTime
            let progress = min(1.0, transition.elapsed / transition.duration)
            let t = smoothStep(progress)

            currentSmoothPose = SmoothPose(
                yaw: transition.start.yaw + shortestAngleDelta(from: transition.start.yaw, to: transition.end.yaw) * t,
                pitch: lerp(transition.start.pitch, transition.end.pitch, t),
                radius: lerp(transition.start.radius, transition.end.radius, t),
                pivot: transition.start.pivot + (transition.end.pivot - transition.start.pivot) * t,
                fov: CGFloat(lerp(Float(transition.start.fov), Float(transition.end.fov), t))
            )

            activeSmoothTransition = transition
            if progress >= 1.0 {
                activeSmoothTransition = nil
                currentSmoothPose = targetSmoothPose
            }

            if let pose = currentSmoothPose {
                syncOrbitState(with: pose)
                applySmoothPoseTransform(pose)
            }
            return
        } else if let targetPose = targetSmoothPose {
            let currentPose = currentSmoothPose ?? SmoothPose(
                yaw: currentYaw,
                pitch: pitch,
                radius: radiusForZoom(currentZoom),
                pivot: currentPivot,
                fov: cameraNode.camera?.fieldOfView ?? config.aimFov
            )
            let frameScale = max(0.25, min(2.0, deltaTime * 60))
            let t = min(1, config.dampingFactor * frameScale)
            currentSmoothPose = SmoothPose(
                yaw: currentPose.yaw + shortestAngleDelta(from: currentPose.yaw, to: targetPose.yaw) * t,
                pitch: lerp(currentPose.pitch, targetPose.pitch, t),
                radius: lerp(currentPose.radius, targetPose.radius, t),
                pivot: currentPose.pivot + (targetPose.pivot - currentPose.pivot) * t,
                fov: CGFloat(lerp(Float(currentPose.fov), Float(targetPose.fov), t))
            )
            if let pose = currentSmoothPose {
                syncOrbitState(with: pose)
                applySmoothPoseTransform(pose)
            }
            return
        }

        if var transition = activeTransition {
            transition.elapsed += deltaTime
            let progress = min(1.0, transition.elapsed / transition.duration)
            let t = smoothStep(progress)

            currentZoom = lerp(transition.startZoom, transition.endZoom, t)
            currentYaw = transition.startYaw + shortestAngleDelta(from: transition.startYaw, to: transition.endYaw) * t
            currentPivot = transition.startPivot + (transition.endPivot - transition.startPivot) * t

            activeTransition = transition
            if progress >= 1.0 {
                activeTransition = nil
            }
        } else {
            let frameScale = max(0.25, min(2.0, deltaTime * 60))
            let t = min(1, config.dampingFactor * frameScale)

            currentZoom += (targetZoom - currentZoom) * t
            currentYaw += shortestAngleDelta(from: currentYaw, to: targetYaw) * t
            currentPivot = currentPivot + (targetPivot - currentPivot) * t
        }

        applyCameraTransform()
    }

    func radiusForZoom(_ zoom: Float) -> Float {
        let clampedZoom = clampZoom(zoom)
        return max(config.minDistance, lerp(config.minRadius, config.maxRadius, clampedZoom))
    }

    func zoomForRadius(_ radius: Float) -> Float {
        let clampedRadius = max(config.minRadius, min(config.maxRadius, radius))
        let denom = max(0.0001, config.maxRadius - config.minRadius)
        return clampZoom((clampedRadius - config.minRadius) / denom)
    }

    /// 五阶 smootherstep 缓动：起止更柔和，减少视角切换卡顿感
    private func smoothStep(_ t: Float) -> Float {
        let x = max(0, min(1, t))
        return x * x * x * (x * (x * 6 - 15) + 10)
    }

    func translatePivot(deltaXZ: SCNVector3, immediate: Bool) {
        disableSmoothPoseControl()
        let delta = SCNVector3(deltaXZ.x, 0, deltaXZ.z)
        targetPivot = targetPivot + delta
        if immediate {
            currentPivot = currentPivot + delta
            applyCameraTransform()
        }
    }

    /// 立即同步当前值到目标值（跳过动画插值）
    func snapToTarget() {
        disableSmoothPoseControl()
        currentZoom = targetZoom
        currentYaw = targetYaw
        currentPivot = targetPivot
        applyCameraTransform()
    }

    private func syncOrbitState(with pose: SmoothPose) {
        currentPivot = pose.pivot
        targetPivot = pose.pivot
        currentYaw = pose.yaw
        targetYaw = pose.yaw
        let mappedZoom = zoomForRadius(pose.radius)
        currentZoom = mappedZoom
        targetZoom = mappedZoom
    }

    private func applySmoothPoseTransform(_ pose: SmoothPose) {
        let clampedRadius = max(config.minDistance, pose.radius)
        let mappedZoom = zoomForRadius(clampedRadius)
        let desiredHeight = lerp(config.minHeight, config.maxHeight, mappedZoom)
        let cameraY = max(tableSurfaceY + config.minHeightAboveTable, tableSurfaceY + desiredHeight)

        let forwardXZ = SCNVector3(-cosf(pose.yaw), 0, -sinf(pose.yaw))
        let position = SCNVector3(
            pose.pivot.x - forwardXZ.x * clampedRadius,
            cameraY,
            pose.pivot.z - forwardXZ.z * clampedRadius
        )
        let lookDir = (pose.pivot - position).normalized()
        let yawEuler = atan2f(-lookDir.x, -lookDir.z)

        cameraNode.position = position
        cameraNode.eulerAngles = SCNVector3(pose.pitch, yawEuler, 0)
        cameraNode.eulerAngles.z = 0
        cameraNode.camera?.fieldOfView = pose.fov
    }

    private func applyCameraTransform() {
        let clampedZoom = clampZoom(currentZoom)
        let radius = max(config.minDistance, lerp(config.minRadius, config.maxRadius, clampedZoom))
        let desiredHeight = lerp(config.minHeight, config.maxHeight, clampedZoom)
        let cameraY = max(tableSurfaceY + config.minHeightAboveTable, tableSurfaceY + desiredHeight)

        let easedZoom = clampedZoom * clampedZoom
        var pitch = lerp(config.aimPitchRad, config.standPitchRad, easedZoom)
        pitch = max(config.minPitchRad, min(config.maxPitchRad, pitch))

        let forwardXZ = SCNVector3(-cosf(currentYaw), 0, -sinf(currentYaw))
        let position = SCNVector3(
            currentPivot.x - forwardXZ.x * radius,
            cameraY,
            currentPivot.z - forwardXZ.z * radius
        )
        let lookDir = (currentPivot - position).normalized()
        let yawEuler = atan2f(-lookDir.x, -lookDir.z)

        cameraNode.position = position
        cameraNode.eulerAngles = SCNVector3(pitch, yawEuler, 0)
        cameraNode.eulerAngles.z = 0
        let interpolatedFov = CGFloat(lerp(Float(config.aimFov), Float(config.standFov), clampedZoom))
        cameraNode.camera?.fieldOfView = interpolatedFov
    }

    private func clampZoom(_ zoom: Float) -> Float {
        max(TrainingCameraConfig.minZoom, min(TrainingCameraConfig.maxZoom, zoom))
    }

    private func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
        a + (b - a) * max(0, min(1, t))
    }

    private func shortestAngleDelta(from: Float, to: Float) -> Float {
        var delta = to - from
        while delta > .pi { delta -= 2 * .pi }
        while delta < -.pi { delta += 2 * .pi }
        return delta
    }
}
