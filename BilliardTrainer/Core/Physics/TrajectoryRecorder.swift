//
//  TrajectoryRecorder.swift
//  BilliardTrainer
//
//  轨迹记录与回放
//

import SceneKit

struct BallFrame {
    let time: Float
    let position: SCNVector3
    let velocity: SCNVector3
    let angularVelocity: SCNVector4
    let state: BallMotionState
}

final class TrajectoryRecorder {
    private(set) var framesByBallName: [String: [BallFrame]] = [:]
    private(set) var duration: Float = 0
    
    func recordFrame(ballName: String, frame: BallFrame) {
        var list = framesByBallName[ballName] ?? []
        list.append(frame)
        framesByBallName[ballName] = list
        duration = max(duration, frame.time)
    }
    
    func stateAt(ballName: String, time: Float) -> BallFrame? {
        guard let frames = framesByBallName[ballName], !frames.isEmpty else { return nil }
        // 简单线性查找，可后续优化为二分
        var last: BallFrame = frames[0]
        for frame in frames {
            if frame.time >= time { return frame }
            last = frame
        }
        return last
    }
    
    /// 检查指定球是否在轨迹中被进袋
    func isBallPocketed(_ ballName: String) -> Bool {
        guard let frames = framesByBallName[ballName], let last = frames.last else { return false }
        return last.state == .pocketed
    }
    
    /// 生成 SCNAction 序列回放轨迹
    /// - Parameters:
    ///   - node: 要动画的节点
    ///   - ballName: 球名称
    ///   - speed: 播放速度
    ///   - surfaceY: 台面Y坐标，传入后会强制所有帧的 Y 坐标为此值（防止球飞离台面）
    func action(for node: SCNNode, ballName: String, speed: Float = 1.0, surfaceY: Float? = nil) -> SCNAction? {
        guard let frames = framesByBallName[ballName], frames.count > 1 else { return nil }
        
        var actions: [SCNAction] = []
        for i in 1..<frames.count {
            let prev = frames[i - 1]
            let next = frames[i]
            let dt = max(0.001, (next.time - prev.time) / speed)
            
            // 强制 Y 坐标贴合台面，防止浮点误差累积导致球飞离台面
            var position = next.position
            if let y = surfaceY {
                position.y = y
            }
            
            // 检测进袋：当球状态从非 pocketed 变为 pocketed 时
            if next.state == .pocketed && prev.state != .pocketed {
                // 移动到进袋位置 + 同时淡出
                let move = SCNAction.move(to: position, duration: TimeInterval(dt))
                let fadeOut = SCNAction.fadeOut(duration: min(0.3, TimeInterval(dt)))
                actions.append(SCNAction.group([move, fadeOut]))
                // 进袋后从场景中移除
                actions.append(SCNAction.removeFromParentNode())
                break  // 进袋后不再生成后续帧动作
            }
            
            // 根据位移方向和距离计算滚动旋转
            let displacement = next.position - prev.position
            let distance = displacement.length()
            
            let move = SCNAction.move(to: position, duration: TimeInterval(dt))
            
            if distance > 0.0001 {
                let rotationAngle = distance / BallPhysics.radius
                let moveDir = displacement.normalized()
                // 旋转轴 = Y轴 × 运动方向（球向前滚时绕垂直于运动方向的水平轴旋转）
                let rotationAxis = SCNVector3(0, 1, 0).cross(moveDir).normalized()
                if rotationAxis.length() > 0.001 {
                    let rotate = SCNAction.rotate(by: CGFloat(rotationAngle), around: rotationAxis, duration: TimeInterval(dt))
                    actions.append(SCNAction.group([move, rotate]))
                } else {
                    actions.append(move)
                }
            } else {
                actions.append(move)
            }
        }
        
        return SCNAction.sequence(actions)
    }
}
