//
//  BilliardSceneView.swift
//  BilliardTrainer
//
//  SwiftUI + SceneKit 集成视图
//

import SwiftUI
import SceneKit

// MARK: - Billiard Scene View
/// SwiftUI包装的SceneKit视图
struct BilliardSceneView: UIViewRepresentable {
    
    @ObservedObject var viewModel: BilliardSceneViewModel
    
    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        
        // 配置SceneKit视图
        scnView.scene = viewModel.scene
        scnView.allowsCameraControl = false  // 我们自己控制相机
        scnView.showsStatistics = false  // 生产环境关闭统计信息
        scnView.backgroundColor = .clear
        scnView.antialiasingMode = .multisampling4X
        scnView.preferredFramesPerSecond = 60
        
        // 添加手势
        setupGestures(scnView, context: context)
        
        // 设置物理代理
        scnView.scene?.physicsWorld.contactDelegate = context.coordinator
        
        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        // 视图更新时的处理
        uiView.scene = viewModel.scene
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    // MARK: - Gesture Setup
    
    private func setupGestures(_ view: SCNView, context: Context) {
        // 单指拖动 - 瞄准/旋转视角
        let panGesture = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        view.addGestureRecognizer(panGesture)
        
        // 双指捏合 - 缩放
        let pinchGesture = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        view.addGestureRecognizer(pinchGesture)
        
        // 双指平移 - 调整俯仰角
        let twoFingerPan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTwoFingerPan(_:))
        )
        twoFingerPan.minimumNumberOfTouches = 2
        twoFingerPan.maximumNumberOfTouches = 2
        view.addGestureRecognizer(twoFingerPan)
        
        // 双击 - 切换视角
        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)
        
        // 单击 - 选择/确认
        let singleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleSingleTap(_:))
        )
        singleTap.require(toFail: doubleTap)
        view.addGestureRecognizer(singleTap)
        
        // 长按 - 击球蓄力
        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.3
        view.addGestureRecognizer(longPress)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, SCNPhysicsContactDelegate {
        var viewModel: BilliardSceneViewModel
        
        private var lastPanLocation: CGPoint = .zero
        private var isAiming: Bool = false
        private var strokeStartTime: Date?
        
        init(viewModel: BilliardSceneViewModel) {
            self.viewModel = viewModel
            super.init()
        }
        
        // MARK: - Gesture Handlers
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view as? SCNView else { return }
            
            let location = gesture.location(in: view)
            let translation = gesture.translation(in: view)
            
            switch gesture.state {
            case .began:
                lastPanLocation = location
                
                // 检测是否点击了母球（开始瞄准）
                if viewModel.gameState == .aiming {
                    isAiming = true
                }
                
            case .changed:
                if isAiming {
                    // 瞄准模式：更新瞄准方向
                    viewModel.updateAimDirection(
                        deltaX: Float(translation.x) * 0.002,
                        deltaY: Float(translation.y) * 0.002
                    )
                } else {
                    // 非瞄准模式：旋转相机
                    viewModel.scene.rotateCamera(
                        deltaX: Float(translation.x) * 0.01,
                        deltaY: Float(translation.y) * 0.01
                    )
                }
                
                gesture.setTranslation(.zero, in: view)
                
            case .ended, .cancelled:
                isAiming = false
                
            default:
                break
            }
        }
        
        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard gesture.state == .changed else { return }
            
            viewModel.scene.zoomCamera(scale: Float(gesture.scale))
            gesture.scale = 1.0
        }
        
        @objc func handleTwoFingerPan(_ gesture: UIPanGestureRecognizer) {
            guard gesture.state == .changed else { return }
            
            let translation = gesture.translation(in: gesture.view)
            
            // 调整俯仰角
            viewModel.scene.rotateCamera(
                deltaX: 0,
                deltaY: Float(translation.y) * 0.005
            )
            
            gesture.setTranslation(.zero, in: gesture.view)
        }
        
        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            // 循环切换视角
            viewModel.cycleNextCameraMode()
        }
        
        @objc func handleSingleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? SCNView else { return }
            
            let location = gesture.location(in: view)
            
            // 命中测试
            let hitResults = view.hitTest(location, options: [
                .searchMode: SCNHitTestSearchMode.closest.rawValue
            ])
            
            if let hit = hitResults.first {
                viewModel.handleTap(on: hit.node, at: hit.localCoordinates)
            }
        }
        
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            switch gesture.state {
            case .began:
                // 开始蓄力
                strokeStartTime = Date()
                viewModel.startCharging()
                
            case .ended, .cancelled:
                // 释放击球
                if let startTime = strokeStartTime {
                    let duration = Date().timeIntervalSince(startTime)
                    let power = min(1.0, duration / 2.0)  // 最大2秒蓄力
                    viewModel.executeStroke(power: Float(power))
                }
                strokeStartTime = nil
                
            default:
                break
            }
        }
        
        // MARK: - Physics Contact Delegate
        
        func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
            // 碰撞检测
            let nodeA = contact.nodeA
            let nodeB = contact.nodeB
            
            // 检测是否有球进袋
            if nodeA.name?.starts(with: "pocket") == true || nodeB.name?.starts(with: "pocket") == true {
                let ballNode = nodeA.name?.starts(with: "ball") == true ? nodeA : nodeB
                viewModel.handleBallPocketed(ballNode)
            }
            
            // 球与球碰撞音效
            if (nodeA.name?.starts(with: "ball") == true || nodeA.name == "cueBall") &&
               (nodeB.name?.starts(with: "ball") == true || nodeB.name == "cueBall") {
                let impulse = contact.collisionImpulse
                viewModel.playCollisionSound(impulse: Float(impulse))
            }
            
            // 球与库边碰撞音效
            if nodeA.name?.starts(with: "cushion") == true || nodeB.name?.starts(with: "cushion") == true {
                let impulse = contact.collisionImpulse
                viewModel.playCushionSound(impulse: Float(impulse))
            }
        }
    }
}

// MARK: - Billiard Scene View Model

/// 台球场景视图模型
class BilliardSceneViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var scene: BilliardScene
    @Published var gameState: GameState = .idle
    @Published var currentPower: Float = 0
    @Published var aimDirection: SCNVector3 = SCNVector3(1, 0, 0)
    @Published var selectedCuePoint: CGPoint = CGPoint(x: 0.5, y: 0.5)  // 打点位置 (0-1)
    
    // MARK: - Game State
    
    enum GameState {
        case idle           // 空闲
        case aiming         // 瞄准中
        case charging       // 蓄力中
        case ballsMoving    // 球在运动
        case turnEnd        // 回合结束
    }
    
    // MARK: - Initialization
    
    init() {
        scene = BilliardScene()
    }
    
    // MARK: - Game Setup
    
    /// 设置训练场景
    func setupTrainingScene(type: TrainingType) {
        scene.resetScene()
        
        switch type {
        case .aiming(let difficulty):
            setupAimingTraining(difficulty: difficulty)
        case .spin(let spinType):
            setupSpinTraining(spinType: spinType)
        case .bankShot:
            setupBankShotTraining()
        case .kickShot:
            setupKickShotTraining()
        }
        
        gameState = .aiming
    }
    
    enum TrainingType {
        case aiming(difficulty: Int)
        case spin(SpinType)
        case bankShot
        case kickShot
    }
    
    enum SpinType {
        case center, top, bottom, left, right
    }
    
    /// 设置瞄准训练
    private func setupAimingTraining(difficulty: Int) {
        // 创建母球
        scene.createCueBall()
        
        // 根据难度创建目标球
        let targetPosition: SCNVector3
        switch difficulty {
        case 1:  // 直球
            targetPosition = SCNVector3(0.5, TablePhysics.height + BallPhysics.radius + 0.001, 0)
        case 2:  // 30度
            targetPosition = SCNVector3(0.5, TablePhysics.height + BallPhysics.radius + 0.001, 0.3)
        case 3:  // 45度
            targetPosition = SCNVector3(0.5, TablePhysics.height + BallPhysics.radius + 0.001, 0.5)
        case 4:  // 60度
            targetPosition = SCNVector3(0.5, TablePhysics.height + BallPhysics.radius + 0.001, 0.7)
        default:
            targetPosition = SCNVector3(0.5, TablePhysics.height + BallPhysics.radius + 0.001, 0)
        }
        
        scene.createTargetBall(number: 1, at: targetPosition)
    }
    
    /// 设置杆法训练
    private func setupSpinTraining(spinType: SpinType) {
        scene.createCueBall()
        scene.createTargetBall(
            number: 1,
            at: SCNVector3(0.5, TablePhysics.height + BallPhysics.radius + 0.001, 0)
        )
    }
    
    /// 设置翻袋训练
    private func setupBankShotTraining() {
        scene.createCueBall(at: SCNVector3(-0.5, TablePhysics.height + BallPhysics.radius + 0.001, 0))
        scene.createTargetBall(
            number: 1,
            at: SCNVector3(0.3, TablePhysics.height + BallPhysics.radius + 0.001, 0.4)
        )
    }
    
    /// 设置K球训练
    private func setupKickShotTraining() {
        scene.createCueBall(at: SCNVector3(-0.5, TablePhysics.height + BallPhysics.radius + 0.001, -0.2))
        scene.createTargetBall(
            number: 1,
            at: SCNVector3(0.5, TablePhysics.height + BallPhysics.radius + 0.001, 0.3)
        )
    }
    
    // MARK: - Aiming
    
    /// 更新瞄准方向
    func updateAimDirection(deltaX: Float, deltaY: Float) {
        guard gameState == .aiming else { return }
        
        // 在XZ平面上旋转瞄准方向
        let angle = atan2(aimDirection.z, aimDirection.x) + deltaX
        aimDirection = SCNVector3(cos(angle), 0, sin(angle))
        
        // 更新瞄准线显示
        if let cueBall = scene.cueBallNode {
            scene.showAimLine(
                from: cueBall.position,
                direction: aimDirection,
                length: AimingSystem.maxAimLineLength
            )
        }
    }
    
    /// 设置打点
    func setCuePoint(_ point: CGPoint) {
        selectedCuePoint = point
    }
    
    // MARK: - Stroke
    
    /// 开始蓄力
    func startCharging() {
        guard gameState == .aiming else { return }
        gameState = .charging
        currentPower = 0
    }
    
    /// 执行击球
    func executeStroke(power: Float) {
        guard gameState == .charging, let cueBall = scene.cueBallNode else { return }
        
        // 计算击球速度
        let velocity = StrokePhysics.minVelocity +
            (StrokePhysics.maxVelocity - StrokePhysics.minVelocity) * power
        
        // 计算旋转（基于打点）
        let spin = calculateSpin(from: selectedCuePoint, power: power)
        
        // 应用力
        let force = aimDirection * velocity * BallPhysics.mass
        cueBall.physicsBody?.applyForce(force, asImpulse: true)
        
        // 应用旋转
        cueBall.physicsBody?.applyTorque(spin, asImpulse: true)
        
        // 隐藏瞄准线
        scene.hideAimLine()
        
        // 更新状态
        gameState = .ballsMoving
        
        // 播放击球音效
        playStrokeSound(power: power)
    }
    
    /// 计算旋转
    private func calculateSpin(from cuePoint: CGPoint, power: Float) -> SCNVector4 {
        let offsetX = Float(cuePoint.x - 0.5) * 2  // -1 to 1
        let offsetY = Float(cuePoint.y - 0.5) * 2  // -1 to 1
        
        // 上下打点 -> 前后旋转
        let topSpin = -offsetY * SpinPhysics.maxTopSpin * power
        
        // 左右打点 -> 侧旋
        let sideSpin = offsetX * SpinPhysics.maxSideSpin * power
        
        return SCNVector4(topSpin, sideSpin, 0, 1)
    }
    
    // MARK: - Camera
    
    /// 切换到下一个相机视角
    func cycleNextCameraMode() {
        let modes: [BilliardScene.CameraMode] = [.topDown2D, .perspective3D, .shooting, .free]
        
        if let currentIndex = modes.firstIndex(of: scene.currentCameraMode) {
            let nextIndex = (currentIndex + 1) % modes.count
            scene.setCameraMode(modes[nextIndex])
        }
    }
    
    // MARK: - Event Handlers
    
    /// 处理点击事件
    func handleTap(on node: SCNNode, at localCoordinates: SCNVector3) {
        if node.name == "cueBall" && gameState == .idle {
            // 点击母球，进入瞄准模式
            gameState = .aiming
        }
    }
    
    /// 处理球进袋
    func handleBallPocketed(_ ballNode: SCNNode) {
        // 播放进袋音效
        playPocketSound()
        
        // 从场景移除
        ballNode.removeFromParentNode()
        
        // 通知上层逻辑
        // TODO: 发送事件通知
    }
    
    // MARK: - Audio

    func playCollisionSound(impulse: Float) {
        AudioManager.shared.playCollision(impulse: impulse)
    }

    func playCushionSound(impulse: Float) {
        AudioManager.shared.playCushion(impulse: impulse)
    }

    func playStrokeSound(power: Float) {
        AudioManager.shared.playStroke(power: power)
    }

    func playPocketSound() {
        AudioManager.shared.playPocket()
    }
}

// MARK: - Preview

#Preview {
    BilliardSceneView(viewModel: BilliardSceneViewModel())
}
