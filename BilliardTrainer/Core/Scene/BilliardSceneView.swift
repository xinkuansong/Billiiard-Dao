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
        scnView.showsStatistics = false
        scnView.backgroundColor = .clear
        scnView.antialiasingMode = .multisampling4X
        scnView.preferredFramesPerSecond = 60
        scnView.isPlaying = true
        scnView.pointOfView = viewModel.scene.cameraNode
        
        // 添加手势
        setupGestures(scnView, context: context)
        
        // 启动渲染循环（更新第一人称相机和球杆）
        context.coordinator.startRenderLoop(for: scnView)
        
        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        // 确保 pointOfView 始终指向我们的相机（避免 SwiftUI 重绘时丢失）
        if uiView.pointOfView !== viewModel.scene.cameraNode {
            uiView.pointOfView = viewModel.scene.cameraNode
        }
    }
    
    static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        // 视图被移除时停止渲染循环，打破 CADisplayLink → Coordinator 的循环引用
        coordinator.stopRenderLoop()
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
    
    class Coordinator: NSObject {
        var viewModel: BilliardSceneViewModel
        
        private var lastPanLocation: CGPoint = .zero
        private var strokeStartTime: Date?
        private var chargeTimer: Timer?
        
        /// 渲染循环回调（用于更新第一人称相机和球杆）
        private var displayLink: CADisplayLink?
        private weak var scnView: SCNView?
        
        init(viewModel: BilliardSceneViewModel) {
            self.viewModel = viewModel
            super.init()
        }
        
        deinit {
            stopRenderLoop()
        }
        
        /// 启动渲染循环更新
        func startRenderLoop(for view: SCNView) {
            scnView = view
            displayLink = CADisplayLink(target: self, selector: #selector(renderUpdate))
            displayLink?.add(to: .main, forMode: .common)
        }
        
        /// 停止渲染循环（释放 CADisplayLink 防止循环引用）
        func stopRenderLoop() {
            displayLink?.invalidate()
            displayLink = nil
        }
        
        @objc private func renderUpdate() {
            guard let cueBall = viewModel.scene.cueBallNode else { return }
            
            // 更新第一人称相机
            if viewModel.scene.currentCameraMode == .firstPerson {
                viewModel.scene.updateFirstPersonCamera(
                    cueBallPosition: cueBall.position,
                    aimDirection: viewModel.aimDirection,
                    pitchAngle: viewModel.pitchAngle
                )
            }
            
            // 更新球杆位置
            if viewModel.gameState == .aiming || viewModel.gameState == .charging {
                let pullBack: Float
                if viewModel.gameState == .charging {
                    pullBack = viewModel.currentPower * CueStickSettings.maxPullBack
                } else {
                    pullBack = 0
                }
                viewModel.cueStick?.update(
                    cueBallPosition: cueBall.position,
                    aimDirection: viewModel.aimDirection,
                    pullBack: pullBack
                )
            }
            
            // 更新瞄准线和轨迹预测
            if viewModel.gameState == .aiming {
                viewModel.scene.showAimLine(
                    from: cueBall.position,
                    direction: viewModel.aimDirection,
                    length: AimingSystem.maxAimLineLength
                )
                viewModel.updateTrajectoryPreview()
            }
        }
        
        // MARK: - Gesture Handlers
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view as? SCNView else { return }
            let translation = gesture.translation(in: view)
            
            switch viewModel.gameState {
            case .placing:
                // 母球摆放：拖动母球
                if gesture.state == .changed {
                    handlePlacingPan(translation: translation, in: view)
                }
                
            case .aiming:
                // 瞄准模式：左右旋转瞄准方向，上下调俯仰
                if gesture.state == .changed {
                    let sensitivity = FirstPersonCamera.aimSensitivity
                    
                    // 左右 = 旋转瞄准方向
                    viewModel.updateAimDirection(
                        deltaX: Float(translation.x) * sensitivity,
                        deltaY: 0
                    )
                    
                    // 上下 = 调整俯仰角（不影响瞄准方向）
                    let pitchDelta = Float(translation.y) * sensitivity * 0.5
                    viewModel.pitchAngle = max(
                        FirstPersonCamera.minPitch,
                        min(FirstPersonCamera.maxPitch,
                            viewModel.pitchAngle + pitchDelta)
                    )
                }
                
            case .ballsMoving, .turnEnd, .idle:
                // 自由旋转相机观察
                if gesture.state == .changed {
                    viewModel.scene.rotateCamera(
                        deltaX: Float(translation.x) * 0.01,
                        deltaY: Float(translation.y) * 0.01
                    )
                }
                
            case .charging:
                break
            }
            
            gesture.setTranslation(.zero, in: view)
        }
        
        /// 处理母球摆放拖动
        private func handlePlacingPan(translation: CGPoint, in view: SCNView) {
            guard let cueBall = viewModel.scene.cueBallNode else { return }
            
            let sensitivity: Float = 0.003
            var newPos = cueBall.position
            newPos.x += Float(translation.x) * sensitivity
            newPos.z += Float(translation.y) * sensitivity
            
            // 限制在开球区内（球台左半边）
            let halfLength = TablePhysics.innerLength / 2
            let halfWidth = TablePhysics.innerWidth / 2
            let ballR = BallPhysics.radius
            
            newPos.x = max(-halfLength + ballR, min(0, newPos.x))  // 左半区
            newPos.z = max(-halfWidth + ballR, min(halfWidth - ballR, newPos.z))
            
            cueBall.position = newPos
        }
        
        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard gesture.state == .changed else { return }
            viewModel.scene.zoomCamera(scale: Float(gesture.scale))
            gesture.scale = 1.0
        }
        
        @objc func handleTwoFingerPan(_ gesture: UIPanGestureRecognizer) {
            guard gesture.state == .changed else { return }
            let translation = gesture.translation(in: gesture.view)
            
            if viewModel.gameState == .aiming {
                // 精细瞄准模式：灵敏度降低 5 倍
                let sensitivity = FirstPersonCamera.fineSensitivity
                viewModel.updateAimDirection(
                    deltaX: Float(translation.x) * sensitivity,
                    deltaY: 0
                )
            } else {
                viewModel.scene.rotateCamera(
                    deltaX: 0,
                    deltaY: Float(translation.y) * 0.005
                )
            }
            
            gesture.setTranslation(.zero, in: gesture.view)
        }
        
        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            // 循环切换视角
            viewModel.cycleNextCameraMode()
        }
        
        @objc func handleSingleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? SCNView else { return }
            let location = gesture.location(in: view)
            
            // 母球摆放模式：点击确认放置
            if viewModel.gameState == .placing {
                viewModel.confirmCueBallPlacement()
                return
            }
            
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
                guard viewModel.gameState == .aiming else { return }
                strokeStartTime = Date()
                viewModel.startCharging()
                
                // 启动蓄力计时器，持续更新力度
                chargeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
                    guard let self = self, let startTime = self.strokeStartTime else { return }
                    let duration = Date().timeIntervalSince(startTime)
                    let power = min(1.0, duration / 2.0)
                    self.viewModel.currentPower = Float(power)
                }
                
            case .ended, .cancelled:
                // 释放击球
                chargeTimer?.invalidate()
                chargeTimer = nil
                
                if let startTime = strokeStartTime, viewModel.gameState == .charging {
                    let duration = Date().timeIntervalSince(startTime)
                    let power = min(1.0, duration / 2.0)
                    viewModel.executeStroke(power: Float(power))
                }
                strokeStartTime = nil
                
            default:
                break
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
    @Published var isTopDownView: Bool = false  // 2D/3D 视角切换
    @Published var lastFouls: [Foul] = []
    @Published var lastShotLegal: Bool = true
    
    // MARK: - Event Callbacks
    
    /// 目标球进袋回调 (ballName, pocketId)
    var onTargetBallPocketed: ((String, String) -> Void)?
    
    /// 母球进袋回调
    var onCueBallPocketed: (() -> Void)?
    
    /// 击球完成回调 (isLegal, fouls)
    var onShotCompleted: ((Bool, [Foul]) -> Void)?
    
    // MARK: - Physics Engine (Event-Driven)
    
    /// 球杆
    private(set) var cueStick: CueStick?
    
    /// 第一人称俯仰角
    var pitchAngle: Float = FirstPersonCamera.defaultPitch
    
    /// 当前击球事件记录
    private var shotEvents: [GameEvent] = []
    
    /// 当前击球时间（用于播放中跟踪）
    private(set) var currentShotTime: Float = 0
    
    /// 最近一次轨迹记录
    private(set) var lastShotRecorder: TrajectoryRecorder?
    
    /// 规则分组（默认 open）
    private var currentGroup: BallGroup = .open
    
    /// 播放中的球动作计数器
    private var playbackRemainingCount: Int = 0

    /// 推进当前击球时间
    func advanceShotTime(delta: Float) {
        currentShotTime += delta
    }
    
    // MARK: - Game State
    
    enum GameState {
        case idle           // 空闲
        case placing        // 母球摆放
        case aiming         // 瞄准中
        case charging       // 蓄力中
        case ballsMoving    // 球在运动
        case turnEnd        // 回合结束
    }
    
    // MARK: - Initialization
    
    init() {
        print("[BilliardSceneViewModel] 🏗️ init 开始...")
        scene = BilliardScene()
        print("[BilliardSceneViewModel] ✅ init 完成")
    }
    
    /// 所有球停止运动后的处理（由 SCNAction 播放完成触发）
    private func onBallsAtRest() {
        guard gameState == .ballsMoving else { return }
        
        // 规则判定
        let result = EightBallRules.isLegalShot(events: shotEvents, currentGroup: currentGroup)
        lastShotLegal = result.legal
        lastFouls = result.fouls
        
        // 触发事件回调：通知训练层每个进袋事件
        for event in shotEvents {
            switch event {
            case .ballPocketed(let ball, let pocket, _):
                onTargetBallPocketed?(ball, pocket)
            case .cueBallPocketed:
                onCueBallPocketed?()
            default:
                break
            }
        }
        
        // 触发击球完成回调
        onShotCompleted?(result.legal, result.fouls)
        
        // 先进入回合结束状态
        gameState = .turnEnd
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Game Setup
    
    /// 设置训练场景
    func setupTrainingScene(type: TrainingType) {
        print("[BilliardSceneViewModel] 🎱 setupTrainingScene 开始 type=\(type)")
        // 清除事件
        shotEvents.removeAll()
        scene.hideGhostBall()
        
        // 重置球位置（球来自 USDZ 模型，resetScene 恢复初始位置）
        scene.resetScene()
        
        // 球已在模型中就位，无需程序化创建
        
        // 重置瞄准方向
        aimDirection = SCNVector3(1, 0, 0)
        pitchAngle = FirstPersonCamera.defaultPitch
        currentPower = 0
        
        // 设置球杆
        setupCueStick()
        
        // 切换到第一人称视角
        if !isTopDownView {
            scene.setCameraMode(.firstPerson, animated: false)
            // 立即更新相机到正确位置（不使用平滑插值）
            if let cueBall = scene.cueBallNode {
                scene.updateFirstPersonCamera(
                    cueBallPosition: cueBall.position,
                    aimDirection: aimDirection,
                    pitchAngle: pitchAngle,
                    smooth: false
                )
            }
        }
        
        gameState = .aiming
        print("[BilliardSceneViewModel] ✅ setupTrainingScene 完成")
    }
    
    /// 初始化球杆
    private func setupCueStick() {
        // 移除旧球杆
        cueStick?.rootNode.removeFromParentNode()
        
        // 优先使用 USDZ 模型球杆，否则使用程序化球杆
        if let modelCueNode = scene.modelCueStickNode {
            cueStick = CueStick(modelCueStickNode: modelCueNode)
            print("[ViewModel] 使用 USDZ 模型球杆")
        } else {
            cueStick = CueStick()
            print("[ViewModel] 使用程序化球杆（USDZ 球杆不可用）")
        }
        scene.rootNode.addChildNode(cueStick!.rootNode)
        
        // 更新球杆位置
        if let cueBall = scene.cueBallNode {
            cueStick?.update(
                cueBallPosition: cueBall.position,
                aimDirection: aimDirection,
                pullBack: 0
            )
        }
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
    
    // NOTE: 训练专用球创建方法已移除
    // 所有球来自 USDZ 模型，位置在模型中预设，白球在 setupModelBalls 中移到置球点
    // 如需特殊训练场景（只保留特定球），可在此添加逻辑隐藏不需要的球
    
    // MARK: - Ball Name Helpers
    
    /// 判断节点名是否为目标球（非母球）
    /// 兼容程序化球 "ball_N" 和 USDZ 模型球 "_N"
    func isTargetBallName(_ name: String) -> Bool {
        if name.starts(with: "ball_") { return true }
        // USDZ 模型球：_1, _2, ..., _15（不含 _0，_0 已改名为 cueBall）
        if name.starts(with: "_"), let num = Int(name.dropFirst()), (1...15).contains(num) { return true }
        return false
    }
    
    // MARK: - Next Shot
    
    /// 准备下一次击球（从当前球局继续，不重置所有球）
    func prepareNextShot() {
        shotEvents.removeAll()
        currentPower = 0
        
        scene.hideAimLine()
        scene.hideGhostBall()
        scene.hidePredictedTrajectory()
        
        // 检查母球是否在场
        if scene.cueBallNode == nil || scene.cueBallNode?.parent == nil {
            // 母球落袋 -> 重新创建母球，进入摆放状态
            scene.createCueBall()
            gameState = .placing
        } else {
            // 正常 -> 直接进入瞄准状态
            gameState = .aiming
        }
        
        // 重置瞄准方向
        aimDirection = SCNVector3(1, 0, 0)
        pitchAngle = FirstPersonCamera.defaultPitch
        
        // 恢复球杆
        setupCueStick()
        
        // 恢复相机
        if !isTopDownView {
            scene.setCameraMode(.firstPerson, animated: true)
            if let cueBall = scene.cueBallNode {
                scene.updateFirstPersonCamera(
                    cueBallPosition: cueBall.position,
                    aimDirection: aimDirection,
                    pitchAngle: pitchAngle,
                    smooth: false
                )
            }
        }
    }
    
    // MARK: - Aiming
    
    /// 更新瞄准方向
    func updateAimDirection(deltaX: Float, deltaY: Float) {
        guard gameState == .aiming else { return }
        
        // 在XZ平面上旋转瞄准方向
        let angle = atan2(aimDirection.z, aimDirection.x) + deltaX
        aimDirection = SCNVector3(cos(angle), 0, sin(angle))
        
        // 瞄准线和球杆位置由渲染循环（renderUpdate）持续更新
        // 更新轨迹预测
        updateTrajectoryPreview()
    }
    
    /// 更新瞄准轨迹预测（几何计算，不使用物理引擎）
    func updateTrajectoryPreview() {
        guard gameState == .aiming, let cueBall = scene.cueBallNode else {
            scene.hidePredictedTrajectory()
            return
        }
        
        let cueBallPos = cueBall.position
        let R = BallPhysics.radius
        let surfaceY = cueBallPos.y
        
        // 1. 沿瞄准方向射线检测第一个碰到的目标球
        var closestBall: SCNNode? = nil
        var closestDist: Float = Float.greatestFiniteMagnitude
        
        for ball in scene.targetBallNodes {
            guard ball.parent != nil else { continue }
            let toBall = ball.position - cueBallPos
            // 投影到瞄准方向
            let projection = toBall.dot(aimDirection)
            guard projection > 0 else { continue }  // 球在母球前方
            
            // 最近点距离
            let closest = cueBallPos + aimDirection * projection
            let perpDist = (ball.position - closest).length()
            
            // 碰撞条件：垂直距离 < 2R
            if perpDist < R * 2 {
                // 精确碰撞点：母球中心到目标球中心距离 = 2R 时的投影距离
                let halfChord = sqrtf(max(0, (R * 2) * (R * 2) - perpDist * perpDist))
                let hitDist = projection - halfChord
                if hitDist > 0.01 && hitDist < closestDist {
                    closestDist = hitDist
                    closestBall = ball
                }
            }
        }
        
        guard let targetBall = closestBall else {
            scene.hidePredictedTrajectory()
            return
        }
        
        // 2. 计算碰撞点处母球位置
        let collisionCueBallPos = SCNVector3(
            cueBallPos.x + aimDirection.x * closestDist,
            surfaceY,
            cueBallPos.z + aimDirection.z * closestDist
        )
        
        // 3. 计算碰后目标球方向（沿碰撞法线方向）
        let targetPos = targetBall.position
        let collisionNormal = (targetPos - collisionCueBallPos).normalized()
        let targetBallEndPos = SCNVector3(
            targetPos.x + collisionNormal.x * 0.6,
            surfaceY,
            targetPos.z + collisionNormal.z * 0.6
        )
        
        // 4. 计算碰后母球偏转方向（近似90度分离角）
        // 母球偏转方向 = 入射方向 - 法线分量
        let normalComponent = collisionNormal * aimDirection.dot(collisionNormal)
        let tangentComponent = aimDirection - normalComponent
        let tangentLength = tangentComponent.length()
        
        var cueBallPath: [SCNVector3] = []
        if tangentLength > 0.01 {
            let deflectionDir = tangentComponent.normalized()
            let cueBallEndPos = SCNVector3(
                collisionCueBallPos.x + deflectionDir.x * 0.5,
                surfaceY,
                collisionCueBallPos.z + deflectionDir.z * 0.5
            )
            cueBallPath = [collisionCueBallPos, cueBallEndPos]
        }
        
        // 5. 绘制预测轨迹
        let targetBallPath = [targetPos, targetBallEndPos]
        scene.showPredictedTrajectory(cueBallPath: cueBallPath, targetBallPath: targetBallPath)
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
    
    /// 执行击球 — 使用 EventDrivenEngine 计算轨迹并用 SCNAction 回放
    func executeStroke(power: Float) {
        guard gameState == .charging, let cueBall = scene.cueBallNode else { return }
        
        shotEvents.removeAll()
        currentShotTime = 0
        
        // 1. 计算击球参数
        let velocity = StrokePhysics.minVelocity +
            (StrokePhysics.maxVelocity - StrokePhysics.minVelocity) * power
        
        let strike = computeCueStrike(velocity: velocity, power: power)
        
        // 2. 隐藏瞄准线、轨迹预测和球杆
        scene.hideAimLine()
        scene.hidePredictedTrajectory()
        scene.hideGhostBall()
        cueStick?.hide()
        
        // 3. 创建 EventDrivenEngine 并收集所有球状态
        let engine = EventDrivenEngine(tableGeometry: scene.tableGeometry)
        
        // 母球 — 设置击球后的速度/角速度
        let cueBallState = BallState(
            position: cueBall.presentation.position,
            velocity: strike.linearVelocity,
            angularVelocity: SCNVector3(strike.angularVelocity.x, strike.angularVelocity.y, strike.angularVelocity.z),
            state: .sliding,
            name: cueBall.name ?? "cueBall"
        )
        engine.setBall(cueBallState)
        
        // 目标球
        for ballNode in scene.targetBallNodes {
            let state = BallState(
                position: ballNode.presentation.position,
                velocity: SCNVector3Zero,
                angularVelocity: SCNVector3Zero,
                state: .stationary,
                name: ballNode.name ?? "ball"
            )
            engine.setBall(state)
        }
        
        // 4. 运行模拟
        engine.simulate(maxTime: 15.0)
        
        // 5. 提取事件记录供规则判定
        extractGameEvents(from: engine)
        
        // 6. 获取轨迹记录器用于回放
        let recorder = engine.getTrajectoryRecorder()
        lastShotRecorder = recorder
        
        // 7. 更新状态
        gameState = .ballsMoving
        
        // 8. 用 SCNAction 回放所有球的轨迹
        playTrajectories(recorder: recorder)
        
        // 9. 击球后切换到观察视角
        if !isTopDownView {
            scene.setCameraPostShot(cueBallPosition: cueBall.position)
        }
        
        // 10. 播放击球音效
        playStrokeSound(power: power)
    }
    
    /// 从 EventDrivenEngine 提取游戏事件
    private func extractGameEvents(from engine: EventDrivenEngine) {
        for eventType in engine.resolvedEvents {
            switch eventType {
            case .ballBall(let a, let b):
                shotEvents.append(.ballBallCollision(ball1: a, ball2: b, time: engine.currentTime))
            case .ballCushion(let ball, _, _):
                shotEvents.append(.ballCushionCollision(ball: ball, time: engine.currentTime))
            case .pocket(let ball, let pocketId):
                if ball == "cueBall" {
                    shotEvents.append(.cueBallPocketed(time: engine.currentTime))
                } else {
                    shotEvents.append(.ballPocketed(ball: ball, pocket: pocketId, time: engine.currentTime))
                }
            case .transition:
                break
            }
        }
    }
    
    /// 使用 SCNAction 播放模拟轨迹
    private func playTrajectories(recorder: TrajectoryRecorder) {
        // 收集需要播放的球节点
        var ballNodes: [SCNNode] = []
        if let cueBall = scene.cueBallNode {
            ballNodes.append(cueBall)
        }
        ballNodes.append(contentsOf: scene.targetBallNodes)
        
        // 台面 Y 坐标（球心高度）
        let surfaceY = TablePhysics.height + BallPhysics.radius
        
        playbackRemainingCount = 0
        
        for ballNode in ballNodes {
            guard let name = ballNode.name else { continue }
            guard let action = recorder.action(for: ballNode, ballName: name, speed: 1.0, surfaceY: surfaceY) else { continue }
            
            playbackRemainingCount += 1
            ballNode.removeAllActions()
            
            // 检查该球是否会进袋（进袋球的 SCNAction 已包含 fadeOut + removeFromParentNode）
            let willBePocketed = recorder.isBallPocketed(name)
            
            // 播放轨迹 + 完成回调
            let sequence = SCNAction.sequence([
                action,
                SCNAction.run { [weak self] _ in
                    DispatchQueue.main.async {
                        if willBePocketed {
                            // 进袋球：隐藏影子，从 targetBallNodes 中清理
                            self?.scene.hideShadow(for: name)
                            self?.scene.removeTargetBall(named: name)
                            // 如果是母球进袋，清空母球引用
                            if name == "cueBall" {
                                self?.scene.clearCueBallReference()
                            }
                        } else {
                            // 非进袋球：确保 Y 坐标正确
                            ballNode.position.y = surfaceY
                        }
                        self?.onBallPlaybackFinished()
                    }
                }
            ])
            ballNode.runAction(sequence)
        }
        
        // 如果没有球需要播放（理论上不会发生），直接结束
        if playbackRemainingCount == 0 {
            onBallsAtRest()
        }
    }
    
    /// 单个球的轨迹播放完成
    private func onBallPlaybackFinished() {
        playbackRemainingCount -= 1
        if playbackRemainingCount <= 0 {
            onBallsAtRest()
        }
    }
    

    /// 计算击球初始速度与旋转（含 squirt）
    private func computeCueStrike(velocity: Float, power: Float) -> (linearVelocity: SCNVector3, angularVelocity: SCNVector4) {
        // Derive spin offsets from selected cue point (same as before)
        let offsetX = Float(selectedCuePoint.x - 0.5) * 2  // -1 to 1
        let offsetY = Float(selectedCuePoint.y - 0.5) * 2  // -1 to 1
        
        let spinX = offsetX  // horizontal spin (left/right english)
        let spinY = offsetY  // vertical spin (top/bottom spin)
        
        // Derive elevation from pitchAngle (clamped to 0-20 degrees)
        // pitchAngle is negative when looking down, so negate for elevation
        let maxElevationDegrees: Float = 20.0
        let maxElevationRadians = maxElevationDegrees * Float.pi / 180.0
        let elevation = max(0, min(maxElevationRadians, -pitchAngle))
        
        // Call CueBallStrike.executeStrike
        let result = CueBallStrike.executeStrike(
            aimDirection: aimDirection,
            velocity: velocity,
            spinX: spinX,
            spinY: spinY,
            elevation: elevation
        )
        
        // Convert angularVelocity from SCNVector3 to SCNVector4 (w=1)
        let angularVelocity = SCNVector4(
            result.angularVelocity.x,
            result.angularVelocity.y,
            result.angularVelocity.z,
            1
        )
        
        return (result.velocity, angularVelocity)
    }
    
    // MARK: - Camera
    
    /// 切换到下一个相机视角
    func cycleNextCameraMode() {
        let modes: [BilliardScene.CameraMode] = [.firstPerson, .topDown2D, .perspective3D, .free]
        
        if let currentIndex = modes.firstIndex(of: scene.currentCameraMode) {
            let nextIndex = (currentIndex + 1) % modes.count
            scene.setCameraMode(modes[nextIndex])
            isTopDownView = modes[nextIndex] == .topDown2D
        }
    }
    
    /// 2D/3D 视角切换
    func toggleViewMode() {
        isTopDownView.toggle()
        if isTopDownView {
            scene.setCameraMode(.topDown2D, animated: true)
            cueStick?.hide()
        } else {
            scene.setCameraMode(.firstPerson, animated: true)
            // 立即将相机定位到正确位置
            if let cueBall = scene.cueBallNode {
                scene.updateFirstPersonCamera(
                    cueBallPosition: cueBall.position,
                    aimDirection: aimDirection,
                    pitchAngle: pitchAngle,
                    smooth: false
                )
            }
            if gameState == .aiming {
                cueStick?.show()
            }
        }
    }
    
    // MARK: - Event Handlers
    
    /// 处理点击事件
    func handleTap(on node: SCNNode, at localCoordinates: SCNVector3) {
        if node.name == "cueBall" && gameState == .idle {
            // 点击母球，进入瞄准模式
            gameState = .aiming
            cueStick?.show()
            if !isTopDownView {
                scene.setCameraMode(.firstPerson, animated: true)
            }
        } else if let name = node.name, isTargetBallName(name), gameState == .aiming {
            guard let cueBall = scene.cueBallNode else { return }
            let target = node.position
            let pockets = scene.pockets()
            let otherBalls = scene.targetBallNodes
                .filter { $0 !== node }
                .map { $0.position }
            let candidates = AimingCalculator.viablePockets(
                cueBall: cueBall.position,
                objectBall: target,
                pockets: pockets,
                otherBalls: otherBalls
            )
            if let bestPocket = AimingCalculator.pickEasiestPot(candidates) {
                let ghost = AimingCalculator.ghostBallCenter(objectBall: target, pocket: bestPocket.center)
                scene.showGhostBall(at: ghost)
                aimDirection = (ghost - cueBall.position).normalized()
            } else {
                scene.hideGhostBall()
            }
        }
    }
    
    /// 确认母球放置
    func confirmCueBallPlacement() {
        guard gameState == .placing else { return }
        gameState = .aiming
        cueStick?.show()
        if !isTopDownView {
            scene.setCameraMode(.firstPerson, animated: true)
        }
    }
    
    /// 记录事件
    func recordEvent(_ event: GameEvent) {
        shotEvents.append(event)
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
    
    // MARK: - Replay
    
    /// 回放上一次击球
    func playLastShotReplay(speed: Float = 0.5) {
        guard let recorder = lastShotRecorder else { return }
        for ball in scene.targetBallNodes + (scene.cueBallNode != nil ? [scene.cueBallNode!] : []) {
            guard let name = ball.name, let action = recorder.action(for: ball, ballName: name, speed: speed) else { continue }
            ball.removeAllActions()
            ball.runAction(action)
        }
    }
}

// MARK: - Preview

#Preview {
    BilliardSceneView(viewModel: BilliardSceneViewModel())
}
