//
//  CameraStateMachine.swift
//  BilliardTrainer
//
//  摄像系统状态机：Aiming / Adjusting / Shooting / Observing / ReturnToAim
//

import SceneKit

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
