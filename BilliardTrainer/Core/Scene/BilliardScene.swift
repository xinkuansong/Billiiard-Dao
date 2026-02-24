//
//  BilliardScene.swift
//  BilliardTrainer
//
//  SceneKit 台球场景核心类
//

import SceneKit
import SwiftUI
import UIKit

// MARK: - Billiard Scene
/// 台球场景管理器
class BilliardScene: SCNScene {
    
    // MARK: - Properties
    
    /// 球台节点
    private(set) var tableNode: SCNNode!
    
    /// 母球节点
    private(set) var cueBallNode: SCNNode!
    
    /// 所有目标球节点
    private(set) var targetBallNodes: [SCNNode] = []
    
    /// 所有球节点引用（用于重置）
    private var allBallNodes: [String: SCNNode] = [:]
    
    /// 所有球节点的初始位置（用于重置）
    private var initialBallPositions: [String: SCNVector3] = [:]
    
    /// 从 USDZ 模型得到的初始位置备份（用于恢复“全部球”布局）
    private var modelInitialBallPositions: [String: SCNVector3] = [:]
    
    /// CameraRig（核心摄像机驱动）
    private(set) var cameraRig: CameraRig?

    /// 摄像系统状态机
    private(set) var cameraStateMachine = CameraStateMachine()

    /// 瞄准控制器
    private(set) var aimingController: AimingController?

    /// 视角过渡控制器
    private(set) var viewTransitionController: ViewTransitionController?

    /// 观察视角控制器
    private(set) var observationController: ObservationController?

    /// 自动对齐控制器
    private(set) var autoAlignController: AutoAlignController?

    /// 上帧白球 XZ 位置，用于检测白球是否实际移动
    private var lastTrackedCueBallXZ: SIMD2<Float>?

    /// 相机节点
    private(set) var cameraNode: SCNNode!
    
    /// 灯光节点
    private(set) var lightNodes: [SCNNode] = []
    
    /// 瞄准线节点
    private(set) var aimLineNode: SCNNode?
    
    /// 幽灵球节点
    private var ghostBallNode: SCNNode?
    
    /// 球影节点
    private var shadowNodes: [String: SCNNode] = [:]
    
    /// 预测轨迹节点（母球碰后路径 + 目标球路径）
    private var predictedTrajectoryNodes: [SCNNode] = []
    
    /// 当前视角模式
    private(set) var currentCameraMode: CameraMode = .aim {
        didSet {
            if currentCameraMode != oldValue {
                onCameraModeChanged?(currentCameraMode)
            }
        }
    }
    
    /// 视角模式变化回调（供 ViewModel 自动同步 UI 状态）
    var onCameraModeChanged: ((CameraMode) -> Void)?
    /// 记忆用户在 Aim 态的 zoom（用于 Action -> Aim 回归）
    private var savedAimZoom: Float = 0

    
    /// 球台几何描述
    private(set) var tableGeometry: TableGeometry = .chineseEightBall()
    
    /// USDZ 模型提取的球杆节点（供 CueStick 使用）
    private(set) var modelCueStickNode: SCNNode?
    
    /// 地面节点（3D 视角参考平面，Y = SceneLayout.groundLevelY）
    private(set) var groundNode: SCNNode?
    
    // MARK: - Camera Mode
    enum CameraMode: Equatable {
        case aim            // CameraRig 瞄准态
        case action         // CameraRig 观察态
        case topDown2D      // 2D俯视
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupScene()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupScene()
    }
    
    // MARK: - Setup
    
    private func setupScene() {
        setupEnvironment()
        setupGround()
        setupTable()
        setupLights()
        setupCamera()
        setupPhysics()
    }
    
    /// 两层地面：Layer 1 unlit 视觉面 + Layer 2 shadow catcher
    private func setupGround() {
        let planeSize: CGFloat = 40

        // ── Layer 1: 视觉地面 (unlit, 与背景无缝衔接) ──
        let visualPlane = SCNPlane(width: planeSize, height: planeSize)
        let visualMat = SCNMaterial()
        visualMat.lightingModel = .constant
        visualMat.diffuse.contents = UIColor(red: 0.032, green: 0.042, blue: 0.062, alpha: 1.0)
        visualMat.writesToDepthBuffer = true
        visualMat.readsFromDepthBuffer = true
        visualMat.isDoubleSided = false
        visualPlane.materials = [visualMat]

        let visualNode = SCNNode(geometry: visualPlane)
        visualNode.name = "ground_visual"
        visualNode.eulerAngles.x = -.pi / 2
        visualNode.position = SCNVector3(0, SceneLayout.groundLevelY, 0)
        visualNode.castsShadow = false
        visualNode.renderingOrder = -10
        rootNode.addChildNode(visualNode)

        // ── Layer 2: Shadow catcher (只渲染阴影) ──
        let shadowPlane = SCNPlane(width: planeSize, height: planeSize)
        let shadowMat = SCNMaterial()
        shadowMat.lightingModel = .physicallyBased
        shadowMat.diffuse.contents = UIColor.white
        shadowMat.roughness.contents = Float(1.0)
        shadowMat.metalness.contents = Float(0.0)
        shadowMat.isDoubleSided = false
        shadowMat.writesToDepthBuffer = false
        shadowMat.readsFromDepthBuffer = true
        shadowMat.blendMode = .alpha
        shadowMat.shaderModifiers = [.fragment: Self.shadowCatcherShader]
        shadowPlane.materials = [shadowMat]

        let shadowNode = SCNNode(geometry: shadowPlane)
        shadowNode.name = "ground_shadow"
        shadowNode.eulerAngles.x = -.pi / 2
        shadowNode.position = SCNVector3(0, SceneLayout.groundLevelY + 0.0005, 0)
        shadowNode.castsShadow = false
        shadowNode.renderingOrder = -9
        rootNode.addChildNode(shadowNode)

        groundNode = visualNode
    }

    /// Shadow catcher fragment shader:
    /// 利用漫反射光照贡献判断阴影区域，仅输出半透明黑色叠加
    private static let shadowCatcherShader = """
    float lum = dot(_lightingContribution.diffuse, float3(0.2126, 0.7152, 0.0722));
    float lit = saturate(lum);
    float shadowAlpha = (1.0 - lit) * 0.35;
    _output.color = float4(0.0, 0.0, 0.0, shadowAlpha);
    """
    
    /// 设置环境光照：HDRI 或增强程序化 cube map（按 Tier 自动选择）
    private func setupEnvironment() {
        EnvironmentLightingManager.apply(to: self, tier: RenderQualityManager.shared.currentTier)
    }
    
    /// 设置球台（视觉与物理分离架构）
    /// USDZ 模型提供视觉渲染，不可见的简单几何体处理物理碰撞
    private func setupTable() {
        tableNode = SCNNode()
        tableNode.name = "table"
        
        tableGeometry = .chineseEightBall()
        
        // 1. 加载 USDZ 视觉模型
        if let tableModel = TableModelLoader.loadTable() {
            // 将模型放置在正确高度
            // 模型的 surfaceY 表示台面在模型中的 Y 高度
            // 我们需要模型的台面对齐到 TablePhysics.height
            let yOffset = TablePhysics.height - tableModel.surfaceY
            
            print("[BilliardScene] 📐 yOffset=\(yOffset), surfaceY=\(tableModel.surfaceY), TablePhysics.height=\(TablePhysics.height)")
            // 安全检查：yOffset 不应过大（放宽到 10m 以适配不同模型单位）
            if abs(yOffset) > 10.0 || yOffset.isNaN {
                print("[BilliardScene] ⚠️ 异常 yOffset=\(yOffset), surfaceY=\(tableModel.surfaceY), 回退到程序化球台")
                setupFallbackTableTop()
            } else {
                tableModel.visualNode.position.y += yOffset
                tableNode.addChildNode(tableModel.visualNode)
                
                // 保存球杆模型节点（位置已归零，由 CueStick 类动态控制）
                if let cueNode = tableModel.cueStickNode {
                    modelCueStickNode = cueNode
                    print("[BilliardScene] ✅ 球杆模型已保存，将由 CueStick 使用")
                }
                
                print("[BilliardScene] ✅ USDZ model loaded:")
                print("[BilliardScene]   surfaceY=\(tableModel.surfaceY), TablePhysics.height=\(TablePhysics.height)")
                print("[BilliardScene]   yOffset=\(yOffset)")
                print("[BilliardScene]   visualNode final position=\(tableModel.visualNode.position)")
                print("[BilliardScene]   visualNode scale=\(tableModel.visualNode.scale)")
            }
        } else {
            // 降级方案：使用程序化台面
            print("[BilliardScene] USDZ model not available, using fallback")
            setupFallbackTableTop()
        }
        
        // 2. 不可见物理碰撞体（始终由代码生成，精确控制碰撞）
        setupPhysicsColliders()
        
        // 3. 颗星标记（叠加在物理层上方）
        setupDiamonds()
        
        rootNode.addChildNode(tableNode)

        // 4. 调试：打印 USDZ 材质信息（首次运行时查看控制台）
        MaterialFactory.debugPrintMaterials(in: tableNode)

        // 5. 增强台面 / 木边 / 袋口材质
        MaterialFactory.enhanceClothMaterials(in: tableNode)
        MaterialFactory.enhanceRailMaterials(in: tableNode)
        MaterialFactory.enhancePocketMaterials(in: tableNode)

        // 6. 台面中央微提亮（摄影棚感 radial vignette 反转）
        addTableCenterGlow()

        // 7. 从模型中提取球节点，设置为游戏球（必须在 tableNode 加入 rootNode 之后执行）
        setupModelBalls()
    }
    
    /// Subtle center-bright radial overlay on table surface (~+4% center, 0% edges)
    private func addTableCenterGlow() {
        let w = CGFloat(TablePhysics.innerLength)
        let h = CGFloat(TablePhysics.innerWidth)
        let plane = SCNPlane(width: w, height: h)

        let glowSize: CGFloat = 256
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: glowSize, height: glowSize))
        let tex = renderer.image { ctx in
            let center = CGPoint(x: glowSize / 2, y: glowSize / 2)
            if let grad = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor(white: 1.0, alpha: 0.04).cgColor,
                    UIColor(white: 1.0, alpha: 0.0).cgColor
                ] as CFArray,
                locations: [0.0, 1.0]
            ) {
                ctx.cgContext.drawRadialGradient(
                    grad,
                    startCenter: center, startRadius: 0,
                    endCenter: center, endRadius: glowSize * 0.5,
                    options: []
                )
            }
        }

        let mat = SCNMaterial()
        mat.diffuse.contents = tex
        mat.lightingModel = .constant
        mat.isDoubleSided = false
        mat.writesToDepthBuffer = false
        mat.transparencyMode = .aOne
        mat.blendMode = .add
        plane.materials = [mat]

        let node = SCNNode(geometry: plane)
        node.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        node.position = SCNVector3(0, TablePhysics.height + 0.002, 0)
        node.renderingOrder = -2
        rootNode.addChildNode(node)
    }

    // MARK: - Physics Colliders (Invisible)
    
    /// 设置不可见的物理碰撞体
    /// 这些碰撞体精确匹配 PhysicsConstants 中的尺寸，用于物理模拟
    private func setupPhysicsColliders() {
        setupSurfaceCollider()
        setupCushionColliders()
        setupPocketColliders()
    }
    
    /// 台面碰撞体
    private func setupSurfaceCollider() {
        let surfaceThickness: Float = 0.02
        let surfaceGeometry = SCNBox(
            width: CGFloat(TablePhysics.innerLength),
            height: CGFloat(surfaceThickness),
            length: CGFloat(TablePhysics.innerWidth),
            chamferRadius: 0
        )
        
        let surfaceNode = SCNNode(geometry: surfaceGeometry)
        surfaceNode.name = "surface_collider"
        // 碰撞体顶面对齐 TablePhysics.height，球才能贴合视觉台面
        surfaceNode.position = SCNVector3(0, TablePhysics.height - surfaceThickness / 2, 0)
        surfaceNode.opacity = 0  // 不可见
        
        // 静态物理体
        let physicsShape = SCNPhysicsShape(geometry: surfaceGeometry, options: [
            .type: SCNPhysicsShape.ShapeType.concavePolyhedron
        ])
        surfaceNode.physicsBody = SCNPhysicsBody(type: .static, shape: physicsShape)
        surfaceNode.physicsBody?.restitution = 0.05  // 极低弹性，防止球弹跳
        surfaceNode.physicsBody?.friction = CGFloat(TablePhysics.clothFriction)
        
        tableNode.addChildNode(surfaceNode)
    }
    
    /// 库边碰撞体（不可见）
    private func setupCushionColliders() {
        let halfLength = TablePhysics.innerLength / 2
        let halfWidth = TablePhysics.innerWidth / 2
        let cushionHeight = TablePhysics.cushionHeight
        let cushionThickness = TablePhysics.cushionThickness
        let tableHeight = TablePhysics.height
        
        // 长边库边 (上下)
        let longCushionGeometry = SCNBox(
            width: CGFloat(TablePhysics.innerLength),
            height: CGFloat(cushionHeight),
            length: CGFloat(cushionThickness),
            chamferRadius: 0.005
        )
        
        // 上边库
        let topCushionNode = SCNNode(geometry: longCushionGeometry)
        topCushionNode.name = "cushion_top"
        topCushionNode.position = SCNVector3(
            0,
            tableHeight + cushionHeight / 2,
            halfWidth + cushionThickness / 2
        )
        topCushionNode.opacity = 0
        topCushionNode.physicsBody = createCushionPhysicsBody(geometry: longCushionGeometry)
        tableNode.addChildNode(topCushionNode)
        
        // 下边库
        let bottomCushionNode = SCNNode(geometry: longCushionGeometry)
        bottomCushionNode.name = "cushion_bottom"
        bottomCushionNode.position = SCNVector3(
            0,
            tableHeight + cushionHeight / 2,
            -(halfWidth + cushionThickness / 2)
        )
        bottomCushionNode.opacity = 0
        bottomCushionNode.physicsBody = createCushionPhysicsBody(geometry: longCushionGeometry)
        tableNode.addChildNode(bottomCushionNode)
        
        // 短边库边 (左右)
        let shortCushionGeometry = SCNBox(
            width: CGFloat(cushionThickness),
            height: CGFloat(cushionHeight),
            length: CGFloat(TablePhysics.innerWidth),
            chamferRadius: 0.005
        )
        
        // 左边库
        let leftCushionNode = SCNNode(geometry: shortCushionGeometry)
        leftCushionNode.name = "cushion_left"
        leftCushionNode.position = SCNVector3(
            -(halfLength + cushionThickness / 2),
            tableHeight + cushionHeight / 2,
            0
        )
        leftCushionNode.opacity = 0
        leftCushionNode.physicsBody = createCushionPhysicsBody(geometry: shortCushionGeometry)
        tableNode.addChildNode(leftCushionNode)
        
        // 右边库
        let rightCushionNode = SCNNode(geometry: shortCushionGeometry)
        rightCushionNode.name = "cushion_right"
        rightCushionNode.position = SCNVector3(
            halfLength + cushionThickness / 2,
            tableHeight + cushionHeight / 2,
            0
        )
        rightCushionNode.opacity = 0
        rightCushionNode.physicsBody = createCushionPhysicsBody(geometry: shortCushionGeometry)
        tableNode.addChildNode(rightCushionNode)
    }
    
    /// 创建库边物理体
    private func createCushionPhysicsBody(geometry: SCNGeometry) -> SCNPhysicsBody {
        let physicsBody = SCNPhysicsBody(
            type: .static,
            shape: SCNPhysicsShape(geometry: geometry, options: nil)
        )
        physicsBody.restitution = CGFloat(TablePhysics.cushionRestitution)
        physicsBody.friction = CGFloat(TablePhysics.clothFriction)
        return physicsBody
    }
    
    /// 袋口碰撞检测体（不可见）
    private func setupPocketColliders() {
        let tableHeight = TablePhysics.height
        
        for pocket in tableGeometry.pockets {
            let radius = pocket.radius
            let pocketGeometry = SCNCylinder(radius: CGFloat(radius), height: 0.05)
            
            let pocketNode = SCNNode(geometry: pocketGeometry)
            pocketNode.name = pocket.id
            pocketNode.position = SCNVector3(pocket.center.x, tableHeight - 0.02, pocket.center.z)
            pocketNode.opacity = 0  // 不可见
            
            // 用于检测球进袋的物理体
            pocketNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
            
            tableNode.addChildNode(pocketNode)
        }
    }
    
    // MARK: - Fallback Table (Programmatic)
    
    /// 降级方案：程序化生成球台（当 USDZ 模型不可用时）
    private func setupFallbackTableTop() {
        // 台面
        let tableTopGeometry = SCNBox(
            width: CGFloat(TablePhysics.innerLength),
            height: 0.02,
            length: CGFloat(TablePhysics.innerWidth),
            chamferRadius: 0
        )
        
        let clothMaterial = SCNMaterial()
        clothMaterial.diffuse.contents = UIColor(red: 0.0, green: 0.45, blue: 0.3, alpha: 1.0)
        clothMaterial.roughness.contents = 0.8
        tableTopGeometry.materials = [clothMaterial]
        
        let tableTopNode = SCNNode(geometry: tableTopGeometry)
        tableTopNode.name = "tableTop_fallback"
        tableTopNode.position = SCNVector3(0, Float(TablePhysics.height), 0)
        tableNode.addChildNode(tableTopNode)
        
        // 可见的库边（降级方案需要可见）
        setupFallbackCushions()
        
        // 可见的袋口
        setupFallbackPockets()
    }
    
    /// 降级方案：可见的库边
    private func setupFallbackCushions() {
        let cushionMaterial = SCNMaterial()
        cushionMaterial.diffuse.contents = UIColor(red: 0.0, green: 0.35, blue: 0.25, alpha: 1.0)
        
        let halfLength = TablePhysics.innerLength / 2
        let halfWidth = TablePhysics.innerWidth / 2
        let cushionHeight = TablePhysics.cushionHeight
        let cushionThickness = TablePhysics.cushionThickness
        let tableHeight = TablePhysics.height
        
        let longCushionGeometry = SCNBox(
            width: CGFloat(TablePhysics.innerLength),
            height: CGFloat(cushionHeight),
            length: CGFloat(cushionThickness),
            chamferRadius: 0.005
        )
        longCushionGeometry.materials = [cushionMaterial]
        
        let topNode = SCNNode(geometry: longCushionGeometry)
        topNode.name = "fallback_cushion_top"
        topNode.position = SCNVector3(0, tableHeight + cushionHeight / 2, halfWidth + cushionThickness / 2)
        tableNode.addChildNode(topNode)
        
        let bottomNode = SCNNode(geometry: longCushionGeometry)
        bottomNode.name = "fallback_cushion_bottom"
        bottomNode.position = SCNVector3(0, tableHeight + cushionHeight / 2, -(halfWidth + cushionThickness / 2))
        tableNode.addChildNode(bottomNode)
        
        let shortCushionGeometry = SCNBox(
            width: CGFloat(cushionThickness),
            height: CGFloat(cushionHeight),
            length: CGFloat(TablePhysics.innerWidth),
            chamferRadius: 0.005
        )
        shortCushionGeometry.materials = [cushionMaterial]
        
        let leftNode = SCNNode(geometry: shortCushionGeometry)
        leftNode.name = "fallback_cushion_left"
        leftNode.position = SCNVector3(-(halfLength + cushionThickness / 2), tableHeight + cushionHeight / 2, 0)
        tableNode.addChildNode(leftNode)
        
        let rightNode = SCNNode(geometry: shortCushionGeometry)
        rightNode.name = "fallback_cushion_right"
        rightNode.position = SCNVector3(halfLength + cushionThickness / 2, tableHeight + cushionHeight / 2, 0)
        tableNode.addChildNode(rightNode)
    }
    
    /// 降级方案：可见的袋口
    private func setupFallbackPockets() {
        let pocketMaterial = SCNMaterial()
        pocketMaterial.diffuse.contents = UIColor.black
        let tableHeight = TablePhysics.height
        
        for pocket in tableGeometry.pockets {
            let radius = pocket.radius
            let pocketGeometry = SCNCylinder(radius: CGFloat(radius), height: 0.05)
            pocketGeometry.materials = [pocketMaterial]
            
            let pocketNode = SCNNode(geometry: pocketGeometry)
            pocketNode.name = "fallback_\(pocket.id)"
            pocketNode.position = SCNVector3(pocket.center.x, tableHeight - 0.02, pocket.center.z)
            tableNode.addChildNode(pocketNode)
        }
    }
    
    /// 设置颗星标记
    private func setupDiamonds() {
        let diamondMaterial = SCNMaterial()
        diamondMaterial.diffuse.contents = UIColor(white: 0.9, alpha: 1.0)
        
        let diamondGeometry = SCNSphere(radius: 0.008)
        diamondGeometry.materials = [diamondMaterial]
        
        let halfLength = TablePhysics.innerLength / 2
        let halfWidth = TablePhysics.innerWidth / 2
        let tableHeight = TablePhysics.height
        let cushionThickness = TablePhysics.cushionThickness
        
        // 长边颗星 (4个间隔)
        let longSpacing = TablePhysics.innerLength / Float(TablePhysics.diamondCount)
        for i in 1..<TablePhysics.diamondCount {
            let x = -halfLength + Float(i) * longSpacing
            
            // 上边颗星
            let topDiamond = SCNNode(geometry: diamondGeometry)
            topDiamond.position = SCNVector3(x, tableHeight + 0.02, halfWidth + cushionThickness)
            tableNode.addChildNode(topDiamond)
            
            // 下边颗星
            let bottomDiamond = SCNNode(geometry: diamondGeometry)
            bottomDiamond.position = SCNVector3(x, tableHeight + 0.02, -(halfWidth + cushionThickness))
            tableNode.addChildNode(bottomDiamond)
        }
        
        // 短边颗星 (3个间隔 → 2个内部标记)
        let shortDiamondCount = 3
        let shortSpacing = TablePhysics.innerWidth / Float(shortDiamondCount)
        for i in 1..<shortDiamondCount {
            let z = -halfWidth + Float(i) * shortSpacing
            
            // 左边颗星
            let leftDiamond = SCNNode(geometry: diamondGeometry)
            leftDiamond.position = SCNVector3(-(halfLength + cushionThickness), tableHeight + 0.02, z)
            tableNode.addChildNode(leftDiamond)
            
            // 右边颗星
            let rightDiamond = SCNNode(geometry: diamondGeometry)
            rightDiamond.position = SCNVector3(halfLength + cushionThickness, tableHeight + 0.02, z)
            tableNode.addChildNode(rightDiamond)
        }
    }
    
    /// 摄影棚式三灯系统：Key + IBL + Rim
    private func setupLights() {
        let flags = RenderQualityManager.shared.featureFlags

        // ── 1. Key Light：主顶光（体积 + 阴影 + 高光） ──
        // 6500K 中性白，pitch ~-82°，唯一投影光源
        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.intensity = 750
        keyLight.color = UIColor(red: 1.0, green: 0.99, blue: 0.96, alpha: 1.0)
        keyLight.castsShadow = true
        keyLight.shadowRadius = 2.5
        keyLight.shadowSampleCount = 16
        keyLight.shadowColor = UIColor(white: 0.0, alpha: 0.22)
        keyLight.shadowMapSize = CGSize(width: flags.shadowMapSize, height: flags.shadowMapSize)
        keyLight.shadowBias = 0.02
        keyLight.shadowMode = flags.shadowMode
        keyLight.orthographicScale = 3.0

        let keyLightNode = SCNNode()
        keyLightNode.light = keyLight
        keyLightNode.position = SCNVector3(0, 4, 0)
        keyLightNode.eulerAngles = SCNVector3(-82.0 * Float.pi / 180.0, 0, 0)
        rootNode.addChildNode(keyLightNode)
        lightNodes.append(keyLightNode)

        // ── 2. Rim Light：弱侧分离光（轮廓张力） ──
        // 5500K 略暖，从侧后方打入，不投影
        let rimLight = SCNLight()
        rimLight.type = .directional
        rimLight.intensity = 150
        rimLight.color = UIColor(red: 1.0, green: 0.96, blue: 0.90, alpha: 1.0)
        rimLight.castsShadow = false

        let rimLightNode = SCNNode()
        rimLightNode.light = rimLight
        // 从右后上方 (yaw ~135°, pitch ~-40°)
        rimLightNode.eulerAngles = SCNVector3(
            -40.0 * Float.pi / 180.0,
            135.0 * Float.pi / 180.0,
            0
        )
        rootNode.addChildNode(rimLightNode)
        lightNodes.append(rimLightNode)
    }
    
    /// 设置相机（HDR + Tone Mapping + SSAO + Bloom 按 Tier 配置）
    private func setupCamera() {
        let flags = RenderQualityManager.shared.featureFlags
        let camera = SCNCamera()
        camera.zNear = 0.01
        camera.zFar = 100
        camera.fieldOfView = CameraRigConfig.aimFov

        // ── HDR + Tone Mapping ──
        camera.wantsHDR = true
        if flags.toneMappingEnabled {
            camera.exposureOffset = -0.25
            camera.minimumExposure = -2.0
            camera.maximumExposure = 3.0
            camera.whitePoint = 1.0
            camera.wantsExposureAdaptation = false
        }

        // ── SSAO（接触阴影 + 凹角暗化） ──
        if flags.ssaoEnabled {
            camera.screenSpaceAmbientOcclusionIntensity = flags.ssaoIntensity
            camera.screenSpaceAmbientOcclusionRadius = flags.ssaoRadius
            camera.screenSpaceAmbientOcclusionNormalThreshold = 0.3
            camera.screenSpaceAmbientOcclusionDepthThreshold = 0.01
            camera.screenSpaceAmbientOcclusionBias = 0.01
        } else {
            camera.screenSpaceAmbientOcclusionIntensity = 0
        }

        // ── Bloom ──
        if flags.bloomEnabled {
            camera.bloomIntensity = flags.bloomIntensity
            camera.bloomThreshold = flags.bloomThreshold
            camera.bloomBlurRadius = 4.0
        }

        cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.name = "billiard_camera"

        rootNode.addChildNode(cameraNode)

        let rig = CameraRig(cameraNode: cameraNode, tableSurfaceY: TablePhysics.height)
        cameraRig = rig
        savedAimZoom = 0

        aimingController = AimingController(cameraRig: rig)
        viewTransitionController = ViewTransitionController(cameraRig: rig)
        observationController = ObservationController(cameraRig: rig)
        autoAlignController = AutoAlignController(cameraRig: rig)
        
        // 默认进入 Aim 态
        setCameraMode(.aim, animated: false)
        
        print("[BilliardScene] 📷 Camera setup complete:")
        print("[BilliardScene]   cueBallNode exists: \(cueBallNode != nil)")
        print("[BilliardScene]   cueBallNode position: \(cueBallNode?.position ?? SCNVector3Zero)")
        print("[BilliardScene]   camera position: \(cameraNode.position)")
        print("[BilliardScene]   camera eulerAngles: \(cameraNode.eulerAngles)")
        print("[BilliardScene]   targetBallNodes count: \(targetBallNodes.count)")
    }
    
    /// 设置物理世界（永久禁用 — 物理计算由 EventDrivenEngine 处理）
    private func setupPhysics() {
        physicsWorld.gravity = SCNVector3Zero
        physicsWorld.speed = 0
    }
    
    // MARK: - Model Ball Extraction
    
    /// 从 USDZ 模型中提取球节点，设置物理体，作为游戏球使用
    private func setupModelBalls() {
        guard let visualNode = tableNode.childNode(withName: "tableVisual", recursively: false) else {
            print("[BilliardScene] ❌ 未找到 tableVisual 节点，USDZ 模型加载失败")
            return
        }
        
        targetBallNodes.removeAll()
        allBallNodes.removeAll()
        initialBallPositions.removeAll()
        
        func hasRenderableGeometry(_ node: SCNNode) -> Bool {
            if node.geometry != nil { return true }
            for child in node.childNodes where hasRenderableGeometry(child) { return true }
            return false
        }
        
        func firstGeometryNode(in node: SCNNode) -> SCNNode? {
            if node.geometry != nil { return node }
            for child in node.childNodes {
                if let found = firstGeometryNode(in: child) { return found }
            }
            return nil
        }
        
        func collectNodes(named targetName: String, in root: SCNNode, result: inout [SCNNode]) {
            if root.name == targetName {
                result.append(root)
            }
            for child in root.childNodes {
                collectNodes(named: targetName, in: child, result: &result)
            }
        }
        
        let ballNames = (0...15).map { "_\($0)" }
        var foundCount = 0
        var ballSizeVerified = 0
        var ballSizeMismatch = 0
        let correctY = TablePhysics.height + BallPhysics.radius
        for name in ballNames {
            var matches: [SCNNode] = []
            collectNodes(named: name, in: visualNode, result: &matches)
            
            guard !matches.isEmpty else {
                print("[BilliardScene] 模型中未找到球节点: \(name)")
                continue
            }
            
            // _N 通常是空父节点，真实网格在子节点里；以 _N 为提取锚点
            let anchorNode = matches[0]
            guard let sourceNode = firstGeometryNode(in: anchorNode) else {
                print("[BilliardScene] ⚠️ 球 '\(name)' 未找到几何网格节点")
                continue
            }
            foundCount += 1
            
            // 计算球心世界坐标（不能用 node.position；该模型球心在几何顶点偏移里）
            let (meshMin, meshMax) = sourceNode.boundingBox
            let meshCenterLocal = SCNVector3(
                (meshMin.x + meshMax.x) * 0.5,
                (meshMin.y + meshMax.y) * 0.5,
                (meshMin.z + meshMax.z) * 0.5
            )
            let worldCenter = sourceNode.convertPosition(meshCenterLocal, to: nil)
            
            let worldTransform = anchorNode.worldTransform
            let col0 = simd_float3(worldTransform.m11, worldTransform.m12, worldTransform.m13)
            let worldScale = simd_length(col0)
            
            // 以空根节点作为“球心节点”，把原始网格子树平移到以球心为原点
            // 这样后续 applyBallLayout 只改 ballRoot.position 就不会出现网格跑到台外
            anchorNode.removeFromParentNode()
            let originalBall = SCNNode()
            originalBall.name = name
            originalBall.transform = SCNMatrix4Identity
            originalBall.scale = SCNVector3(worldScale, worldScale, worldScale)
            
            let centerInAnchor = sourceNode.convertPosition(meshCenterLocal, to: anchorNode)
            anchorNode.position = SCNVector3(-centerInAnchor.x, -centerInAnchor.y, -centerInAnchor.z)
            originalBall.addChildNode(anchorNode)
            
            // ballRoot 位置就是球心位置
            originalBall.position = SCNVector3(worldCenter.x, correctY, worldCenter.z)
            
            // 二次校正：确保 mesh 的视觉中心与 ballRoot 重合（消除模型局部偏移）
            if let meshNode = firstGeometryNode(in: originalBall) {
                let (mmn, mmx) = meshNode.boundingBox
                let meshCenterLocal2 = SCNVector3(
                    (mmn.x + mmx.x) * 0.5,
                    (mmn.y + mmx.y) * 0.5,
                    (mmn.z + mmx.z) * 0.5
                )
                let visualCenterWorld = meshNode.convertPosition(meshCenterLocal2, to: nil)
                let deltaWorld = SCNVector3(
                    worldCenter.x - visualCenterWorld.x,
                    worldCenter.y - visualCenterWorld.y,
                    worldCenter.z - visualCenterWorld.z
                )
                let invScale = worldScale > 0.0001 ? (1.0 / worldScale) : 1.0
                // root 无旋转，仅有均匀缩放；将世界偏移换算到 root 局部
                anchorNode.position = anchorNode.position + deltaWorld * invScale
            }
            recenterBallVisualIfNeeded(originalBall)
            
            // 验证：3D 模型球的视觉半径（世界空间）是否与 BallPhysics.radius 一致
            if let meshNode = firstGeometryNode(in: originalBall) {
                let (mmn, mmx) = meshNode.boundingBox
                let localHalfX = (mmx.x - mmn.x) * 0.5
                let localHalfY = (mmx.y - mmn.y) * 0.5
                let localHalfZ = (mmx.z - mmn.z) * 0.5
                let localRadius = max(localHalfX, localHalfY, localHalfZ)
                let worldVisualRadius = Float(localRadius) * worldScale
                let expectedRadius = BallPhysics.radius
                let tolerance: Float = 0.0005  // 0.5mm
                let match = abs(worldVisualRadius - expectedRadius) <= tolerance
                if match { ballSizeVerified += 1 } else { ballSizeMismatch += 1 }
                print("[BilliardScene] 球 '\(name)' 尺寸验证: 模型世界半径=\(String(format: "%.5f", worldVisualRadius))m, 物理常数=\(String(format: "%.5f", expectedRadius))m, 一致=\(match ? "✓" : "✗")")
            }
            
            print("[BilliardScene] 球 '\(name)': scale=\(worldScale), renderable=\(hasRenderableGeometry(originalBall)), center=\(originalBall.position)")
            
            let physRadius = worldScale > 0.001 ? CGFloat(BallPhysics.radius / worldScale) : CGFloat(BallPhysics.radius)
            let physicsBody = SCNPhysicsBody(
                type: .dynamic,
                shape: SCNPhysicsShape(geometry: SCNSphere(radius: physRadius), options: nil)
            )
            physicsBody.mass = CGFloat(BallPhysics.mass)
            physicsBody.restitution = CGFloat(BallPhysics.restitution)
            physicsBody.friction = CGFloat(BallPhysics.friction)
            physicsBody.rollingFriction = CGFloat(BallPhysics.rollingDamping)
            physicsBody.angularDamping = CGFloat(BallPhysics.angularDamping)
            physicsBody.damping = CGFloat(BallPhysics.linearDamping)
            physicsBody.isAffectedByGravity = false
            originalBall.physicsBody = physicsBody
            
            rootNode.addChildNode(originalBall)
            
            if name == "_0" {
                originalBall.name = "cueBall"
                cueBallNode = originalBall
                
                let cueBallPos = SCNVector3(
                    BilliardScene.headStringX,
                    correctY,
                    0
                )
                cueBallNode.position = cueBallPos
                initialBallPositions["cueBall"] = cueBallPos
                allBallNodes["cueBall"] = originalBall
                
                print("[BilliardScene] 白球(_0) 已设为母球，位于置球点: \(cueBallPos)")
            } else {
                let correctedPos = SCNVector3(worldCenter.x, correctY, worldCenter.z)
                targetBallNodes.append(originalBall)
                initialBallPositions[name] = correctedPos
                allBallNodes[name] = originalBall
            }
        }
        
        // 清除 tableVisual 中同名残留球节点
        var removedResidual = 0
        for name in ballNames {
            while let residual = visualNode.childNode(withName: name, recursively: true) {
                residual.removeFromParentNode()
                removedResidual += 1
            }
        }
        
        if removedResidual > 0 {
            print("[BilliardScene] 🧹 清除了 \(removedResidual) 个残留球视觉副本")
        }
        
        print("[BilliardScene] 🎱 从模型中提取了 \(foundCount) / 16 个球节点")
        if foundCount > 0 {
            print("[BilliardScene] 📐 球尺寸验证汇总: \(ballSizeVerified)/\(foundCount) 与 BallPhysics.radius(\(String(format: "%.5f", BallPhysics.radius))m) 一致" + (ballSizeMismatch > 0 ? ", \(ballSizeMismatch) 个不一致" : ""))
        }
        
        if cueBallNode == nil {
            print("[BilliardScene] ❌ 模型中未找到白球(_0)，请检查 USDZ 模型")
        }
        
        if let cb = cueBallNode {
            print("[BilliardScene]   母球: pos=\(cb.position), scale=\(cb.scale)")
        }
        for ball in targetBallNodes.prefix(3) {
            print("[BilliardScene]   目标球 '\(ball.name ?? "?")': pos=\(ball.position), scale=\(ball.scale)")
        }
        if targetBallNodes.count > 3 {
            print("[BilliardScene]   ... 和其余 \(targetBallNodes.count - 3) 个目标球")
        }
        
        let uniqueXZCount = Set(
            targetBallNodes.map {
                "\(Int(($0.position.x * 1000).rounded()))_\(Int(($0.position.z * 1000).rounded()))"
            }
        ).count
        print("[BilliardScene]   目标球唯一 XZ 坐标数: \(uniqueXZCount) / \(targetBallNodes.count)")
        
        modelInitialBallPositions = initialBallPositions
        sanitizeBallLayout()
        
        enhanceBallMaterials()
    }
    
    /// 增强所有球体的 PBR 材质 + 接触阴影
    private func enhanceBallMaterials() {
        var allBalls: [SCNNode] = []
        if let cb = cueBallNode { allBalls.append(cb) }
        allBalls.append(contentsOf: targetBallNodes)

        for ballNode in allBalls {
            MaterialFactory.applyBallMaterial(to: ballNode)
            attachShadow(to: ballNode)
        }
        print("[BilliardScene] ✨ 已增强 \(allBalls.count) 个球的 PBR 材质 + 接触阴影")
    }
    
    /// 获取球节点的真实视觉中心（世界坐标）
    func visualCenter(of ballRoot: SCNNode) -> SCNVector3 {
        func firstGeometryNode(in node: SCNNode) -> SCNNode? {
            if node.geometry != nil { return node }
            for child in node.childNodes {
                if let found = firstGeometryNode(in: child) { return found }
            }
            return nil
        }
        
        guard let mesh = firstGeometryNode(in: ballRoot) else { return ballRoot.position }
        let (mn, mx) = mesh.boundingBox
        let centerLocal = SCNVector3(
            (mn.x + mx.x) * 0.5,
            (mn.y + mx.y) * 0.5,
            (mn.z + mx.z) * 0.5
        )
        return mesh.convertPosition(centerLocal, to: nil)
    }
    
    /// 将球节点移动到指定视觉中心（世界坐标）
    func alignVisualCenter(of ballRoot: SCNNode, to desiredCenter: SCNVector3) {
        let current = visualCenter(of: ballRoot)
        let delta = desiredCenter - current
        ballRoot.position = ballRoot.position + delta
    }
    
    /// 保证球的“视觉中心”与根节点重合，避免出现台外偏移/重叠错觉
    private func recenterBallVisualIfNeeded(_ ballRoot: SCNNode) {
        func firstGeometryNode(in node: SCNNode) -> SCNNode? {
            if node.geometry != nil { return node }
            for child in node.childNodes {
                if let found = firstGeometryNode(in: child) { return found }
            }
            return nil
        }
        
        guard let mesh = firstGeometryNode(in: ballRoot) else { return }
        let (mn, mx) = mesh.boundingBox
        let centerLocal = SCNVector3(
            (mn.x + mx.x) * 0.5,
            (mn.y + mx.y) * 0.5,
            (mn.z + mx.z) * 0.5
        )
        let centerInRoot = mesh.convertPosition(centerLocal, to: ballRoot)
        
        let eps: Float = 0.0005
        guard abs(centerInRoot.x) > eps || abs(centerInRoot.y) > eps || abs(centerInRoot.z) > eps else { return }
        
        for child in ballRoot.childNodes {
            child.position = child.position - centerInRoot
        }
    }
    
    /// 应用训练用球布局：仅显示并定位指定球，其余目标球隐藏；nil 或空则恢复模型默认 16 球
    func applyBallLayout(_ positions: [BallPosition]?) {
        guard let positions = positions, !positions.isEmpty else {
            initialBallPositions = modelInitialBallPositions
            for (_, node) in allBallNodes {
                node.isHidden = false
            }
            targetBallNodes = allBallNodes.filter { $0.key != "cueBall" }.map { $0.value }
            cueBallNode = allBallNodes["cueBall"]
            return
        }
        let correctY = TablePhysics.height + BallPhysics.radius
        var newInitial: [String: SCNVector3] = [:]
        let usedTargetNumbers = Set(positions.filter { $0.ballNumber != 0 }.map { $0.ballNumber })
        for bp in positions {
            let key = bp.ballNumber == 0 ? "cueBall" : "_\(bp.ballNumber)"
            guard let node = allBallNodes[key] else { continue }
            recenterBallVisualIfNeeded(node)
            let pos = SCNVector3(bp.position.x, correctY, bp.position.z)
            node.position = pos
            alignVisualCenter(of: node, to: pos)
            node.isHidden = false
            newInitial[key] = pos
            if let shadow = shadowNodes[key] {
                shadow.isHidden = false
                shadow.position = SCNVector3(pos.x, TablePhysics.height + 0.002, pos.z)
            }
        }
        for num in 1...15 where !usedTargetNumbers.contains(num) {
            let key = "_\(num)"
            if let node = allBallNodes[key] {
                node.isHidden = true
            }
            shadowNodes[key]?.isHidden = true
        }
        sanitizeBallLayout()
        for (key, node) in allBallNodes where !node.isHidden {
            newInitial[key] = node.position
        }
        initialBallPositions = newInitial
        targetBallNodes = allBallNodes
            .filter { $0.key != "cueBall" && !($0.value.isHidden) }
            .map { $0.value }
        cueBallNode = allBallNodes["cueBall"]
        print("[BilliardScene] applyBallLayout: \(positions.count) 球")
    }
    
    // MARK: - Ball Management
    
    /// 恢复母球（从 allBallNodes 中取回 USDZ 模型球，重新加入场景）
    /// 用于母球落袋后恢复，不创建程序化球
    func restoreCueBall(at position: SCNVector3? = nil) {
        let defaultPosition = position ?? SCNVector3(
            BilliardScene.headStringX,
            TablePhysics.height + BallPhysics.radius,
            0
        )
        
        guard let ball = allBallNodes["cueBall"] else {
            print("[BilliardScene] ❌ allBallNodes 中无母球，无法恢复")
            return
        }
        
        if ball.parent == nil {
            rootNode.addChildNode(ball)
        }
        ball.opacity = 1.0
        ball.isHidden = false
        ball.position = defaultPosition
        cueBallNode = ball
        
        if let shadow = shadowNodes["cueBall"] {
            shadow.isHidden = false
            shadow.position = SCNVector3(defaultPosition.x, TablePhysics.height + 0.002, defaultPosition.z)
        }
        
        alignVisualCenter(of: ball, to: defaultPosition)
        initialBallPositions["cueBall"] = defaultPosition
    }
    
    // MARK: - Camera Control

    func setCameraMode(_ mode: CameraMode, animated: Bool = true) {
        currentCameraMode = mode
        guard let cameraRig else { return }

        switch mode {
        case .topDown2D:
            cameraNode.camera?.usesOrthographicProjection = true
            cameraNode.camera?.orthographicScale = TrainingCameraConfig.topDownOrthographicScale
            if animated {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = TrainingCameraConfig.transitionDuration
                SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            }
            // 固定长边俯视：台面正上方，视线朝下（-Y），长边（X 轴 2.54m）水平
            cameraNode.position = SCNVector3(0, TablePhysics.height + 3.2, 0)
            cameraNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
            if animated { SCNTransaction.commit() }
        case .aim, .action:
            cameraNode.camera?.usesOrthographicProjection = false
            cameraNode.camera?.fieldOfView = TrainingCameraConfig.aimFov
            if let cueBall = cueBallNode {
                cameraRig.targetPivot = SCNVector3(cueBall.position.x, TablePhysics.height, cueBall.position.z)
            }
            if mode == .aim {
                cameraRig.returnToAim(zoom: savedAimZoom, animated: animated)
            } else {
                cameraRig.pushToObservation(animated: animated)
            }
        }
    }

    var currentCameraZoom: Float {
        cameraRig?.zoom ?? 0
    }

    func setAimDirectionForCamera(_ aimDirection: SCNVector3) {
        aimingController?.syncCameraToAimDirection(aimDirection)
    }

    func updateCameraRig(deltaTime: Float, cueBallPosition: SCNVector3) {
        guard currentCameraMode != .topDown2D, let cameraRig else { return }

        let camState = cameraStateMachine.currentState

        switch camState {
        case .aiming, .adjusting:
            let currentXZ = SIMD2<Float>(cueBallPosition.x, cueBallPosition.z)
            let moved: Bool
            if let last = lastTrackedCueBallXZ {
                moved = simd_distance(last, currentXZ) > 0.001
            } else {
                moved = true
            }
            if moved {
                lastTrackedCueBallXZ = currentXZ
                cameraRig.targetPivot = SCNVector3(cueBallPosition.x, TablePhysics.height, cueBallPosition.z)
            }
        case .observing:
            observationController?.updateObservation(cueBallPosition: cueBallPosition)
        case .returnToAim:
            if !cameraRig.isTransitioning {
                cameraStateMachine.handleEvent(.returnAnimationCompleted)
            }
        case .shooting:
            break
        }

        cameraRig.update(deltaTime: deltaTime)
    }

    /// 获取所有目标球的世界坐标（供动态灵敏度计算）
    func targetBallPositions() -> [SCNVector3] {
        targetBallNodes.compactMap { node -> SCNVector3? in
            guard node.parent != nil else { return nil }
            return visualCenter(of: node)
        }
    }

    func applyCameraPan(deltaX: Float, deltaY: Float) {
        if currentCameraMode == .topDown2D {
            guard let camera = cameraNode.camera else { return }
            let scale = Float(camera.orthographicScale)
            let panSpeed: Float = scale * 0.003
            let pos = cameraNode.position
            cameraNode.position = SCNVector3(
                pos.x - deltaX * panSpeed,
                pos.y,
                pos.z - deltaY * panSpeed
            )
            return
        }
        cameraRig?.handleHorizontalSwipe(delta: deltaX)
        cameraRig?.handleVerticalSwipe(delta: -deltaY)
    }

    func applyCameraPinch(scale: Float) {
        cameraRig?.handlePinch(scale: scale)
    }

    /// 2D 区域缩放：以捏合中心为锚点，直接应用（无插值延迟）
    func applyTopDownAreaZoom(scale: Float, anchorScreen: CGPoint, in view: SCNView) {
        guard let camera = cameraNode.camera else { return }
        let oldScale = camera.orthographicScale
        let newScale = max(
            TrainingCameraConfig.topDownMinOrthographicScale,
            min(TrainingCameraConfig.topDownMaxOrthographicScale, oldScale / Double(scale))
        )

        let viewW = Double(view.bounds.width)
        let viewH = Double(view.bounds.height)
        guard viewW > 1, viewH > 1 else { return }

        let nx = Double(anchorScreen.x) / viewW - 0.5
        let ny = -(Double(anchorScreen.y) / viewH - 0.5)
        let aspect = viewW / viewH

        let shift = SCNVector3(
            Float((oldScale - newScale) * 2.0 * aspect * nx),
            0,
            Float(-(oldScale - newScale) * 2.0 * ny)
        )

        camera.orthographicScale = newScale
        let pos = cameraNode.position
        cameraNode.position = SCNVector3(pos.x + shift.x, pos.y, pos.z + shift.z)
    }

    /// 每帧调用（2D 模式占位，当前缩放已直接生效无需插值）
    func updateTopDownZoom() {}

    func shouldLinkAimDirectionWithCamera() -> Bool {
        currentCameraMode != .topDown2D
    }

    func currentAimDirectionFromCamera() -> SCNVector3 {
        aimingController?.aimDirectionFromCamera() ?? SCNVector3(-1, 0, 0)
    }

    /// Anchored orbit：锁定白球在屏幕中的投影位置（Aim/Adjusting 态）
    func lockCueBallScreenAnchor(in view: SCNView, cueBallWorld: SCNVector3, anchorNormalized: CGPoint) {
        guard currentCameraMode != .topDown2D else { return }
        let camState = cameraStateMachine.currentState
        guard (camState == .aiming || camState == .adjusting), let cameraRig else { return }
        let projected = view.projectPoint(cueBallWorld)
        guard projected.z.isFinite else { return }

        let width = view.bounds.width
        let height = view.bounds.height
        guard width > 1, height > 1 else { return }

        func uiToSceneY(_ uiY: CGFloat) -> CGFloat { height - uiY }

        let currentUI = CGPoint(x: CGFloat(projected.x), y: height - CGFloat(projected.y))
        let targetUI = CGPoint(x: width * anchorNormalized.x, y: height * anchorNormalized.y)
        let error = hypot(targetUI.x - currentUI.x, targetUI.y - currentUI.y)
        if error < 0.5 { return }

        let currentScenePoint = SCNVector3(
            Float(currentUI.x),
            Float(uiToSceneY(currentUI.y)),
            projected.z
        )
        let targetScenePoint = SCNVector3(
            Float(targetUI.x),
            Float(uiToSceneY(targetUI.y)),
            projected.z
        )

        let worldAtCurrent = view.unprojectPoint(currentScenePoint)
        let worldAtTarget = view.unprojectPoint(targetScenePoint)
        let correction = worldAtCurrent - worldAtTarget

        cameraRig.translatePivot(
            deltaXZ: SCNVector3(correction.x, 0, correction.z),
            immediate: true
        )
    }

    func saveCurrentAimZoom() {
        savedAimZoom = cameraRig?.zoom ?? savedAimZoom
    }

    /// 击球后进入观察视角（通过状态机驱动）
    func setCameraPostShot(cueBallPosition: SCNVector3, aimDirection: SCNVector3) {
        lastTrackedCueBallXZ = nil
        saveCurrentAimZoom()
        cameraStateMachine.saveAimContext(aimDirection: aimDirection, zoom: savedAimZoom)

        if TrainingCameraConfig.observationViewEnabled {
            currentCameraMode = .action
            observationController?.enterObservation(
                cueBallPosition: cueBallPosition,
                aimDirection: aimDirection
            )
        }
    }

    /// 球停后开始回归瞄准态
    func beginReturnToAim(cueBallPosition: SCNVector3, targetDirection: SCNVector3? = nil) {
        currentCameraMode = .aim

        let savedDir = targetDirection ?? cameraStateMachine.savedAimDirection
        let savedZoom = cameraStateMachine.savedAimZoom
        let targetYaw = autoAlignController?.yawFromDirection(savedDir) ?? 0

        observationController?.beginReturnToAim(
            cueBallPosition: cueBallPosition,
            savedZoom: savedZoom,
            targetYaw: targetYaw
        )
    }

    func returnCameraToAim(animated: Bool) {
        setCameraMode(.aim, animated: animated)
    }
    
    // MARK: - Ball Surface Constraint
    
    /// 每帧调用：约束所有球贴合台面（消除 Y 方向的任何漂移或弹跳）
    func constrainBallsToSurface() {
        let surfaceY = TablePhysics.height + BallPhysics.radius
        let shadowY = TablePhysics.height + 0.002
        
        func constrain(_ ball: SCNNode) {
            guard ball.parent != nil else { return }  // 已进袋的球跳过
            
            // 强制 Y 位置贴合台面
            if abs(ball.position.y - surfaceY) > 0.0001 {
                ball.position.y = surfaceY
            }
            
            // 清除 Y 方向速度（防止垂直运动）
            if let body = ball.physicsBody {
                let vel = body.velocity
                if abs(vel.y) > 0.0001 {
                    body.velocity = SCNVector3(vel.x, 0, vel.z)
                }
            }
            
            if let name = ball.name, let shadow = shadowNodes[name] {
                shadow.position = SCNVector3(ball.position.x, shadowY, ball.position.z)
            }
        }
        
        if let cueBall = cueBallNode {
            constrain(cueBall)
        }
        for ball in targetBallNodes {
            constrain(ball)
        }
    }
    
    /// 每帧更新阴影位置（兼容 SCNAction 播放中的 presentation 位置）
    func updateShadowPositions() {
        let shadowY = TablePhysics.height + 0.002
        for (name, shadow) in shadowNodes {
            guard let ball = allBallNodes[name], ball.parent != nil else { continue }
            let pos = ball.presentation.position
            shadow.position = SCNVector3(pos.x, shadowY, pos.z)
        }
    }
    
    // MARK: - Aim Line
    
    /// 显示瞄准线
    func showAimLine(from start: SCNVector3, direction: SCNVector3, length: Float) {
        let lineNode: SCNNode
        if let existing = aimLineNode {
            lineNode = existing
        } else {
            let lineGeometry = SCNCylinder(radius: 0.0015, height: CGFloat(length))
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.white.withAlphaComponent(0.8)
            material.emission.contents = UIColor.white.withAlphaComponent(0.3)
            lineGeometry.materials = [material]
            let node = SCNNode(geometry: lineGeometry)
            rootNode.addChildNode(node)
            aimLineNode = node
            lineNode = node
        }

        if let cylinder = lineNode.geometry as? SCNCylinder {
            cylinder.height = CGFloat(length)
        }

        lineNode.position = start + direction * (length / 2)
        
        // 旋转使圆柱体指向方向
        let up = SCNVector3(0, 1, 0)
        let axis = up.cross(direction).normalized()
        let angle = acos(up.dot(direction))
        lineNode.rotation = SCNVector4(axis.x, axis.y, axis.z, angle)
        lineNode.isHidden = false
    }
    
    /// 隐藏瞄准线
    func hideAimLine() {
        aimLineNode?.isHidden = true
    }
    
    // MARK: - Predicted Trajectory
    
    /// 显示预测轨迹线
    /// - Parameters:
    ///   - cueBallPath: 母球碰后预测路径点
    ///   - targetBallPath: 目标球预测路径点（可选）
    func showPredictedTrajectory(cueBallPath: [SCNVector3], targetBallPath: [SCNVector3]?) {
        hidePredictedTrajectory()
        
        // 母球碰后路径 — 白色虚线
        if cueBallPath.count >= 2 {
            let nodes = createDottedLine(
                points: cueBallPath,
                color: UIColor.white.withAlphaComponent(0.5),
                dotRadius: 0.003,
                dotSpacing: 0.03
            )
            predictedTrajectoryNodes.append(contentsOf: nodes)
        }
        
        // 目标球路径 — 黄色虚线
        if let targetPath = targetBallPath, targetPath.count >= 2 {
            let nodes = createDottedLine(
                points: targetPath,
                color: UIColor.yellow.withAlphaComponent(0.6),
                dotRadius: 0.003,
                dotSpacing: 0.03
            )
            predictedTrajectoryNodes.append(contentsOf: nodes)
        }
        
        for node in predictedTrajectoryNodes {
            rootNode.addChildNode(node)
        }
    }
    
    /// 隐藏预测轨迹线
    func hidePredictedTrajectory() {
        for node in predictedTrajectoryNodes {
            node.removeFromParentNode()
        }
        predictedTrajectoryNodes.removeAll()
    }
    
    /// 创建虚线（一系列小球点组成的路径）
    private func createDottedLine(points: [SCNVector3], color: UIColor, dotRadius: CGFloat, dotSpacing: Float) -> [SCNNode] {
        var nodes: [SCNNode] = []
        let dotGeometry = SCNSphere(radius: dotRadius)
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.emission.contents = color.withAlphaComponent(0.2)
        dotGeometry.materials = [material]
        
        for i in 0..<(points.count - 1) {
            let start = points[i]
            let end = points[i + 1]
            let segment = end - start
            let segmentLength = segment.length()
            guard segmentLength > 0.001 else { continue }
            let dir = segment.normalized()
            
            var dist: Float = 0
            while dist < segmentLength {
                let pos = start + dir * dist
                let dotNode = SCNNode(geometry: dotGeometry)
                dotNode.position = pos
                nodes.append(dotNode)
                dist += dotSpacing
            }
        }
        
        return nodes
    }
    
    /// 显示幽灵球
    func showGhostBall(at position: SCNVector3) {
        if ghostBallNode == nil {
            let ghostGeometry = SCNSphere(radius: CGFloat(BallPhysics.radius))
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.white.withAlphaComponent(0.4)
            material.emission.contents = UIColor.white.withAlphaComponent(0.1)
            ghostGeometry.materials = [material]
            ghostBallNode = SCNNode(geometry: ghostGeometry)
            ghostBallNode?.name = "ghostBall"
            if let node = ghostBallNode {
                rootNode.addChildNode(node)
            }
        }
        ghostBallNode?.position = position
        ghostBallNode?.isHidden = false
    }
    
    /// 隐藏幽灵球
    func hideGhostBall() {
        ghostBallNode?.isHidden = true
    }

    // MARK: - Ball Selection Highlight

    private static let selectionRingName = "_selectionRing"

    /// 在目标球下方添加选中高亮环
    func addSelectionHighlight(to node: SCNNode) {
        removeSelectionHighlight(from: node)
        let ring = SCNTorus(ringRadius: CGFloat(BallPhysics.radius * 1.3), pipeRadius: 0.002)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.systemYellow
        mat.emission.contents = UIColor.systemYellow
        ring.materials = [mat]
        let ringNode = SCNNode(geometry: ring)
        ringNode.name = BilliardScene.selectionRingName
        ringNode.position = SCNVector3(0, -BallPhysics.radius + 0.002, 0)
        node.addChildNode(ringNode)
    }

    /// 移除目标球的选中高亮环
    func removeSelectionHighlight(from node: SCNNode) {
        node.childNodes
            .filter { $0.name == BilliardScene.selectionRingName }
            .forEach { $0.removeFromParentNode() }
    }
    
    private func attachShadow(to ball: SCNNode) {
        guard let name = ball.name, shadowNodes[name] == nil else { return }

        let radius = CGFloat(BallPhysics.radius * 2.2)
        let shadowPlane = SCNPlane(width: radius * 2, height: radius * 2)
        let material = SCNMaterial()
        material.diffuse.contents = MaterialFactory.generateContactShadowTexture(size: 128)
        material.isDoubleSided = true
        material.writesToDepthBuffer = false
        material.lightingModel = .constant
        material.transparencyMode = .aOne
        shadowPlane.materials = [material]

        let shadowNode = SCNNode(geometry: shadowPlane)
        shadowNode.name = "\(name)_shadow"
        shadowNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        shadowNode.position = SCNVector3(ball.position.x, TablePhysics.height + 0.002, ball.position.z)
        shadowNode.renderingOrder = -1
        rootNode.addChildNode(shadowNode)
        shadowNodes[name] = shadowNode
    }
    
    /// 隐藏指定球的影子
    func hideShadow(for ballName: String) {
        shadowNodes[ballName]?.isHidden = true
    }
    
    /// 从 targetBallNodes 数组中移除指定球（进袋后清理引用）
    func removeTargetBall(named name: String) {
        targetBallNodes.removeAll { $0.name == name }
    }
    
    /// 清空母球引用（母球进袋后调用）
    func clearCueBallReference() {
        cueBallNode = nil
    }
    
    /// 移动母球到指定位置（placing 模式）
    /// - Returns: 移动是否成功（不与其他球重叠时成功）
    @discardableResult
    func moveCueBall(to position: SCNVector3, checkCollision: Bool = true) -> Bool {
        guard let cueBall = cueBallNode else { return false }
        
        let R = BallPhysics.radius
        let halfL = TablePhysics.innerLength / 2
        let halfW = TablePhysics.innerWidth / 2
        
        // 台面边界约束
        let clampedX = max(-halfL + R, min(halfL - R, position.x))
        let clampedZ = max(-halfW + R, min(halfW - R, position.z))
        let surfaceY = TablePhysics.height + R
        let targetPos = SCNVector3(clampedX, surfaceY, clampedZ)
        
        if checkCollision {
            let minDist = R * 2 + 0.002
            for ball in targetBallNodes {
                guard ball.parent != nil, !ball.isHidden else { continue }
                let dx = ball.position.x - targetPos.x
                let dz = ball.position.z - targetPos.z
                if dx * dx + dz * dz < minDist * minDist {
                    return false
                }
            }
        }
        
        cueBall.position = targetPos
        if let shadow = shadowNodes["cueBall"] {
            shadow.position = SCNVector3(targetPos.x, TablePhysics.height + 0.002, targetPos.z)
        }
        return true
    }
    
    /// 获取袋口列表
    func pockets() -> [Pocket] {
        return tableGeometry.pockets
    }
    
    // MARK: - Rack Layout (Chinese Eight-Ball)
    
    /// 设置标准中式八球三角阵摆球
    /// 15 颗目标球排成三角形（5行：1+2+3+4+5），白球在开球线后
    /// 规则：8号球在第3行中间，底边两角分别为一颗全色球和一颗花色球
    func setupRackLayout() {
        let R = BallPhysics.radius
        // 开球三角应紧密贴球；过大间隙会导致只撞动第一颗，无法传递
        let gap: Float = 0.0008
        let rowOffset = (R * 2 + gap) * sqrt(3.0) / 2.0
        
        // 置球点 (foot spot): 台面左半区 1/4 处，三角阵从这里向 -X 展开（远离白球）
        let footSpotX = -TablePhysics.innerLength / 4
        // 开球线 (head string): 台面右半区 1/4 处，白球放这里
        let headX = BilliardScene.headStringX
        
        // 生成 15 个三角阵格子坐标 (row=0 顶球 → row=4 底边)
        var slots: [(x: Float, z: Float)] = []
        for row in 0..<5 {
            let ballsInRow = row + 1
            for col in 0..<ballsInRow {
                let x = footSpotX - Float(row) * rowOffset
                let zStart = Float(row) * (R + gap / 2)
                let z = zStart - Float(col) * (R * 2 + gap)
                slots.append((x, z))
            }
        }
        
        // 球号分配: 8号 → slot 4 (row2 中间)，底边两角一全一花
        var solids = Array(1...7).shuffled()
        var stripes = Array(9...15).shuffled()
        var assignment = Array(repeating: 0, count: 15)
        
        // 8号球: row=2, col=1 → slot index 4
        assignment[4] = 8
        
        // 底边两角: slot 10 (row4 col0) 和 slot 14 (row4 col4)
        let cornerSolid = solids.removeLast()
        let cornerStripe = stripes.removeLast()
        if Bool.random() {
            assignment[10] = cornerSolid
            assignment[14] = cornerStripe
        } else {
            assignment[10] = cornerStripe
            assignment[14] = cornerSolid
        }
        
        var remaining = (solids + stripes).shuffled()
        for i in 0..<15 where assignment[i] == 0 {
            assignment[i] = remaining.removeFirst()
        }
        
        // 构建 BallPosition 数组
        var positions: [BallPosition] = []
        
        // 白球: 开球线后
        positions.append(BallPosition(ballNumber: 0, x: headX, z: 0))
        
        // 15 颗目标球
        for (i, slot) in slots.enumerated() {
            positions.append(BallPosition(ballNumber: assignment[i], x: slot.x, z: slot.z))
        }
        
        print("[BilliardScene] setupRackLayout: 白球 x=\(headX), 三角阵顶球 x=\(footSpotX), allBallNodes 数量=\(allBallNodes.count)")
        applyBallLayout(positions)
    }

    /// 修正布局中的球体重叠，避免出现穿插导致的“无碰撞”
    func sanitizeBallLayout(iterations: Int = 10) {
        let R = BallPhysics.radius
        let minCenterDist = R * 2 + 0.0005
        let minCenterDistSq = minCenterDist * minCenterDist
        let halfL = TablePhysics.innerLength / 2 - R
        let halfW = TablePhysics.innerWidth / 2 - R

        var balls: [SCNNode] = []
        if let cue = cueBallNode, cue.parent != nil, !cue.isHidden { balls.append(cue) }
        balls.append(contentsOf: targetBallNodes.filter { $0.parent != nil && !$0.isHidden })
        guard balls.count >= 2 else { return }

        for _ in 0..<iterations {
            var adjusted = false

            for i in 0..<(balls.count - 1) {
                for j in (i + 1)..<balls.count {
                    let a = balls[i]
                    let b = balls[j]
                    let pa = visualCenter(of: a)
                    let pb = visualCenter(of: b)

                    var dx = pb.x - pa.x
                    var dz = pb.z - pa.z
                    let d2 = dx * dx + dz * dz
                    if d2 >= minCenterDistSq { continue }

                    let dist = sqrtf(max(d2, 1e-10))
                    if dist < 1e-5 {
                        dx = 1
                        dz = 0
                    } else {
                        dx /= dist
                        dz /= dist
                    }

                    let overlap = minCenterDist - max(dist, 1e-5)
                    let push = overlap * 0.5
                    let pushVec = SCNVector3(dx * push, 0, dz * push)

                    let desiredA = SCNVector3(
                        max(-halfL, min(halfL, pa.x - pushVec.x)),
                        TablePhysics.height + R,
                        max(-halfW, min(halfW, pa.z - pushVec.z))
                    )
                    let desiredB = SCNVector3(
                        max(-halfL, min(halfL, pb.x + pushVec.x)),
                        TablePhysics.height + R,
                        max(-halfW, min(halfW, pb.z + pushVec.z))
                    )

                    alignVisualCenter(of: a, to: desiredA)
                    alignVisualCenter(of: b, to: desiredB)
                    adjusted = true
                }
            }

            if !adjusted { break }
        }
    }
    
    /// 获取开球线 X 坐标（head string line）
    /// 开球时白球必须位于此线右侧（x > headStringX 的正半区）
    static var headStringX: Float {
        TablePhysics.innerLength / 4
    }

    // MARK: - Render Feature Toggle (A/B comparison)

    /// Toggle a render feature on/off for screenshot comparison.
    func setRenderFeature(_ feature: RenderFeature, enabled: Bool) {
        RenderQualityManager.shared.setOverride(feature, enabled: enabled)
        reapplyRenderSettings()
    }

    /// Clear all feature overrides and restore tier defaults.
    func clearRenderOverrides() {
        RenderQualityManager.shared.clearAllOverrides()
        reapplyRenderSettings()
    }

    /// Reapply all rendering settings to reflect current tier / overrides.
    func reapplyRenderSettings() {
        setupEnvironment()
        reapplyLightSettings()
        reapplyCameraSettings()
        enhanceBallMaterials()
        MaterialFactory.enhanceClothMaterials(in: tableNode)
        MaterialFactory.enhanceRailMaterials(in: tableNode)
        MaterialFactory.enhancePocketMaterials(in: tableNode)
    }

    private func reapplyLightSettings() {
        let flags = RenderQualityManager.shared.featureFlags
        for node in lightNodes {
            guard let light = node.light else { continue }
            if light.type == .directional {
                light.shadowMapSize = CGSize(width: flags.shadowMapSize, height: flags.shadowMapSize)
                light.shadowSampleCount = flags.shadowSampleCount
                light.shadowRadius = flags.shadowRadius
                light.shadowMode = flags.shadowMode
            }
        }
    }

    private func reapplyCameraSettings() {
        guard let camera = cameraNode.camera else { return }
        let flags = RenderQualityManager.shared.featureFlags

        if flags.ssaoEnabled {
            camera.screenSpaceAmbientOcclusionIntensity = flags.ssaoIntensity
            camera.screenSpaceAmbientOcclusionRadius = flags.ssaoRadius
        } else {
            camera.screenSpaceAmbientOcclusionIntensity = 0
        }

        if flags.bloomEnabled {
            camera.bloomIntensity = flags.bloomIntensity
            camera.bloomThreshold = flags.bloomThreshold
            camera.bloomBlurRadius = 4.0
        } else {
            camera.bloomIntensity = 0
        }

        if flags.toneMappingEnabled {
            camera.exposureOffset = -0.25
            camera.whitePoint = 1.0
        } else {
            camera.exposureOffset = 0
            camera.whitePoint = 1.0
        }
    }
    
    // MARK: - Reset
    
    /// 重置场景（将所有球恢复到初始位置）
    func resetScene() {
        for (name, position) in initialBallPositions {
            guard let ball = allBallNodes[name] else { continue }
            
            // 如果球被移除（进袋），重新添加到场景
            if ball.parent == nil {
                rootNode.addChildNode(ball)
                ball.opacity = 1.0  // 恢复透明度（进袋时会淡出）
            }
            
            // 恢复初始位置
            ball.position = position
        }
        
        // 重新填充 targetBallNodes（进袋时会被移除）
        targetBallNodes = allBallNodes
            .filter { $0.key != "cueBall" }
            .map { $0.value }
        
        // 恢复母球引用
        cueBallNode = allBallNodes["cueBall"]
        
        // 恢复所有影子
        for (name, shadow) in shadowNodes {
            shadow.isHidden = false
            if let ball = allBallNodes[name] {
                shadow.position = SCNVector3(ball.position.x, TablePhysics.height + 0.002, ball.position.z)
            }
        }
        
        savedAimZoom = 0
        cameraRig?.setTargetZoom(0)
        
        hideAimLine()
    }
}

