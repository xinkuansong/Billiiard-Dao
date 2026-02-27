//
//  CameraStateMachine.swift
//  BilliardTrainer
//
//  摄像系统状态机：Aiming / Adjusting / Shooting / Observing / ReturnToAim
//

import SceneKit

enum CameraPresentationMode: Equatable {
    case aim3D
    case observe3D
    case topDown2D
}

enum CameraPhase: Equatable {
    case ballPlacement
    case aiming
    case shotRunning
    case postShot
}

enum CameraInteractionState: Equatable {
    case none
    case draggingCueBall
    case draggingTargetBall
    case rotatingCamera
}

enum PivotAnchor {
    case cueBall
    case tableCenter
    case fixedPoint(SCNVector3)
    case selectedBall(String)
}

struct TransitionState: Equatable {
    var isActive: Bool
    var locksCameraInput: Bool
}

/// CameraPose 统一定义：
/// - yaw: 世界 Y 轴弧度
/// - pitch: yawNode 局部 X 轴弧度
/// - radius: pivot 到 camera 的轨道距离（沿 rig -Z）
/// - pivot: 世界坐标
struct CameraPose {
    var yaw: Float
    var pitch: Float
    var radius: Float
    var pivot: SCNVector3
}

struct CameraContext {
    var mode: CameraPresentationMode
    var phase: CameraPhase
    var interaction: CameraInteractionState
    var selectedBallId: String?
    var pivotFollowLocked: Bool
    var pivotAnchor: PivotAnchor
    var shotAnchorPose: CameraPose?
    var transition: TransitionState?
    var savedAimPose: CameraPose
    var observeTargetBallId: String?
    var observeTargetBallPosition: SCNVector3?
    var observePocketId: String?
    var observePocketPosition: SCNVector3?

    static let `default` = CameraContext(
        mode: .aim3D,
        phase: .aiming,
        interaction: .none,
        selectedBallId: nil,
        pivotFollowLocked: false,
        pivotAnchor: .cueBall,
        shotAnchorPose: nil,
        transition: nil,
        savedAimPose: CameraPose(
            yaw: .pi,
            pitch: TrainingCameraConfig.aimPitchRad,
            radius: TrainingCameraConfig.aimRadius,
            pivot: SCNVector3(0, TablePhysics.height, 0)
        ),
        observeTargetBallId: nil,
        observeTargetBallPosition: nil,
        observePocketId: nil,
        observePocketPosition: nil
    )
}

enum CameraIntent: Equatable {
    case none
    case dragCueBall
    case selectTarget(String)
    case rotateYaw(Float)
    case rotateYawPitch(deltaX: Float, deltaY: Float)
    case panTopDown(deltaX: Float, deltaY: Float)
    case zoom(Float)
}

struct PanGestureInput {
    var deltaX: Float
    var deltaY: Float
}

struct HitResult {
    var isUI: Bool
    var isBall: Bool
    var isCueBall: Bool
    var isTargetBall: Bool
    var ballId: String?

    static let none = HitResult(isUI: false, isBall: false, isCueBall: false, isTargetBall: false, ballId: nil)
}

struct InputRouter {
    func routeTap(hit: HitResult, context: CameraContext) -> CameraIntent {
        if context.transition?.isActive == true, context.transition?.locksCameraInput == true {
            return .none
        }
        if hit.isUI { return .none }
        if hit.isBall,
           context.phase == .aiming,
           hit.isTargetBall,
           let ballId = hit.ballId {
            return .selectTarget(ballId)
        }
        return .none
    }

    func routePan(startHit: HitResult, input: PanGestureInput, context: CameraContext) -> CameraIntent {
        if context.transition?.isActive == true, context.transition?.locksCameraInput == true {
            return .none
        }
        if startHit.isUI { return .none }
        if startHit.isBall, context.phase == .ballPlacement, startHit.isCueBall {
            return .dragCueBall
        }
        if startHit.isBall {
            return .none
        }

        switch context.mode {
        case .aim3D:
            guard context.phase == .aiming || context.phase == .ballPlacement else { return .none }
            return .rotateYaw(input.deltaX)
        case .observe3D:
            return .rotateYawPitch(deltaX: input.deltaX, deltaY: input.deltaY)
        case .topDown2D:
            return .panTopDown(deltaX: input.deltaX, deltaY: input.deltaY)
        }
    }

    func routePinch(scale: Float, context: CameraContext) -> CameraIntent {
        if context.transition?.isActive == true, context.transition?.locksCameraInput == true {
            return .none
        }
        return .zoom(scale)
    }
}

// MARK: - Camera State

enum CameraState: Equatable, CustomStringConvertible {
    case aiming
    case adjusting
    case shooting
    case observing
    case returnToAim

    var description: String {
        switch self {
        case .aiming:      return "Aiming"
        case .adjusting:   return "Adjusting"
        case .shooting:    return "Shooting"
        case .observing:   return "Observing"
        case .returnToAim: return "ReturnToAim"
        }
    }
}

// MARK: - Camera Events

enum CameraEvent {
    case verticalSwipeBegan
    case verticalSwipeEnded
    case shotFired
    case ballsStartedMoving
    case ballsStopped
    case targetSelected
    case returnAnimationCompleted
}

// MARK: - Camera State Machine

final class CameraStateMachine {

    private(set) var currentState: CameraState = .aiming

    /// 击球前保存的瞄准方向，用于 autoAlign=false 时恢复
    private(set) var savedAimDirection: SCNVector3 = SCNVector3(-1, 0, 0)

    /// 击球前保存的 zoom 值
    private(set) var savedAimZoom: Float = 0

    /// ReturnToAim 动画进度 (0~1)
    private(set) var returnProgress: Float = 0

    /// 回归目标完成标记
    var onStateChanged: ((CameraState, CameraState) -> Void)?

    // MARK: - Transition

    @discardableResult
    func handleEvent(_ event: CameraEvent) -> Bool {
        let oldState = currentState
        let newState = nextState(for: event)
        guard newState != oldState else { return false }

        currentState = newState

        if newState == .returnToAim {
            returnProgress = 0
        }

        onStateChanged?(oldState, newState)
        return true
    }

    /// 保存瞄准状态的上下文（在 Shooting 前调用）
    func saveAimContext(aimDirection: SCNVector3, zoom: Float) {
        savedAimDirection = aimDirection
        savedAimZoom = zoom
    }

    /// 更新 ReturnToAim 进度
    func updateReturnProgress(deltaTime: Float) {
        guard currentState == .returnToAim else { return }
        let duration = TrainingCameraConfig.returnToAimDuration
        returnProgress += deltaTime / max(0.01, duration)
        if returnProgress >= 1.0 {
            returnProgress = 1.0
            handleEvent(.returnAnimationCompleted)
        }
    }

    /// 强制设置状态（用于初始化或重置）
    func forceState(_ state: CameraState) {
        let old = currentState
        currentState = state
        if state != old {
            onStateChanged?(old, state)
        }
    }

    // MARK: - Transition Table

    private func nextState(for event: CameraEvent) -> CameraState {
        switch (currentState, event) {
        // Aiming
        case (.aiming, .verticalSwipeBegan):       return .adjusting
        case (.aiming, .shotFired):                 return .shooting

        // Adjusting
        case (.adjusting, .verticalSwipeEnded):     return .aiming

        // Shooting
        case (.shooting, .ballsStartedMoving):      return .observing

        // Observing
        case (.observing, .ballsStopped):            return .observing
        case (.observing, .targetSelected):          return .returnToAim

        // ReturnToAim
        case (.returnToAim, .returnAnimationCompleted): return .aiming

        default:
            return currentState
        }
    }
}
