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
        let flags = RenderQualityManager.shared.featureFlags

        scnView.scene = viewModel.scene
        scnView.allowsCameraControl = false
        scnView.showsStatistics = false
        scnView.backgroundColor = .clear
        scnView.antialiasingMode = flags.antialiasingMode
        scnView.preferredFramesPerSecond = min(flags.maxFPS, UIScreen.main.maximumFramesPerSecond)
        scnView.isPlaying = true
        scnView.pointOfView = viewModel.scene.cameraNode

        setupGestures(scnView, context: context)
        context.coordinator.startRenderLoop(for: scnView)

        return scnView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        if uiView.pointOfView !== viewModel.scene.cameraNode {
            uiView.pointOfView = viewModel.scene.cameraNode
        }

        let flags = RenderQualityManager.shared.featureFlags
        if uiView.antialiasingMode != flags.antialiasingMode {
            uiView.antialiasingMode = flags.antialiasingMode
        }
        let targetFPS = min(flags.maxFPS, UIScreen.main.maximumFramesPerSecond)
        if uiView.preferredFramesPerSecond != targetFPS {
            uiView.preferredFramesPerSecond = targetFPS
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
        panGesture.delegate = context.coordinator
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
        
        // 单击 - 选择/确认
        let singleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleSingleTap(_:))
        )
        view.addGestureRecognizer(singleTap)
        
        // 长按手势已移除 — 力度通过右侧滑条控制
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var viewModel: BilliardSceneViewModel
        private let inputRouter = InputRouter()
        
        private var lastPanLocation: CGPoint = .zero
        private var isDraggingCueBall: Bool = false
        private var panStartHit: HitResult = .none
        
        /// HUD 控件所在的屏幕边缘宽度（左侧打点器、右侧力度条）
        private let hudEdgeMargin: CGFloat = 130
        
        /// 渲染循环回调（用于更新第一人称相机和球杆）
        private var displayLink: CADisplayLink?
        private weak var scnView: SCNView?
        private var lastTimestamp: CFTimeInterval?
        private var lastAimLineUpdateTimestamp: CFTimeInterval = 0
        private var lastAppliedRenderTier: RenderTier?
        
        private enum PanAxisLock {
            case undecided
            case horizontal
            case vertical
        }
        private var panAxisLock: PanAxisLock = .undecided

        /// 2D 区域缩放锚点（屏幕坐标）
        private var topDownPinchAnchorScreen: CGPoint?
        
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
            lastAppliedRenderTier = nil
            applyRenderQualityIfNeeded(force: true)
            displayLink = CADisplayLink(target: self, selector: #selector(renderUpdate))
            displayLink?.add(to: .main, forMode: .common)
        }
        
        /// 停止渲染循环（释放 CADisplayLink 防止循环引用）
        func stopRenderLoop() {
            displayLink?.invalidate()
            displayLink = nil
            lastTimestamp = nil
            lastAppliedRenderTier = nil
        }

        private func applyRenderQualityIfNeeded(force: Bool = false) {
            guard let view = scnView else { return }
            let manager = RenderQualityManager.shared
            let tier = manager.currentTier
            guard force || tier != lastAppliedRenderTier else { return }

            let flags = manager.featureFlags
            view.antialiasingMode = flags.antialiasingMode
            view.preferredFramesPerSecond = min(flags.maxFPS, UIScreen.main.maximumFramesPerSecond)
            viewModel.scene.reapplyRenderSettings()
            lastAppliedRenderTier = tier
        }
        
        @objc private func renderUpdate() {
            let now = displayLink?.timestamp ?? CACurrentMediaTime()
            viewModel.syncRenderQualityState()
            
            // 轨迹回放：逐帧驱动球位置（必须在 shadow/camera 更新之前）
            viewModel.updateTrajectoryPlaybackFrame(timestamp: now)
            
            viewModel.scene.updateShadowPositions()
            guard let cueBall = viewModel.scene.cueBallNode else { return }
            let cueCenter = viewModel.scene.visualCenter(of: cueBall)
            let deltaTime: Float
            if let last = lastTimestamp {
                let dt = max(1.0 / 240.0, min(1.0 / 20.0, now - last))
                deltaTime = Float(dt)
                _ = RenderQualityManager.shared.recordFrameTime(dt)
            } else {
                deltaTime = 1.0 / 60.0
            }
            lastTimestamp = now
            applyRenderQualityIfNeeded()

            let isTopDown = viewModel.scene.currentCameraMode == .topDown2D
            let camState = viewModel.scene.cameraStateMachine.currentState

            if isTopDown {
                viewModel.scene.updateTopDownZoom()
            } else {
                if (camState == .aiming || camState == .adjusting) && viewModel.gameState == .aiming {
                    viewModel.scene.setAimDirectionForCamera(viewModel.aimDirection)
                }

                viewModel.scene.updateCameraRig(
                    deltaTime: deltaTime,
                    cueBallPosition: cueCenter
                )

                let shouldForceCenterCueBall = viewModel.shouldForceCueBallScreenCentering(at: now)
                if ((camState == .aiming || camState == .adjusting) && viewModel.gameState == .aiming) || shouldForceCenterCueBall,
                   let view = scnView {
                    viewModel.scene.lockCueBallScreenAnchor(
                        in: view,
                        cueBallWorld: cueCenter,
                        anchorNormalized: CGPoint(x: 0.5, y: 0.5),
                        force: shouldForceCenterCueBall
                    )
                }
            }

            viewModel.pitchAngle = viewModel.scene.cameraNode.eulerAngles.x
            
            // 更新球杆位置（含碰撞检测仰角）— 瞄准/观察视角均显示
            if viewModel.gameState == .aiming && !isTopDown {
                let pullBack = (viewModel.currentPower / 100.0) * CueStickSettings.maxPullBack
                let elevation = CueStick.calculateRequiredElevation(
                    cueBallPosition: cueCenter,
                    aimDirection: viewModel.aimDirection,
                    pullBack: pullBack,
                    ballPositions: viewModel.scene.targetBallPositions()
                )
                viewModel.cueStick?.update(
                    cueBallPosition: cueCenter,
                    aimDirection: viewModel.aimDirection,
                    pullBack: pullBack,
                    elevation: elevation
                )
            }
            
            // 更新瞄准线和轨迹预测（2D 俯视模式下不显示）
            if viewModel.gameState == .aiming && !isTopDown {
                if now - lastAimLineUpdateTimestamp >= (1.0 / 45.0) {
                    let aimLineLen = viewModel.scene.calculateAimLineLength(
                        from: cueCenter,
                        direction: viewModel.aimDirection
                    )
                    viewModel.scene.showAimLine(
                        from: cueCenter,
                        direction: viewModel.aimDirection,
                        length: aimLineLen
                    )
                    lastAimLineUpdateTimestamp = now
                }
                viewModel.updateTrajectoryPreview(minInterval: 1.0 / 30.0)
            }
        }
        
        // MARK: - UIGestureRecognizerDelegate
        
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let view = gestureRecognizer.view,
                  gestureRecognizer is UIPanGestureRecognizer else { return true }
            let loc = gestureRecognizer.location(in: view)
            let w = view.bounds.width
            if viewModel.gameState == .aiming {
                if loc.x > w - hudEdgeMargin || loc.x < hudEdgeMargin {
                    return false
                }
            }
            return true
        }
        
        // MARK: - Gesture Handlers
        
        private func canPlaceCueBallDrag() -> Bool { viewModel.gameState == .placing }
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view as? SCNView else { return }
            let translation = gesture.translation(in: view)
            if gesture.state == .began {
                panAxisLock = .undecided
                panStartHit = hitResult(at: gesture.location(in: view), in: view)
            }

            if gesture.state == .began {
                let beginIntent = inputRouter.routePan(
                    startHit: panStartHit,
                    input: PanGestureInput(deltaX: 0, deltaY: 0),
                    context: viewModel.cameraContext
                )
                if beginIntent == .dragCueBall {
                    isDraggingCueBall = true
                    viewModel.beginCueBallDrag()
                }
            }

            if gesture.state == .changed {
                let intent = inputRouter.routePan(
                    startHit: panStartHit,
                    input: PanGestureInput(deltaX: Float(translation.x), deltaY: Float(translation.y)),
                    context: viewModel.cameraContext
                )
                applyPanIntent(intent, gesture: gesture, view: view)
            }

            if gesture.state == .ended || gesture.state == .cancelled || gesture.state == .failed {
                if isDraggingCueBall {
                    isDraggingCueBall = false
                    viewModel.endCueBallDrag()
                }
                if viewModel.cameraContext.interaction == .rotatingCamera {
                    viewModel.cameraContext.interaction = .none
                }
                panAxisLock = .undecided
                panStartHit = .none
            }
            
            gesture.setTranslation(.zero, in: view)
        }

        private func applyPanIntent(_ intent: CameraIntent, gesture: UIPanGestureRecognizer, view: SCNView) {
            switch intent {
            case .none:
                return
            case .dragCueBall:
                handlePlacingPan(gesture: gesture, in: view)
            case .rotateYaw(let deltaX):
                guard viewModel.gameState == .aiming,
                      let aimCtrl = viewModel.scene.aimingController,
                      let cueBall = viewModel.scene.cueBallNode else { return }
                let cueBallPos = viewModel.scene.visualCenter(of: cueBall)
                let targetPositions = viewModel.scene.targetBallPositions()
                viewModel.aimDirection = aimCtrl.handleHorizontalSwipe(
                    delta: deltaX,
                    currentAimDirection: viewModel.aimDirection,
                    cueBallPos: cueBallPos,
                    targetBalls: targetPositions
                )
                viewModel.updateTrajectoryPreview()
            case .rotateYawPitch(let deltaX, let deltaY):
                viewModel.cameraContext.interaction = .rotatingCamera
                if viewModel.selectedNextTarget != nil,
                   let aimCtrl = viewModel.scene.aimingController,
                   let cueBall = viewModel.scene.cueBallNode {
                    let cueBallPos = viewModel.scene.visualCenter(of: cueBall)
                    let targetPositions = viewModel.scene.targetBallPositions()
                    viewModel.aimDirection = aimCtrl.handleHorizontalSwipe(
                        delta: deltaX,
                        currentAimDirection: viewModel.aimDirection,
                        cueBallPos: cueBallPos,
                        targetBalls: targetPositions
                    )
                    viewModel.scene.setAimDirectionForCamera(viewModel.aimDirection)
                    viewModel.updateTrajectoryPreview()
                    if abs(deltaY) > 0.0001 {
                        viewModel.scene.observationController?.handleObservationPan(deltaX: 0, deltaY: deltaY)
                    }
                } else {
                    viewModel.scene.observationController?.handleObservationPan(deltaX: deltaX, deltaY: deltaY)
                }
            case .panTopDown(let deltaX, let deltaY):
                viewModel.scene.applyCameraPan(deltaX: deltaX, deltaY: deltaY)
            case .zoom, .selectTarget:
                break
            }
        }
        
        /// 处理母球摆放拖动：射线投射到台面平面，直接定位白球
        private func handlePlacingPan(gesture: UIPanGestureRecognizer, in view: SCNView) {
            guard viewModel.scene.cueBallNode != nil else { return }
            let location = gesture.location(in: view)

            let surfaceY = TablePhysics.height + BallPhysics.radius
            guard let worldPos = unprojectToTablePlane(screenPoint: location, in: view, planeY: surfaceY) else { return }

            var newX = worldPos.x
            var newZ = worldPos.z

            let R = BallPhysics.radius
            let halfL = TablePhysics.innerLength / 2
            let halfW = TablePhysics.innerWidth / 2

            // 依据当前相机缩放自适应拖动灵敏度，避免高视角下拖动过猛
            let zoom = viewModel.scene.currentCameraZoom
            let dragScale = max(0.35, min(0.85, 0.35 + zoom * 0.5))
            if let cueBall = viewModel.scene.cueBallNode {
                let cuePos = viewModel.scene.visualCenter(of: cueBall)
                newX = cuePos.x + (newX - cuePos.x) * dragScale
                newZ = cuePos.z + (newZ - cuePos.z) * dragScale
            }

            if viewModel.placingBehindHeadString {
                let headStringX = BilliardScene.headStringX
                newX = max(headStringX, min(halfL - R, newX))
            } else {
                newX = max(-halfL + R, min(halfL - R, newX))
            }
            newZ = max(-halfW + R, min(halfW - R, newZ))

            let targetPos = SCNVector3(newX, surfaceY, newZ)
            viewModel.scene.moveCueBall(to: targetPos)
        }

        /// 将屏幕坐标投射到 y=planeY 的水平平面
        private func unprojectToTablePlane(screenPoint: CGPoint, in view: SCNView, planeY: Float) -> SCNVector3? {
            let nearPoint = view.unprojectPoint(SCNVector3(Float(screenPoint.x), Float(screenPoint.y), 0))
            let farPoint  = view.unprojectPoint(SCNVector3(Float(screenPoint.x), Float(screenPoint.y), 1))
            let dir = farPoint - nearPoint
            guard abs(dir.y) > 1e-6 else { return nil }
            let t = (planeY - nearPoint.y) / dir.y
            guard t > 0 else { return nil }
            return SCNVector3(nearPoint.x + dir.x * t, planeY, nearPoint.z + dir.z * t)
        }
        
        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let view = gesture.view as? SCNView else { return }

            if viewModel.scene.currentCameraMode == .topDown2D {
                switch gesture.state {
                case .began:
                    topDownPinchAnchorScreen = gesture.location(in: view)
                case .changed:
                    let anchor = topDownPinchAnchorScreen ?? gesture.location(in: view)
                    viewModel.scene.applyTopDownAreaZoom(
                        scale: Float(gesture.scale),
                        anchorScreen: anchor,
                        in: view
                    )
                    gesture.scale = 1.0
                default:
                    topDownPinchAnchorScreen = nil
                }
                return
            }

            if gesture.state == .ended || gesture.state == .cancelled || gesture.state == .failed {
                if viewModel.cameraContext.interaction == .rotatingCamera {
                    viewModel.cameraContext.interaction = .none
                }
                return
            }
            guard gesture.state == .changed else { return }
            let intent = inputRouter.routePinch(scale: Float(gesture.scale), context: viewModel.cameraContext)
            if case .zoom(let scale) = intent {
                if viewModel.cameraContext.mode == .observe3D {
                    viewModel.cameraContext.interaction = .rotatingCamera
                    viewModel.scene.observationController?.handleObservationPinch(scale: scale)
                } else {
                    viewModel.scene.applyCameraPinch(scale: scale)
                    if viewModel.gameState == .aiming && viewModel.scene.shouldLinkAimDirectionWithCamera() {
                        viewModel.aimDirection = viewModel.scene.currentAimDirectionFromCamera()
                        viewModel.updateTrajectoryPreview()
                    }
                }
            }
            gesture.scale = 1.0
        }
        
        @objc func handleTwoFingerPan(_ gesture: UIPanGestureRecognizer) {
            guard gesture.state == .changed else { return }
            guard viewModel.cameraContext.mode == .topDown2D else { return }
            if viewModel.cameraContext.transition?.isActive == true,
               viewModel.cameraContext.transition?.locksCameraInput == true {
                return
            }
            let translation = gesture.translation(in: gesture.view)
            viewModel.scene.applyCameraPan(deltaX: Float(translation.x), deltaY: Float(translation.y))
            
            gesture.setTranslation(.zero, in: gesture.view)
        }
        
        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            // 双击切换路径已禁用，避免与按钮交互重复并造成误触跳变
        }
        
        @objc func handleTwoFingerDoubleTap(_ gesture: UITapGestureRecognizer) {
            // 双指双击切换路径已禁用，保留空实现兼容历史入口
        }
        
        @objc func handleSingleTap(_ gesture: UITapGestureRecognizer) {
            guard viewModel.scene.currentCameraMode != .topDown2D else { return }
            guard let view = gesture.view as? SCNView else { return }
            if viewModel.cameraContext.transition?.isActive == true,
               viewModel.cameraContext.transition?.locksCameraInput == true {
                return
            }
            let location = gesture.location(in: view)
            
            if viewModel.gameState == .placing {
                viewModel.confirmCueBallPlacement()
                return
            }
            
            // 先尝试 SceneKit hitTest
            let hitResults = view.hitTest(location, options: [
                .searchMode: SCNHitTestSearchMode.closest.rawValue
            ])
            
            if !hitResults.isEmpty {
                for hit in hitResults {
                    let node = viewModel.findBallAncestor(hit.node) ?? hit.node
                    if node.name == "cueBall" || (node.name != nil && viewModel.isTargetBallName(node.name!)) {
                        let hitResult = makeBallHitResult(node: node)
                        let intent = inputRouter.routeTap(hit: hitResult, context: viewModel.cameraContext)
                        if case .selectTarget = intent {
                            viewModel.handleTap(on: node, at: hit.localCoordinates)
                            return
                        }
                        if hitResult.isCueBall {
                            viewModel.handleTap(on: node, at: hit.localCoordinates)
                        }
                        return
                    }
                }
            }
            
            // 距离兜底：投影到台面找最近的球（包含白球，便于重复摆放）
            let surfaceY = TablePhysics.height + BallPhysics.radius
            guard let worldPos = unprojectToTablePlane(screenPoint: location, in: view, planeY: surfaceY) else { return }
            let threshold: Float = BallPhysics.radius * 4.0
            
            var closestBall: SCNNode? = nil
            var closestDist: Float = threshold
            if let cueBall = viewModel.scene.cueBallNode, cueBall.parent != nil {
                let pos = viewModel.scene.visualCenter(of: cueBall)
                let dx = pos.x - worldPos.x
                let dz = pos.z - worldPos.z
                let dist = sqrtf(dx * dx + dz * dz)
                if dist < closestDist {
                    closestDist = dist
                    closestBall = cueBall
                }
            }
            
            for ball in viewModel.scene.targetBallNodes {
                guard ball.parent != nil else { continue }
                let pos = viewModel.scene.visualCenter(of: ball)
                let dx = pos.x - worldPos.x
                let dz = pos.z - worldPos.z
                let dist = sqrtf(dx * dx + dz * dz)
                if dist < closestDist {
                    closestDist = dist
                    closestBall = ball
                }
            }
            
            if let ball = closestBall {
                let hitResult = makeBallHitResult(node: ball)
                let intent = inputRouter.routeTap(hit: hitResult, context: viewModel.cameraContext)
                if case .selectTarget = intent {
                    viewModel.handleTap(on: ball, at: SCNVector3Zero)
                    return
                }
                if hitResult.isCueBall {
                    viewModel.handleTap(on: ball, at: SCNVector3Zero)
                }
            }
        }

        private func hitResult(at point: CGPoint, in view: SCNView) -> HitResult {
            let hitResults = view.hitTest(point, options: [.searchMode: SCNHitTestSearchMode.closest.rawValue])
            guard let first = hitResults.first else { return .none }
            let node = viewModel.findBallAncestor(first.node) ?? first.node
            return makeBallHitResult(node: node)
        }

        private func makeBallHitResult(node: SCNNode) -> HitResult {
            guard let name = node.name else { return .none }
            let isCueBall = (name == "cueBall")
            let isTarget = viewModel.isTargetBallName(name)
            return HitResult(
                isUI: false,
                isBall: isCueBall || isTarget,
                isCueBall: isCueBall,
                isTargetBall: isTarget,
                ballId: isTarget ? name : nil
            )
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
    @Published var isHighQuality: Bool = false   // 高/低画质切换
    @Published var cameraContext: CameraContext = .default {
        didSet {
            isInObservationView = (cameraContext.mode == .observe3D)
            scene.isPivotFollowLocked = cameraContext.pivotFollowLocked
        }
    }
    @Published var lastFouls: [Foul] = []
    @Published var lastShotLegal: Bool = true
    @Published var selectionWarning: String? = nil
    
    /// Whether placing mode restricts cue ball to behind head string
    var placingBehindHeadString: Bool = false
    
    /// 目标球选择合法性验证回调：返回 (valid, errorMessage?)
    var ballSelectionValidator: ((String) -> (valid: Bool, message: String?))? = nil

    /// 观察视角中用户点选的下一颗目标球
    private(set) var selectedNextTarget: SCNNode?
    
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
    
    /// 当前击球仰角（与相机 pitch 同步）
    var pitchAngle: Float = CameraRigConfig.aimPitchRad
    
    /// 当前击球事件记录
    private(set) var shotEvents: [GameEvent] = []
    
    /// 当前击球时间（用于播放中跟踪）
    private(set) var currentShotTime: Float = 0
    
    /// 最近一次轨迹记录
    private(set) var lastShotRecorder: TrajectoryRecorder?
    
    /// 规则分组（默认 open）
    private var currentGroup: BallGroup = .open
    
    /// CADisplayLink 驱动的轨迹回放器
    private(set) var trajectoryPlayback: TrajectoryPlayback?
    
    /// 回放起始时间戳（CADisplayLink timestamp）
    private(set) var playbackStartTime: CFTimeInterval = 0

    /// 延迟观察视角：首次球-球碰撞的模拟时间（nil 表示整局无碰撞）
    private var pendingObservationContactTime: Float?
    /// 延迟观察视角：击球时的上下文
    private var pendingObservationContext: (cueBallPosition: SCNVector3, aimDirection: SCNVector3)?
    /// 延迟观察视角：是否已触发过
    private var hasTriggeredObservation: Bool = false
    /// 无碰撞时的后备延迟（秒）
    private let observationFallbackDelay: Float = 0.8
    /// 防止停球阈值附近抖动导致重复切 phase
    private var lastBallsStoppedWallClock: CFTimeInterval = 0
    /// 需要短时间强制把白球投影锁到屏幕中心（用于回合结束/首次选球）
    private var forceCueBallCenteringUntil: CFTimeInterval = 0

    /// 轨迹预测节流与变化阈值缓存
    private var lastTrajectoryPreviewTimestamp: CFTimeInterval = 0
    private var lastTrajectoryCueBallPos: SCNVector3?
    private var lastTrajectoryAimDirection: SCNVector3?
    
    /// 推进当前击球时间
    func advanceShotTime(delta: Float) {
        currentShotTime += delta
    }
    
    // MARK: - Game State
    
    enum GameState {
        case idle           // 空闲
        case placing        // 母球摆放
        case aiming         // 瞄准中（力度由滑条控制）
        case ballsMoving    // 球在运动
        case turnEnd        // 回合结束
    }
    
    /// 摄像系统状态机的便利访问
    var cameraMachineState: CameraState {
        scene.cameraStateMachine.currentState
    }

    /// 旧式相机状态（兼容 UI 层和测试）
    enum LegacyCameraState: Equatable {
        case aim
        case action
        case topDown2D
    }

    var cameraState: LegacyCameraState {
        switch cameraContext.mode {
        case .topDown2D:
            return .topDown2D
        case .observe3D:
            return .action
        case .aim3D:
            return .aim
        }
    }

    // MARK: - Initialization
    
    init() {
        print("[BilliardSceneViewModel] init 开始...")
        scene = BilliardScene()
        isHighQuality = (RenderQualityManager.shared.currentTier == .high)
        cameraContext = .default
        isInObservationView = false
        
        scene.onCameraModeChanged = { [weak self] mode in
            guard let self = self else { return }
            self.isTopDownView = (mode == .topDown2D)
            if mode == .topDown2D {
                self.cameraContext.mode = .topDown2D
            } else if self.cameraContext.mode == .topDown2D {
                self.cameraContext.mode = .aim3D
            }
        }
        scene.cameraContextProvider = { [weak self] in
            self?.cameraContext ?? .default
        }

        scene.cameraStateMachine.onStateChanged = { [weak self] oldState, newState in
            print("[CameraStateMachine] \(oldState) -> \(newState)")
            self?.handleCameraStateTransition(from: oldState, to: newState)
        }
        
        print("[BilliardSceneViewModel] init 完成")
    }

    /// 与 RenderQualityManager 同步，避免自动降级后 UI 状态不一致
    func syncRenderQualityState() {
        let isManagerHigh = (RenderQualityManager.shared.currentTier == .high)
        if isHighQuality != isManagerHigh {
            isHighQuality = isManagerHigh
        }
    }
    
    /// 所有球停止运动后的处理（由 SCNAction 播放完成触发）
    private func onBallsAtRest() {
        guard gameState == .ballsMoving else { return }
        let now = CACurrentMediaTime()
        if now - lastBallsStoppedWallClock < 0.12 {
            return
        }
        lastBallsStoppedWallClock = now
        
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
        cameraContext.phase = .postShot

        // 通知摄像状态机：球停止
        scene.cameraStateMachine.handleEvent(.ballsStopped)
        requestCueBallScreenCentering(duration: 1.1)
    }

    /// 处理摄像状态机转换
    private func handleCameraStateTransition(from oldState: CameraState, to newState: CameraState) {
        syncContextPhaseWithCameraState(newState)

        switch newState {
        case .aiming:
            if oldState == .returnToAim {
                if let selected = selectedNextTarget, selected.parent != nil,
                   let cueBall = scene.cueBallNode {
                    let targetPos = scene.visualCenter(of: selected)
                    let cueBallPos = scene.visualCenter(of: cueBall)
                    aimDirection = SCNVector3(
                        targetPos.x - cueBallPos.x, 0, targetPos.z - cueBallPos.z
                    ).normalized()
                } else {
                    aimDirection = scene.cameraStateMachine.savedAimDirection
                }
                clearNextTargetSelection()
                setupCueStick()
                scene.setAimDirectionForCamera(aimDirection)
            }
        case .returnToAim:
            if selectedNextTarget != nil {
                scene.cameraStateMachine.forceState(.observing)
                cameraContext.mode = .observe3D
                return
            }
            if !isTopDownView, let cueBall = scene.cueBallNode {
                let cueBallPos = scene.visualCenter(of: cueBall)
                var targetDir: SCNVector3?
                if let selected = selectedNextTarget, selected.parent != nil {
                    let targetPos = scene.visualCenter(of: selected)
                    targetDir = SCNVector3(
                        targetPos.x - cueBallPos.x, 0, targetPos.z - cueBallPos.z
                    ).normalized()
                }
                scene.beginReturnToAim(
                    cueBallPosition: cueBallPos,
                    targetDirection: targetDir
                )
            } else if isTopDownView {
                enterTopDownState(animated: true)
                scene.cameraStateMachine.forceState(.aiming)
            }
        default:
            break
        }
    }

    private func syncContextPhaseWithCameraState(_ state: CameraState) {
        var updated = cameraContext
        switch state {
        case .aiming, .adjusting:
            updated.phase = .aiming
        case .shooting, .observing:
            updated.phase = .shotRunning
        case .returnToAim:
            updated.phase = .postShot
        }
        if updated.mode != .topDown2D {
            updated.mode = (state == .observing) ? .observe3D : .aim3D
        }
        cameraContext = updated
    }

    /// 白球当前位置的便利属性
    private var cueBallPosition: SCNVector3 {
        guard let cueBall = scene.cueBallNode else { return SCNVector3Zero }
        return scene.visualCenter(of: cueBall)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Game Setup
    
    /// 设置训练场景；ballPositions 非空时仅显示并定位这些球（来自 USDZ），其余目标球隐藏
    func setupTrainingScene(type: TrainingType, ballPositions: [BallPosition]? = nil) {
        print("[BilliardSceneViewModel] 🎱 setupTrainingScene 开始 type=\(type)")
        // 清除事件
        shotEvents.removeAll()
        scene.hideGhostBall()
        
        // 重置球位置（球来自 USDZ 模型，resetScene 恢复初始位置）
        scene.resetScene()
        // 若配置指定了球布局（如一星瞄准 2 球），则应用并隐藏未用球
        if let positions = ballPositions, !positions.isEmpty {
            scene.applyBallLayout(positions)
        }
        
        // 球已在模型中就位，无需程序化创建
        
        aimDirection = SCNVector3(-1, 0, 0)
        pitchAngle = CameraRigConfig.aimPitchRad
        currentPower = 0

        // 设置球杆
        setupCueStick()
        
        // 切换到第一人称视角
        if !isTopDownView {
            transitionToAimState(animated: false)
        } else {
            enterTopDownState(animated: false)
        }
        
        gameState = .aiming
        cameraContext.phase = .aiming
        print("[BilliardSceneViewModel] ✅ setupTrainingScene 完成")
    }
    
    /// 初始化球杆
    func setupCueStick() {
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
            let cueCenter = scene.visualCenter(of: cueBall)
            cueStick?.update(
                cueBallPosition: cueCenter,
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
    
    /// 从 hit test 命中的子节点向上查找球根节点（母球或目标球）
    func findBallAncestor(_ node: SCNNode) -> SCNNode? {
        var current: SCNNode? = node
        while let n = current {
            if n.name == "cueBall" { return n }
            if let name = n.name, isTargetBallName(name) { return n }
            current = n.parent
        }
        return nil
    }

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
        selectedCuePoint = CGPoint(x: 0.5, y: 0.5)
        
        scene.hideAimLine()
        scene.hideGhostBall()
        scene.hidePredictedTrajectory()
        
        // 检查母球是否在场
        if scene.cueBallNode == nil || scene.cueBallNode?.parent == nil {
            scene.restoreCueBall()
            gameState = .placing
            cameraContext.phase = .ballPlacement
        } else {
            gameState = .aiming
            cameraContext.phase = .aiming
        }
        
        pitchAngle = scene.cameraNode.eulerAngles.x

        setupCueStick()
        if gameState == .aiming {
            cueStick?.show()
        }

        let camState = scene.cameraStateMachine.currentState
        if camState == .observing || camState == .returnToAim {
            return
        }
        
        if !isTopDownView {
            transitionToAimState(animated: true)
        } else {
            enterTopDownState(animated: true)
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
    func updateTrajectoryPreview(minInterval: CFTimeInterval = 1.0 / 30.0, force: Bool = false) {
        guard gameState == .aiming, let cueBall = scene.cueBallNode else {
            scene.hidePredictedTrajectory()
            lastTrajectoryCueBallPos = nil
            lastTrajectoryAimDirection = nil
            return
        }
        
        let cueBallPos = scene.visualCenter(of: cueBall)
        let now = CACurrentMediaTime()
        if !force {
            let elapsed = now - lastTrajectoryPreviewTimestamp
            let cueDelta = lastTrajectoryCueBallPos.map { (cueBallPos - $0).length() } ?? .greatestFiniteMagnitude
            let aimDelta = lastTrajectoryAimDirection.map { (aimDirection - $0).length() } ?? .greatestFiniteMagnitude
            if elapsed < minInterval, cueDelta < 0.002, aimDelta < 0.002 {
                return
            }
        }
        lastTrajectoryPreviewTimestamp = now
        lastTrajectoryCueBallPos = cueBallPos
        lastTrajectoryAimDirection = aimDirection

        let R = BallPhysics.radius
        let surfaceY = cueBallPos.y
        
        // 1. 沿瞄准方向射线检测第一个碰到的目标球
        var closestBall: SCNNode? = nil
        var closestDist: Float = Float.greatestFiniteMagnitude
        
        for ball in scene.targetBallNodes {
            guard ball.parent != nil else { continue }
            let ballPos = scene.visualCenter(of: ball)
            let toBall = ballPos - cueBallPos
            // 投影到瞄准方向
            let projection = toBall.dot(aimDirection)
            guard projection > 0 else { continue }  // 球在母球前方
            
            // 最近点距离
            let closest = cueBallPos + aimDirection * projection
            let perpDist = (ballPos - closest).length()
            
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
        let targetPos = scene.visualCenter(of: targetBall)
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
    
    /// 使用当前滑条力度执行击球
    func executeStrokeFromSlider() {
        executeStroke(power: currentPower)
    }
    
    /// 执行击球 — 使用 EventDrivenEngine 计算轨迹并用 SCNAction 回放
    func executeStroke(power: Float) {
        guard gameState == .aiming, let cueBall = scene.cueBallNode else { return }
        
        let velocity = StrokePhysics.velocity(forPower: power)
        guard velocity > 0 else { return }
        
        shotEvents.removeAll()
        currentShotTime = 0
        
        let normalizedPower = min(max(power, 0), 100) / 100.0
        let strike = computeCueStrike(velocity: velocity, power: normalizedPower)
        let aimUnit = aimDirection.normalized()
        let velUnit = strike.linearVelocity.normalized()
        let alignmentDot = aimUnit.dot(velUnit)
        print("[StrokeDebug] aimUnit=\(aimUnit), velUnit=\(velUnit), alignmentDot=\(alignmentDot)")
        
        // 2. 隐藏瞄准线、轨迹预测；播放球杆前冲击球动画
        cameraContext.mode = .aim3D
        cameraContext.phase = .shotRunning
        cameraContext.interaction = .none
        scene.hideAimLine()
        scene.hidePredictedTrajectory()
        scene.hideGhostBall()
        cueStick?.animateStroke(
            cueBallPosition: scene.visualCenter(of: cueBall),
            aimDirection: aimDirection
        ) {}
        clearNextTargetSelection()
        
        // 3. 创建 EventDrivenEngine 并收集所有球状态
        let engine = EventDrivenEngine(tableGeometry: scene.tableGeometry)
        
        // 母球 — 设置击球后的速度/角速度
        let cueCenter = scene.visualCenter(of: cueBall)
        let cueBallState = BallState(
            position: cueCenter,
            velocity: strike.linearVelocity,
            angularVelocity: SCNVector3(strike.angularVelocity.x, strike.angularVelocity.y, strike.angularVelocity.z),
            state: .sliding,
            name: cueBall.name ?? "cueBall"
        )
        engine.setBall(cueBallState)
        
        // 目标球
        var sampledTargetCenters: [SCNVector3] = []
        var targetCount = 0
        for ballNode in scene.targetBallNodes {
            let center = scene.visualCenter(of: ballNode)
            let state = BallState(
                position: center,
                velocity: SCNVector3Zero,
                angularVelocity: SCNVector3Zero,
                state: .stationary,
                name: ballNode.name ?? "ball"
            )
            engine.setBall(state)
            targetCount += 1
            if sampledTargetCenters.count < 3 { sampledTargetCenters.append(center) }
        }
        
        if let nearest = scene.targetBallNodes
            .map({ scene.visualCenter(of: $0) })
            .min(by: { ($0 - cueCenter).length() < ($1 - cueCenter).length() }) {
            let d = (nearest - cueCenter).length()
            print("[StrokeDebug] cueCenter=\(cueCenter), nearestTargetDistance=\(d), targetCount=\(targetCount)")
        } else {
            print("[StrokeDebug] cueCenter=\(cueCenter), targetCount=0")
        }
        print("[StrokeDebug] sampledTargets=\(sampledTargetCenters)")
        
        // 4. 运行模拟
        engine.simulate(maxEvents: 500, maxTime: 15.0)
        let firstBallBall = engine.resolvedEvents.first {
            if case .ballBall = $0 { return true }
            return false
        }
        print("[StrokeDebug] resolvedEvents=\(engine.resolvedEvents.count), firstBallBall=\(String(describing: firstBallBall))")
        
        // 5. 提取事件记录供规则判定
        extractGameEvents(from: engine)
        
        // 6. 获取轨迹记录器用于回放
        let recorder = engine.getTrajectoryRecorder()
        lastShotRecorder = recorder
        
        // 7. 通知状态机：击球
        updateObservationFocusByBestEffort()
        scene.cameraStateMachine.saveAimContext(aimDirection: aimDirection, zoom: scene.currentCameraZoom)
        scene.cameraStateMachine.handleEvent(.shotFired)
        if let shotPose = scene.captureCurrentCameraPose() {
            cameraContext.shotAnchorPose = shotPose
        }

        gameState = .ballsMoving
        saveAimCameraMemory()

        // 8. 启动 CADisplayLink 驱动的轨迹回放
        startTrajectoryPlayback(recorder: recorder)
        
        // 9. 延迟观察视角：等白球击中目标球后再切换
        hasTriggeredObservation = false
        pendingObservationContactTime = engine.firstBallBallCollisionTime
        pendingObservationContext = (cueBallPosition: cueCenter, aimDirection: aimDirection)
        
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
    
    /// 启动 CADisplayLink 驱动的轨迹回放
    private func startTrajectoryPlayback(recorder: TrajectoryRecorder) {
        let surfaceY = TablePhysics.height + BallPhysics.radius
        trajectoryPlayback = TrajectoryPlayback(recorder: recorder, surfaceY: surfaceY)
        playbackStartTime = 0
    }
    
    /// 每帧由 CADisplayLink 调用：驱动轨迹回放，设置球节点位置/旋转
    func updateTrajectoryPlaybackFrame(timestamp: CFTimeInterval) {
        guard let playback = trajectoryPlayback else { return }
        guard gameState == .ballsMoving else { return }
        
        if playbackStartTime == 0 {
            playbackStartTime = timestamp
        }
        
        let elapsed = Float(timestamp - playbackStartTime)
        let surfaceY = TablePhysics.height + BallPhysics.radius

        // 延迟观察视角：白球击中目标球后再切换
        if !hasTriggeredObservation, !isTopDownView,
           let ctx = pendingObservationContext {
            let triggerTime = pendingObservationContactTime ?? observationFallbackDelay
            if elapsed >= triggerTime {
                hasTriggeredObservation = true
                scene.cameraStateMachine.handleEvent(.ballsStartedMoving)
                scene.setCameraPostShot(cueBallPosition: ctx.cueBallPosition, aimDirection: ctx.aimDirection)
            }
        }

        var allBallNodes: [SCNNode] = []
        if let cueBall = scene.cueBallNode {
            allBallNodes.append(cueBall)
        }
        allBallNodes.append(contentsOf: scene.targetBallNodes)
        
        for ballNode in allBallNodes {
            guard let name = ballNode.name else { continue }
            guard let state = playback.stateAt(ballName: name, time: elapsed) else { continue }
            
            ballNode.position = state.position
            
            // 视觉旋转：根据累积滚动弧度和运动方向旋转球体
            if state.accumulatedRotation > 0.001, state.moveDirection.length() > 0.001 {
                let axis = SCNVector3(0, 1, 0).cross(state.moveDirection).normalized()
                if axis.length() > 0.001 {
                    ballNode.rotation = SCNVector4(
                        axis.x, axis.y, axis.z,
                        state.accumulatedRotation
                    )
                }
            }
            
            // 进袋处理
            if state.motionState == .pocketed && !playback.pocketedBalls.contains(name) {
                playback.markPocketed(name, at: elapsed)
            }
            
            // 淡出效果
            let opacity = playback.opacity(for: name, at: elapsed)
            if opacity < 1.0 {
                ballNode.opacity = CGFloat(opacity)
                if opacity <= 0 {
                    scene.hideShadow(for: name)
                    scene.removeTargetBall(named: name)
                    if name == "cueBall" {
                        scene.clearCueBallReference()
                    }
                    ballNode.removeFromParentNode()
                }
            }
        }
        
        // 回放完成
        if playback.isComplete(at: elapsed) {
            // 确保最终位置精确
            for ballNode in allBallNodes {
                guard let name = ballNode.name else { continue }
                if !playback.pocketedBalls.contains(name) {
                    ballNode.position.y = surfaceY
                }
            }

            // 安全兜底：回放结束但观察视角尚未触发时，立即推入 observing
            if !hasTriggeredObservation {
                hasTriggeredObservation = true
                if let ctx = pendingObservationContext, !isTopDownView {
                    scene.cameraStateMachine.handleEvent(.ballsStartedMoving)
                    scene.setCameraPostShot(cueBallPosition: ctx.cueBallPosition, aimDirection: ctx.aimDirection)
                }
            }

            trajectoryPlayback = nil
            playbackStartTime = 0
            pendingObservationContext = nil
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
        toggleViewMode()
    }
    
    /// 切换高/低画质
    func toggleRenderQuality() {
        syncRenderQualityState()
        isHighQuality.toggle()
        let tier: RenderTier = isHighQuality ? .high : .low
        RenderQualityManager.shared.setTier(tier)
        scene.reapplyRenderSettings()
    }

    /// 2D/3D 视角切换
    func toggleViewMode() {
        cameraContext.transition = TransitionState(isActive: true, locksCameraInput: true)
        let unlockDelay = 0.55
        DispatchQueue.main.asyncAfter(deadline: .now() + unlockDelay) { [weak self] in
            guard let self = self else { return }
            self.cameraContext.transition = TransitionState(isActive: false, locksCameraInput: false)
        }

        let shouldEnterTopDown = scene.currentCameraMode != .topDown2D
        if shouldEnterTopDown {
            enterTopDownState(animated: true)
            cueStick?.hide()
        } else {
            transitionToAimState(animated: true)
            if gameState == .aiming {
                cueStick?.show()
            }
        }
    }
    
    // MARK: - View Switching (Observation / Aiming)
    
    @Published private(set) var isInObservationView: Bool = false

    private enum CameraTrajectoryMode {
        case observation
        case aiming
    }

    private func applyCameraTrajectory(
        _ mode: CameraTrajectoryMode,
        animated: Bool,
        speed: Float = TrainingCameraConfig.cameraTransitionSpeed
    ) {
        guard let cameraRig = scene.cameraRig else { return }
        guard let cueBall = scene.cueBallNode else { return }
        let cueBallPos = scene.visualCenter(of: cueBall)
        let flatAim = SCNVector3(aimDirection.x, 0, aimDirection.z).normalized()
        let alignedYaw = atan2f(-flatAim.z, -flatAim.x)

        switch mode {
        case .observation:
            cameraRig.targetPivot = SCNVector3(cueBallPos.x, TablePhysics.height, cueBallPos.z)
            cameraRig.targetYaw = alignedYaw
            cameraRig.pushToObservation(animated: animated)
            scene.cameraStateMachine.forceState(.observing)
            cameraContext.mode = .observe3D
            cameraContext.phase = (gameState == .placing) ? .ballPlacement : .aiming
        case .aiming:
            cameraRig.targetPivot = SCNVector3(cueBallPos.x, TablePhysics.height, cueBallPos.z)
            cameraRig.targetYaw = alignedYaw
            cameraRig.returnToAim(zoom: 0, animated: animated)
            scene.cameraStateMachine.forceState(.aiming)
            cameraContext.mode = .aim3D
            cameraContext.phase = .aiming
        }

        if animated {
            cameraRig.beginConstantSpeedTransition(speed: speed)
        } else {
            cameraRig.snapToTarget()
        }
    }
    
    /// 切换到观察视角（瞄准状态下）：zoom 升高、pivot 到球桌中心、保持当前瞄准方向
    func switchToObservationView() {
        guard gameState == .aiming, !isTopDownView else { return }
        scene.setAimDirectionForCamera(aimDirection)
        applyCameraTrajectory(.observation, animated: true, speed: TrainingCameraConfig.cameraTransitionSpeed)
    }
    
    /// 切换到瞄准视角（第一人称）：zoom 降到 0、pivot 回到白球
    func switchToAimingView() {
        guard gameState == .aiming, !isTopDownView else { return }
        scene.setAimDirectionForCamera(aimDirection)
        applyCameraTrajectory(.aiming, animated: true, speed: TrainingCameraConfig.cameraTransitionSpeed)
    }
    
    // MARK: - Event Handlers
    
    /// 处理点击事件
    func handleTap(on node: SCNNode, at localCoordinates: SCNVector3) {
        let camState = scene.cameraStateMachine.currentState

        if node.name == "cueBall" && gameState == .aiming {
            // 支持再次选中白球进入放置模式重复移动
            enterPlacingMode(behindHeadString: placingBehindHeadString)
        } else if let name = node.name, isTargetBallName(name),
                  (camState == .observing || camState == .returnToAim) {
            if let validation = ballSelectionValidator?(name), !validation.valid {
                showSelectionWarning(validation.message ?? "不能选择此球")
                return
            }
            selectNextTargetAndReturn(node)
        } else if node.name == "cueBall" && gameState == .idle {
            gameState = .aiming
            cueStick?.show()
            if !isTopDownView {
                transitionToAimState(animated: true)
            }
        } else if let name = node.name, isTargetBallName(name), gameState == .aiming, camState == .aiming {
            if let validation = ballSelectionValidator?(name), !validation.valid {
                showSelectionWarning(validation.message ?? "不能选择此球")
                return
            }
            guard let cueBall = scene.cueBallNode else { return }
            let target = scene.visualCenter(of: node)
            let pockets = scene.pockets()
            let otherBalls = scene.targetBallNodes
                .filter { $0 !== node }
                .map { scene.visualCenter(of: $0) }
            let candidates = AimingCalculator.viablePockets(
                cueBall: scene.visualCenter(of: cueBall),
                objectBall: target,
                pockets: pockets,
                otherBalls: otherBalls
            )
            if let bestPocket = AimingCalculator.pickEasiestPot(candidates) {
                let ghost = AimingCalculator.ghostBallCenter(objectBall: target, pocket: bestPocket.center)
                scene.showGhostBall(at: ghost)
                aimDirection = (ghost - scene.visualCenter(of: cueBall)).normalized()
                scene.setAimDirectionForCamera(aimDirection)
                updateObservationFocusContext(for: node)
            } else {
                scene.hideGhostBall()
                clearObservationFocusContext()
            }
        }
    }

    /// 显示选球警告，自动消失
    private func showSelectionWarning(_ message: String) {
        selectionWarning = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            if self?.selectionWarning == message {
                self?.selectionWarning = nil
            }
        }
    }

    /// 观察视角中选择下一颗目标球，保持观察态并允许继续重选
    private func selectNextTargetAndReturn(_ node: SCNNode) {
        guard gameState != .ballsMoving else {
            showSelectionWarning("请等待球停止后再选择目标球")
            return
        }
        let isInitialSelection = (selectedNextTarget == nil)

        // 与“观察按钮”路径保持一致：进入可瞄准阶段，确保球杆与瞄准线可见。
        if gameState != .aiming {
            gameState = .aiming
            cameraContext.phase = .aiming
            if cueStick == nil {
                setupCueStick()
            }
            cueStick?.show()
        }

        if let prev = selectedNextTarget {
            scene.removeSelectionHighlight(from: prev)
        }
        selectedNextTarget = node
        scene.addSelectionHighlight(to: node)
        updateObservationFocusContext(for: node)

        guard let cueBall = scene.cueBallNode,
              let targetPos = cameraContext.observeTargetBallPosition else { return }
        let cuePos = scene.visualCenter(of: cueBall)
        let nextAim = (targetPos - cuePos).normalized()
        guard nextAim.length() > 0.0001 else { return }

        aimDirection = nextAim
        scene.setAimDirectionForCamera(nextAim)

        if cameraContext.mode == .observe3D, !isTopDownView {
            scene.observationController?.focusOnSelection(
                cueBallPosition: cuePos,
                targetPosition: targetPos,
                aimDirection: nextAim
            )
        }
        if isInitialSelection {
            requestCueBallScreenCentering(duration: 0.7)
        }
    }

    /// 清除目标球选择
    private func clearNextTargetSelection() {
        if let prev = selectedNextTarget {
            scene.removeSelectionHighlight(from: prev)
        }
        selectedNextTarget = nil
    }
    
    /// 确认母球放置
    func confirmCueBallPlacement() {
        guard gameState == .placing else { return }
        clearNextTargetSelection()
        clearObservationFocusContext()
        cameraContext.pivotFollowLocked = false
        cameraContext.interaction = .none
        gameState = .aiming
        cueStick?.show()
        if !isTopDownView {
            switchToObservationView()
        }
    }
    
    /// Enter placing mode with optional head-string restriction
    func enterPlacingMode(behindHeadString: Bool = false) {
        let wasIdle = (gameState == .idle)
        clearNextTargetSelection()
        clearObservationFocusContext()
        shotEvents.removeAll()
        currentPower = 0
        selectedCuePoint = CGPoint(x: 0.5, y: 0.5)
        scene.hideAimLine()
        scene.hideGhostBall()
        scene.hidePredictedTrajectory()
        cueStick?.hide()
        
        placingBehindHeadString = behindHeadString
        
        if scene.cueBallNode == nil || scene.cueBallNode?.parent == nil {
            scene.restoreCueBall()
        }
        
        // 开球/自由球摆放后，默认朝向球堆方向（-X），保持横屏下的击球方向一致
        aimDirection = SCNVector3(-1, 0, 0)
        pitchAngle = scene.cameraNode.eulerAngles.x
        gameState = .placing
        cameraContext.phase = .ballPlacement
        cameraContext.pivotAnchor = .cueBall
        
        let shouldAnimate = !wasIdle
        if scene.currentCameraMode == .topDown2D {
            enterTopDownState(animated: false)
        } else {
            transitionToPlacingObservation(animated: shouldAnimate)
        }
    }
    
    /// 进入白球摆放的观察视角：从白球靠近的短边方向俯视
    private func transitionToPlacingObservation(animated: Bool) {
        guard let cameraRig = scene.cameraRig,
              let cueBall = scene.cueBallNode else {
            transitionToAimState(animated: animated)
            return
        }
        // 开球放置视角：从近端短库边看向远端（-X），符合真实站位
        let nearToFarDir = SCNVector3(-1, 0, 0)
        aimDirection = nearToFarDir
        let shortEdgeYaw: Float = atan2f(-nearToFarDir.z, -nearToFarDir.x)
        let cuePos = scene.visualCenter(of: cueBall)
        cameraRig.targetPivot = SCNVector3(cuePos.x, TablePhysics.height, cuePos.z)
        cameraRig.targetYaw = shortEdgeYaw
        cameraRig.pushToObservation(animated: animated)
        if animated {
            cameraRig.beginConstantSpeedTransition(speed: TrainingCameraConfig.cameraTransitionSpeed)
        } else {
            cameraRig.snapToTarget()
        }
        cameraContext.mode = .observe3D
        cameraContext.phase = .ballPlacement
        cameraContext.pivotAnchor = .cueBall
        scene.cameraStateMachine.forceState(.observing)
    }

    func beginCueBallDrag() {
        guard gameState == .placing else { return }
        cameraContext.pivotFollowLocked = true
        cameraContext.interaction = .draggingCueBall
    }

    func endCueBallDrag() {
        guard gameState == .placing else { return }
        guard let cueBall = scene.cueBallNode else { return }

        let cuePos = scene.visualCenter(of: cueBall)
        if let rackFront = scene.targetBallNodes
            .filter({ $0.parent != nil })
            .min(by: { scene.visualCenter(of: $0).x < scene.visualCenter(of: $1).x }) {
            let targetPos = scene.visualCenter(of: rackFront)
            aimDirection = SCNVector3(targetPos.x - cuePos.x, 0, targetPos.z - cuePos.z).normalized()
        }

        gameState = .aiming
        setupCueStick()
        cueStick?.show()
        scene.setAimDirectionForCamera(aimDirection)
        applyCameraTrajectory(
            .observation,
            animated: true,
            speed: TrainingCameraConfig.placingToAimTransitionSpeed
        )

        // 拖拽结束后先保持锁定，待回正动画结束再解锁，避免镜头跳变
        cameraContext.interaction = .none
        cameraContext.pivotFollowLocked = true
        let unlockDelay = max(0.3, TrainingCameraConfig.transitionDuration)
        DispatchQueue.main.asyncAfter(deadline: .now() + unlockDelay) { [weak self] in
            guard let self = self else { return }
            self.cameraContext.pivotFollowLocked = false
        }
    }
    
    private func saveAimCameraMemory() {
        scene.saveCurrentAimZoom()
        if let pose = scene.captureCurrentCameraPose() {
            cameraContext.savedAimPose = pose
        }
    }

    private func requestCueBallScreenCentering(duration: CFTimeInterval) {
        let deadline = CACurrentMediaTime() + max(0, duration)
        forceCueBallCenteringUntil = max(forceCueBallCenteringUntil, deadline)
    }

    func shouldForceCueBallScreenCentering(at now: CFTimeInterval) -> Bool {
        if now <= forceCueBallCenteringUntil {
            return true
        }
        forceCueBallCenteringUntil = 0
        return false
    }

    private func clearObservationFocusContext() {
        cameraContext.observeTargetBallId = nil
        cameraContext.observeTargetBallPosition = nil
        cameraContext.observePocketId = nil
        cameraContext.observePocketPosition = nil
    }

    private func updateObservationFocusContext(for targetNode: SCNNode) {
        guard let targetName = targetNode.name,
              scene.cueBallNode != nil else {
            clearObservationFocusContext()
            return
        }
        let targetPos = scene.visualCenter(of: targetNode)
        cameraContext.observeTargetBallId = targetName
        cameraContext.observeTargetBallPosition = targetPos
        cameraContext.observePocketId = nil
        cameraContext.observePocketPosition = nil
    }

    private func updateObservationFocusByBestEffort() {
        if let selected = selectedNextTarget, selected.parent != nil {
            updateObservationFocusContext(for: selected)
            return
        }
        guard let cueBall = scene.cueBallNode else {
            clearObservationFocusContext()
            return
        }
        let cuePos = scene.visualCenter(of: cueBall)
        guard let nearestTarget = scene.targetBallNodes
            .filter({ $0.parent != nil })
            .min(by: { (scene.visualCenter(of: $0) - cuePos).length() < (scene.visualCenter(of: $1) - cuePos).length() }) else {
            clearObservationFocusContext()
            return
        }
        updateObservationFocusContext(for: nearestTarget)
    }
    
    private func transitionToAimState(animated: Bool) {
        saveAimCameraMemory()
        scene.returnCameraToAim(animated: animated)
        scene.setAimDirectionForCamera(aimDirection)
        scene.cameraStateMachine.forceState(.aiming)
        cameraContext.mode = .aim3D
        cameraContext.phase = .aiming
        cameraContext.pivotAnchor = .cueBall
    }

    private func enterTopDownState(animated: Bool) {
        scene.setCameraMode(.topDown2D, animated: animated)
        scene.hideAimLine()
        scene.hidePredictedTrajectory()
        isTopDownView = true
        cameraContext.mode = .topDown2D
        cameraContext.pivotAnchor = .tableCenter
    }
    
    func quickResetPlanningCamera() {
        toggleViewMode()
    }
    
    func applyCameraPreset(_ preset: String) {
        // CameraRig 版本不再支持轨道预设，保留空实现以兼容现有调用方。
    }
    
    func saveCameraPreset(slot: Int) {
        _ = slot
    }
    
    func loadCameraPreset(slot: Int) {
        _ = slot
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
