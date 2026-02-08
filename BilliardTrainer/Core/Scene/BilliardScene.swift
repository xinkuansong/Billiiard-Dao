//
//  BilliardScene.swift
//  BilliardTrainer
//
//  SceneKit 台球场景核心类
//

import SceneKit
import SwiftUI

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
    
    /// 第一人称视角缩放因子（影响相机到母球距离）
    var firstPersonZoomFactor: Float = 1.0
    
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
    private(set) var currentCameraMode: CameraMode = .firstPerson
    
    /// 球台几何描述
    private(set) var tableGeometry: TableGeometry = .chineseEightBall()
    
    /// USDZ 模型提取的球杆节点（供 CueStick 使用）
    private(set) var modelCueStickNode: SCNNode?
    
    // MARK: - Camera Mode
    enum CameraMode: Equatable {
        case firstPerson    // 第一人称击球视角（默认）
        case topDown2D      // 2D俯视
        case perspective3D  // 3D透视
        case shooting       // 击球视角
        case free           // 自由视角
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
        setupTable()
        setupLights()
        setupCamera()
        setupPhysics()
    }
    
    /// 设置环境
    private func setupEnvironment() {
        // 背景色 - 深色环境
        background.contents = UIColor(red: 0.1, green: 0.12, blue: 0.15, alpha: 1.0)
        
        // 环境光照（降低强度，避免 PBR 材质过亮）
        lightingEnvironment.contents = UIColor.darkGray
        lightingEnvironment.intensity = 0.5
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
        
        // 4. 从模型中提取球节点，设置为游戏球（必须在 tableNode 加入 rootNode 之后执行）
        setupModelBalls()
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
    
    /// 设置灯光
    /// 光照配置需要兼容 USDZ 模型的 PBR 材质
    /// 模拟台球室灯光：头顶灯罩投射柔和集中光线，环境光低
    private func setupLights() {
        // 主光源 - 顶部方向光（模拟头顶台球灯）
        let mainLight = SCNLight()
        mainLight.type = .directional
        mainLight.intensity = 150  // 柔和，避免过曝
        mainLight.castsShadow = true
        mainLight.shadowRadius = 5
        mainLight.shadowColor = UIColor.black.withAlphaComponent(0.3)
        mainLight.shadowMapSize = CGSize(width: 2048, height: 2048)
        mainLight.color = UIColor(white: 0.95, alpha: 1.0)  // 略暖白
        
        let mainLightNode = SCNNode()
        mainLightNode.light = mainLight
        mainLightNode.position = SCNVector3(0, 5, 0)
        mainLightNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        rootNode.addChildNode(mainLightNode)
        lightNodes.append(mainLightNode)
        
        // 环境光 - 为 PBR 材质提供基础照明（低强度营造球厅氛围）
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 50  // 较低的环境光，突出台球灯聚光效果
        ambientLight.color = UIColor(white: 0.8, alpha: 1.0)
        
        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight
        rootNode.addChildNode(ambientLightNode)
        lightNodes.append(ambientLightNode)
        
        // 台球灯效果 - 模拟球台上方灯罩的聚光灯
        let fillLight = SCNLight()
        fillLight.type = .spot
        fillLight.intensity = 120  // 降低避免过亮
        fillLight.spotInnerAngle = 60
        fillLight.spotOuterAngle = 90   // 覆盖整张球台
        fillLight.castsShadow = true
        fillLight.shadowRadius = 4
        fillLight.attenuationStartDistance = 3
        fillLight.attenuationEndDistance = 10
        fillLight.color = UIColor(white: 0.95, alpha: 1.0)  // 略暖色温
        
        let fillLightNode = SCNNode()
        fillLightNode.light = fillLight
        fillLightNode.position = SCNVector3(0, 3.5, 0)  // 略低一些更真实
        fillLightNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        rootNode.addChildNode(fillLightNode)
        lightNodes.append(fillLightNode)
    }
    
    /// 设置相机
    private func setupCamera() {
        let camera = SCNCamera()
        camera.zNear = 0.01
        camera.zFar = 100
        camera.fieldOfView = 60
        
        cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.name = "billiard_camera"
        
        rootNode.addChildNode(cameraNode)
        
        // 默认第一人称视角
        setCameraMode(.firstPerson, animated: false)
        
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
            print("[BilliardScene] 未找到 tableVisual 节点，使用程序化母球")
            createCueBall()
            return
        }
        
        let ballNames = (0...15).map { "_\($0)" }
        var foundCount = 0
        
        for name in ballNames {
            guard let originalBall = visualNode.childNode(withName: name, recursively: true) else {
                print("[BilliardScene] 模型中未找到球节点: \(name)")
                continue
            }
            
            foundCount += 1
            
            // 在移除前记录球的世界变换（包含位置、旋转、缩放）
            let worldTransform = originalBall.worldTransform
            let worldPos = SCNVector3(worldTransform.m41, worldTransform.m42, worldTransform.m43)
            
            // 提取世界缩放系数（用于计算物理半径）
            let col0 = simd_float3(worldTransform.m11, worldTransform.m12, worldTransform.m13)
            let worldScale = simd_length(col0)
            
            // 从视觉层移除
            originalBall.removeFromParentNode()
            
            // 设置世界变换（作为 rootNode 的直接子节点，保留旋转和缩放）
            originalBall.transform = worldTransform
            
            // ===== 关键：强制 Y 坐标精确贴合物理台面 =====
            // 碰撞面顶部 = TablePhysics.height，球心 = 顶部 + 球半径
            let correctY = TablePhysics.height + BallPhysics.radius
            originalBall.position = SCNVector3(worldPos.x, correctY, worldPos.z)
            
            print("[BilliardScene] 球 '\(name)': 模型Y=\(worldPos.y), 修正Y=\(correctY)")
            
            // 添加物理体（半径需除以缩放系数，因为物理系统会乘以节点缩放）
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
            physicsBody.isAffectedByGravity = false  // 台球不需要重力，贴台面移动
            originalBall.physicsBody = physicsBody
            
            rootNode.addChildNode(originalBall)
            attachShadow(to: originalBall)
            
            if name == "_0" {
                // _0 = 白球 → 设为母球，移动到置球点
                originalBall.name = "cueBall"
                cueBallNode = originalBall
                
                let cueBallPos = SCNVector3(
                    -TablePhysics.innerLength / 4,
                    correctY,
                    0
                )
                cueBallNode.position = cueBallPos
                initialBallPositions["cueBall"] = cueBallPos
                allBallNodes["cueBall"] = originalBall
                
                print("[BilliardScene] 白球(_0) 已设为母球，位于置球点: \(cueBallPos)")
            } else {
                let correctedPos = SCNVector3(worldPos.x, correctY, worldPos.z)
                targetBallNodes.append(originalBall)
                initialBallPositions[name] = correctedPos
                allBallNodes[name] = originalBall
            }
        }
        
        print("[BilliardScene] 🎱 从模型中提取了 \(foundCount) / 16 个球节点")
        
        // 如果没找到白球，降级创建程序化母球
        if cueBallNode == nil {
            print("[BilliardScene] ⚠️ 模型中未找到白球，创建程序化母球")
            createCueBall()
        }
        
        // 诊断：输出所有球的位置摘要
        if let cb = cueBallNode {
            print("[BilliardScene]   母球位置: \(cb.position), scale: \(cb.scale)")
        }
        for ball in targetBallNodes.prefix(3) {
            print("[BilliardScene]   目标球 '\(ball.name ?? "?")': pos=\(ball.position), scale=\(ball.scale)")
        }
        if targetBallNodes.count > 3 {
            print("[BilliardScene]   ... 和其余 \(targetBallNodes.count - 3) 个目标球")
        }
    }
    
    // MARK: - Ball Management
    
    /// 创建母球（降级方案，模型中无球时使用）
    func createCueBall(at position: SCNVector3? = nil) {
        let defaultPosition = position ?? SCNVector3(
            -TablePhysics.innerLength / 4,
            TablePhysics.height + BallPhysics.radius,
            0
        )
        
        cueBallNode = createBall(
            color: UIColor.white,
            position: defaultPosition,
            name: "cueBall"
        )
        
        rootNode.addChildNode(cueBallNode)
        attachShadow(to: cueBallNode)
    }
    
    /// 创建目标球
    func createTargetBall(number: Int, at position: SCNVector3) {
        let color = getBallColor(number: number)
        let ballNode = createBall(
            color: color,
            position: position,
            name: "ball_\(number)"
        )
        
        // 如果是花色球，添加条纹效果
        if number >= 9 && number <= 15 {
            addStripeToball(ballNode, stripeColor: color)
        }
        
        targetBallNodes.append(ballNode)
        rootNode.addChildNode(ballNode)
    }
    
    /// 创建球体
    private func createBall(color: UIColor, position: SCNVector3, name: String) -> SCNNode {
        let ballGeometry = SCNSphere(radius: CGFloat(BallPhysics.radius))
        
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.specular.contents = UIColor.white
        material.shininess = 0.8
        material.reflective.contents = UIColor.gray.withAlphaComponent(0.3)
        ballGeometry.materials = [material]
        
        let ballNode = SCNNode(geometry: ballGeometry)
        ballNode.name = name
        ballNode.position = position
        
        // 物理体
        let physicsBody = SCNPhysicsBody(
            type: .dynamic,
            shape: SCNPhysicsShape(geometry: ballGeometry, options: nil)
        )
        physicsBody.mass = CGFloat(BallPhysics.mass)
        physicsBody.restitution = CGFloat(BallPhysics.restitution)
        physicsBody.friction = CGFloat(BallPhysics.friction)
        physicsBody.rollingFriction = CGFloat(BallPhysics.rollingDamping)
        physicsBody.angularDamping = CGFloat(BallPhysics.angularDamping)
        physicsBody.damping = CGFloat(BallPhysics.linearDamping)
        physicsBody.isAffectedByGravity = false  // 台球不需要重力
        
        ballNode.physicsBody = physicsBody
        
        attachShadow(to: ballNode)
        
        return ballNode
    }
    
    /// 获取球的颜色
    private func getBallColor(number: Int) -> UIColor {
        switch number {
        case 0:
            return .white  // 母球
        case 8:
            return .black  // 黑八
        case 1...7:
            let colors = BallColors.solidBalls
            let c = colors[number - 1]
            return UIColor(red: c.r, green: c.g, blue: c.b, alpha: 1.0)
        case 9...15:
            let colors = BallColors.stripedBalls
            let c = colors[number - 9]
            return UIColor(red: c.r, green: c.g, blue: c.b, alpha: 1.0)
        default:
            return .gray
        }
    }
    
    /// 为花色球添加条纹
    private func addStripeToball(_ ballNode: SCNNode, stripeColor: UIColor) {
        // 简化版：使用白色底色 + 条纹贴图
        // 实际实现需要创建条纹纹理
        if let geometry = ballNode.geometry as? SCNSphere {
            let material = geometry.firstMaterial
            material?.diffuse.contents = UIColor.white
            // TODO: 添加条纹纹理
        }
    }
    
    // MARK: - Camera Control
    
    /// 设置相机模式
    func setCameraMode(_ mode: CameraMode, animated: Bool = true) {
        currentCameraMode = mode
        
        var newPosition: SCNVector3
        var useLookAt: SCNVector3? = nil  // 如果非 nil，使用 look(at:) 代替 eulerAngles
        var newEulerAngles: SCNVector3 = .init(0, 0, 0)
        var orthographic = false
        
        switch mode {
        case .firstPerson:
            // 第一人称视角 - 相机放在母球后方，朝向母球前方
            // 默认瞄准方向 +X（沿球台长轴）
            if let cueBall = cueBallNode {
                // 相机在母球后方（-X 方向），高于台面，距离受缩放因子影响
                let dist = FirstPersonCamera.distance * firstPersonZoomFactor
                newPosition = SCNVector3(
                    cueBall.position.x - dist,
                    TablePhysics.height + FirstPersonCamera.height,
                    cueBall.position.z
                )
                // 朝向母球前方（+X 方向）
                useLookAt = SCNVector3(
                    cueBall.position.x + 0.3,
                    cueBall.position.y,
                    cueBall.position.z
                )
            } else {
                // 无母球时，默认位置朝向球台中心
                newPosition = SCNVector3(-FirstPersonCamera.distance - 0.6, TablePhysics.height + FirstPersonCamera.height, 0)
                useLookAt = SCNVector3(0, TablePhysics.height, 0)
            }
            
        case .topDown2D:
            // 2D俯视 - 正交投影，从正上方看下去
            // 微小 Z 偏移避免万向锁，负 Z 确保 X 轴朝右（球台长轴朝右对应手机长边）
            newPosition = SCNVector3(0, 4.0, -0.001)
            newEulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
            orthographic = true
            
        case .perspective3D:
            // 3D透视 - 从球台一端沿长轴方向看（平行于球杆方向）
            // 相机位于球台短边外侧，高度略高于台面，看向球台中心
            let halfLength = TablePhysics.innerLength / 2
            newPosition = SCNVector3(-(halfLength + 1.2), 1.8, 0)
            useLookAt = SCNVector3(halfLength * 0.3, TablePhysics.height, 0)
            
        case .shooting:
            // 击球视角 - 从母球后方沿球杆方向看
            if let cueBall = cueBallNode {
                newPosition = SCNVector3(
                    cueBall.position.x - 1.0,
                    cueBall.position.y + 0.3,
                    cueBall.position.z
                )
                useLookAt = SCNVector3(
                    cueBall.position.x + 0.5,
                    cueBall.position.y,
                    cueBall.position.z
                )
            } else {
                newPosition = SCNVector3(-1.5, TablePhysics.height + 0.3, 0)
                useLookAt = SCNVector3(0, TablePhysics.height, 0)
            }
            
        case .free:
            // 自由视角 - 保持当前位置
            return
        }
        
        // 设置投影模式
        cameraNode.camera?.usesOrthographicProjection = orthographic
        if orthographic {
            cameraNode.camera?.orthographicScale = 1.0  // 较小的值 = 球台显示更大
        } else {
            cameraNode.camera?.fieldOfView = 60
        }
        
        // 动画过渡
        if animated {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = CameraSettings.transitionDuration
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        }
        
        cameraNode.position = newPosition
        if let lookTarget = useLookAt {
            cameraNode.look(at: lookTarget)
        } else {
            cameraNode.eulerAngles = newEulerAngles
        }
        
        if animated {
            SCNTransaction.commit()
        }
        
        print("[BilliardScene] setCameraMode(\(mode)): pos=\(cameraNode.position), eulerAngles=\(cameraNode.eulerAngles), orthographic=\(orthographic)")
    }
    
    /// 更新第一人称相机（每帧调用）
    /// - Parameter smooth: 是否使用平滑插值（初始化时应传 false 以立即定位）
    func updateFirstPersonCamera(cueBallPosition: SCNVector3, aimDirection: SCNVector3, pitchAngle: Float, smooth: Bool = true) {
        guard currentCameraMode == .firstPerson else { return }
        
        // 相机位于母球后方（瞄准方向的反方向），距离受缩放因子影响
        let behind = SCNVector3(0, 0, 0) - aimDirection * (FirstPersonCamera.distance * firstPersonZoomFactor)
        
        // 相机高度使用绝对值：台面高度 + 额外高度
        // 不要用 cueBallPosition.y 因为它已经包含了 TablePhysics.height
        let cameraY = TablePhysics.height + FirstPersonCamera.height
        
        let targetPos = SCNVector3(
            cueBallPosition.x + behind.x,
            cameraY,
            cueBallPosition.z + behind.z
        )
        
        if smooth {
            // 平滑插值避免抖动
            let t = FirstPersonCamera.followSmoothFactor
            let smoothedPos = SCNVector3(
                cameraNode.position.x + (targetPos.x - cameraNode.position.x) * t,
                cameraNode.position.y + (targetPos.y - cameraNode.position.y) * t,
                cameraNode.position.z + (targetPos.z - cameraNode.position.z) * t
            )
            cameraNode.position = smoothedPos
        } else {
            // 立即定位（初始化/切换视角时）
            cameraNode.position = targetPos
        }
        
        // 看向母球前方（瞄准方向延伸点）
        let lookTarget = cueBallPosition + aimDirection * 0.3
        cameraNode.look(at: lookTarget)
        
        // 叠加俯仰角微调
        cameraNode.eulerAngles.x += pitchAngle
    }
    
    /// 击球后切换到观察视角
    func setCameraPostShot(cueBallPosition: SCNVector3) {
        guard currentCameraMode == .firstPerson else { return }
        currentCameraMode = .free  // 临时切到自由模式
        
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.6
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        // 拉高拉远，从球台一端沿长轴方向观察全局
        // 相机沿 -X 方向后退，保持沿长轴观察
        let halfLength = TablePhysics.innerLength / 2
        cameraNode.position = SCNVector3(
            -(halfLength + 0.8),
            FirstPersonCamera.postShotHeight,
            0
        )
        cameraNode.look(at: SCNVector3(0, TablePhysics.height, 0))
        
        SCNTransaction.commit()
    }
    
    /// 旋转相机（自由视角）
    func rotateCamera(deltaX: Float, deltaY: Float) {
        guard currentCameraMode == .free else { return }
        
        cameraNode.eulerAngles.y += deltaX * 0.01
        cameraNode.eulerAngles.x = max(-Float.pi / 2, min(0, cameraNode.eulerAngles.x + deltaY * 0.01))
    }
    
    /// 缩放相机
    func zoomCamera(scale: Float) {
        if cameraNode.camera?.usesOrthographicProjection == true {
            // 正交投影：调整 orthographicScale
            let currentScale = cameraNode.camera?.orthographicScale ?? 1.0
            let newScale = max(0.3, min(3.0, currentScale / Double(scale)))
            cameraNode.camera?.orthographicScale = newScale
        } else if currentCameraMode == .firstPerson {
            // 第一人称：调整缩放因子（影响相机到母球距离）
            firstPersonZoomFactor = max(0.3, min(2.5, firstPersonZoomFactor / scale))
        } else {
            // 其他透视模式：调整 FOV
            let currentFOV = cameraNode.camera?.fieldOfView ?? 60
            let newFOV = max(30, min(100, currentFOV / CGFloat(scale)))
            cameraNode.camera?.fieldOfView = newFOV
        }
    }
    
    // MARK: - Ball Surface Constraint
    
    /// 每帧调用：约束所有球贴合台面（消除 Y 方向的任何漂移或弹跳）
    func constrainBallsToSurface() {
        let surfaceY = TablePhysics.height + BallPhysics.radius
        let shadowY = TablePhysics.height + 0.001
        
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
    
    // MARK: - Aim Line
    
    /// 显示瞄准线
    func showAimLine(from start: SCNVector3, direction: SCNVector3, length: Float) {
        // 移除旧的瞄准线
        aimLineNode?.removeFromParentNode()
        
        let lineGeometry = SCNCylinder(radius: 0.003, height: CGFloat(length))
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.white.withAlphaComponent(0.8)
        material.emission.contents = UIColor.white.withAlphaComponent(0.3)
        lineGeometry.materials = [material]
        
        aimLineNode = SCNNode(geometry: lineGeometry)
        aimLineNode?.position = start + direction * (length / 2)
        
        // 旋转使圆柱体指向方向
        let up = SCNVector3(0, 1, 0)
        let axis = up.cross(direction).normalized()
        let angle = acos(up.dot(direction))
        aimLineNode?.rotation = SCNVector4(axis.x, axis.y, axis.z, angle)
        
        rootNode.addChildNode(aimLineNode!)
    }
    
    /// 隐藏瞄准线
    func hideAimLine() {
        aimLineNode?.removeFromParentNode()
        aimLineNode = nil
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
    
    private func attachShadow(to ball: SCNNode) {
        guard let name = ball.name, shadowNodes[name] == nil else { return }
        let shadow = SCNCylinder(radius: CGFloat(BallPhysics.radius * 0.9), height: 0.001)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.black.withAlphaComponent(0.25)
        material.isDoubleSided = true
        shadow.materials = [material]
        
        let shadowNode = SCNNode(geometry: shadow)
        shadowNode.name = "\(name)_shadow"
        shadowNode.position = SCNVector3(ball.position.x, TablePhysics.height + 0.001, ball.position.z)
        // SCNCylinder 轴沿 Y，圆面已在 XZ 平面上，无需旋转
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
    
    /// 获取袋口列表
    func pockets() -> [Pocket] {
        return tableGeometry.pockets
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
                shadow.position = SCNVector3(ball.position.x, TablePhysics.height + 0.001, ball.position.z)
            }
        }
        
        // 重置缩放因子
        firstPersonZoomFactor = 1.0
        
        hideAimLine()
    }
}

