//
//  ViewTransitionController.swift
//  BilliardTrainer
//
//  视角过渡控制器：上/下滑第一人称<->第三人称连续过渡
//  上滑 = zoom 增大（俯身 -> 站起），下滑 = zoom 减小（站起 -> 俯身）
//

import SceneKit

final class ViewTransitionController {

    private let cameraRig: CameraRig

    init(cameraRig: CameraRig) {
        self.cameraRig = cameraRig
    }

    // MARK: - Vertical Swipe

    /// 处理垂直滑动：改变 zoom（姿态参数）
    /// delta > 0 表示上滑（站起），delta < 0 表示下滑（俯身）
    func handleVerticalSwipe(delta: Float) {
        cameraRig.handleVerticalSwipe(delta: delta)
    }

    // MARK: - Zoom Memory

    /// 保存当前 zoom 值为用户偏好（Adjusting 结束时调用）
    func saveCurrentZoom() -> Float {
        cameraRig.zoom
    }

    /// 恢复到指定 zoom 值
    func restoreZoom(_ zoom: Float, animated: Bool) {
        cameraRig.returnToAim(zoom: zoom, animated: animated)
    }

    /// 当前 zoom 值
    var currentZoom: Float {
        cameraRig.zoom
    }
}
