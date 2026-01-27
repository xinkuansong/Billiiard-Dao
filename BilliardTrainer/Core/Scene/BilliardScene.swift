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
    
    /// 相机节点
    private(set) var cameraNode: SCNNode!
    
    /// 灯光节点
    private(set) var lightNodes: [SCNNode] = []
    
    /// 瞄准线节点
    private(set) var aimLineNode: SCNNode?
    
    /// 当前视角模式
    private(set) var currentCameraMode: CameraMode = .topDown2D
    
    // MARK: - Camera Mode
    enum CameraMode {
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
        
        // 环境光照
        lightingEnvironment.contents = UIColor.darkGray
        lightingEnvironment.intensity = 1.0
    }
    
    /// 设置球台
    private func setupTable() {
        tableNode = SCNNode()
        tableNode.name = "table"
        
        // 台面
        let tableTopGeometry = SCNBox(
            width: CGFloat(TablePhysics.innerLength),
            height: 0.02,
            length: CGFloat(TablePhysics.innerWidth),
            chamferRadius: 0
        )
        
        // 台呢材质 - 绿色
        let clothMaterial = SCNMaterial()
        clothMaterial.diffuse.contents = UIColor(red: 0.0, green: 0.45, blue: 0.3, alpha: 1.0)
        clothMaterial.roughness.contents = 0.8
        tableTopGeometry.materials = [clothMaterial]
        
        let tableTopNode = SCNNode(geometry: tableTopGeometry)
        tableTopNode.name = "tableTop"
        tableTopNode.position = SCNVector3(0, Float(TablePhysics.height), 0)
        tableNode.addChildNode(tableTopNode)
        
        // 库边
        setupCushions()
        
        // 袋口
        setupPockets()
        
        // 颗星标记
        setupDiamonds()
        
        rootNode.addChildNode(tableNode)
    }
    
    /// 设置库边
    private func setupCushions() {
        let cushionMaterial = SCNMaterial()
        cushionMaterial.diffuse.contents = UIColor(red: 0.0, green: 0.35, blue: 0.25, alpha: 1.0)
        
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
        longCushionGeometry.materials = [cushionMaterial]
        
        // 上边库
        let topCushionNode = SCNNode(geometry: longCushionGeometry)
        topCushionNode.name = "cushion_top"
        topCushionNode.position = SCNVector3(
            0,
            tableHeight + cushionHeight / 2,
            halfWidth + cushionThickness / 2
        )
        tableNode.addChildNode(topCushionNode)
        
        // 下边库
        let bottomCushionNode = SCNNode(geometry: longCushionGeometry)
        bottomCushionNode.name = "cushion_bottom"
        bottomCushionNode.position = SCNVector3(
            0,
            tableHeight + cushionHeight / 2,
            -(halfWidth + cushionThickness / 2)
        )
        tableNode.addChildNode(bottomCushionNode)
        
        // 短边库边 (左右)
        let shortCushionGeometry = SCNBox(
            width: CGFloat(cushionThickness),
            height: CGFloat(cushionHeight),
            length: CGFloat(TablePhysics.innerWidth),
            chamferRadius: 0.005
        )
        shortCushionGeometry.materials = [cushionMaterial]
        
        // 左边库
        let leftCushionNode = SCNNode(geometry: shortCushionGeometry)
        leftCushionNode.name = "cushion_left"
        leftCushionNode.position = SCNVector3(
            -(halfLength + cushionThickness / 2),
            tableHeight + cushionHeight / 2,
            0
        )
        tableNode.addChildNode(leftCushionNode)
        
        // 右边库
        let rightCushionNode = SCNNode(geometry: shortCushionGeometry)
        rightCushionNode.name = "cushion_right"
        rightCushionNode.position = SCNVector3(
            halfLength + cushionThickness / 2,
            tableHeight + cushionHeight / 2,
            0
        )
        tableNode.addChildNode(rightCushionNode)
    }
    
    /// 设置袋口
    private func setupPockets() {
        let pocketMaterial = SCNMaterial()
        pocketMaterial.diffuse.contents = UIColor.black
        
        let halfLength = TablePhysics.innerLength / 2
        let halfWidth = TablePhysics.innerWidth / 2
        let tableHeight = TablePhysics.height
        
        // 6个袋口位置
        let pocketPositions: [(x: Float, z: Float, isCorner: Bool)] = [
            (-halfLength, -halfWidth, true),   // 左下角
            (-halfLength, halfWidth, true),    // 左上角
            (halfLength, -halfWidth, true),    // 右下角
            (halfLength, halfWidth, true),     // 右上角
            (0, -halfWidth, false),            // 下中袋
            (0, halfWidth, false)              // 上中袋
        ]
        
        for (index, pos) in pocketPositions.enumerated() {
            let radius = pos.isCorner ? TablePhysics.cornerPocketDiameter / 2 : TablePhysics.pocketDiameter / 2
            let pocketGeometry = SCNCylinder(radius: CGFloat(radius), height: 0.05)
            pocketGeometry.materials = [pocketMaterial]
            
            let pocketNode = SCNNode(geometry: pocketGeometry)
            pocketNode.name = "pocket_\(index)"
            pocketNode.position = SCNVector3(pos.x, tableHeight - 0.02, pos.z)
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
        
        // 短边颗星 (2个间隔)
        let shortSpacing = TablePhysics.innerWidth / 2.0
        for i in 1..<2 {
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
    private func setupLights() {
        // 主光源 - 顶部方向光
        let mainLight = SCNLight()
        mainLight.type = .directional
        mainLight.intensity = 800
        mainLight.castsShadow = true
        mainLight.shadowRadius = 3
        mainLight.shadowColor = UIColor.black.withAlphaComponent(0.5)
        
        let mainLightNode = SCNNode()
        mainLightNode.light = mainLight
        mainLightNode.position = SCNVector3(0, 3, 0)
        mainLightNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        rootNode.addChildNode(mainLightNode)
        lightNodes.append(mainLightNode)
        
        // 环境光
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 300
        ambientLight.color = UIColor.white
        
        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight
        rootNode.addChildNode(ambientLightNode)
        lightNodes.append(ambientLightNode)
        
        // 补光 - 台球灯效果
        let fillLight = SCNLight()
        fillLight.type = .spot
        fillLight.intensity = 500
        fillLight.spotInnerAngle = 30
        fillLight.spotOuterAngle = 60
        
        let fillLightNode = SCNNode()
        fillLightNode.light = fillLight
        fillLightNode.position = SCNVector3(0, 2, 0)
        fillLightNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        rootNode.addChildNode(fillLightNode)
        lightNodes.append(fillLightNode)
    }
    
    /// 设置相机
    private func setupCamera() {
        let camera = SCNCamera()
        camera.zNear = 0.1
        camera.zFar = 100
        
        cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.name = "camera"
        
        // 默认2D俯视角度
        setCameraMode(.topDown2D, animated: false)
        
        rootNode.addChildNode(cameraNode)
    }
    
    /// 设置物理世界
    private func setupPhysics() {
        physicsWorld.gravity = SCNVector3(0, -9.8, 0)
        physicsWorld.speed = 1.0
    }
    
    // MARK: - Ball Management
    
    /// 创建母球
    func createCueBall(at position: SCNVector3? = nil) {
        let defaultPosition = position ?? SCNVector3(
            -TablePhysics.innerLength / 4,
            TablePhysics.height + BallPhysics.radius + 0.001,
            0
        )
        
        cueBallNode = createBall(
            color: UIColor.white,
            position: defaultPosition,
            name: "cueBall"
        )
        
        rootNode.addChildNode(cueBallNode)
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
        physicsBody.angularDamping = 0.5
        physicsBody.damping = 0.1
        
        ballNode.physicsBody = physicsBody
        
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
        var newEulerAngles: SCNVector3
        var orthographic = false
        
        switch mode {
        case .topDown2D:
            // 2D俯视 - 正交投影
            newPosition = SCNVector3(0, 3.5, 0)
            newEulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
            orthographic = true
            
        case .perspective3D:
            // 3D透视 - 45度角
            newPosition = SCNVector3(0, 2.5, 2.5)
            newEulerAngles = SCNVector3(-Float.pi / 4, 0, 0)
            
        case .shooting:
            // 击球视角 - 15度角，跟随母球
            if let cueBall = cueBallNode {
                let offset = SCNVector3(0, 0.5, 1.0)
                newPosition = SCNVector3(
                    cueBall.position.x + offset.x,
                    cueBall.position.y + offset.y,
                    cueBall.position.z + offset.z
                )
            } else {
                newPosition = SCNVector3(-0.5, 1.0, 1.0)
            }
            newEulerAngles = SCNVector3(-Float.pi / 12, 0, 0)
            
        case .free:
            // 自由视角 - 保持当前位置
            return
        }
        
        // 设置投影模式
        cameraNode.camera?.usesOrthographicProjection = orthographic
        if orthographic {
            cameraNode.camera?.orthographicScale = 2.0
        }
        
        // 动画过渡
        if animated {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = CameraSettings.transitionDuration
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            cameraNode.position = newPosition
            cameraNode.eulerAngles = newEulerAngles
            
            SCNTransaction.commit()
        } else {
            cameraNode.position = newPosition
            cameraNode.eulerAngles = newEulerAngles
        }
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
            let currentScale = cameraNode.camera?.orthographicScale ?? 2.0
            let newScale = max(0.5, min(5.0, currentScale / Double(scale)))
            cameraNode.camera?.orthographicScale = newScale
        } else {
            // 透视投影：调整相机距离
            let direction = SCNVector3(0, -1, -1).normalized()
            let currentDistance = cameraNode.position.length()
            let newDistance = max(
                CameraSettings.minDistance,
                min(CameraSettings.maxDistance, currentDistance / scale)
            )
            cameraNode.position = direction * newDistance
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
    
    // MARK: - Reset
    
    /// 重置场景
    func resetScene() {
        // 移除所有球
        cueBallNode?.removeFromParentNode()
        cueBallNode = nil
        
        for ball in targetBallNodes {
            ball.removeFromParentNode()
        }
        targetBallNodes.removeAll()
        
        hideAimLine()
    }
}

// MARK: - SCNVector3 Extensions

extension SCNVector3 {
    /// 向量长度
    func length() -> Float {
        return sqrt(x * x + y * y + z * z)
    }
    
    /// 归一化
    func normalized() -> SCNVector3 {
        let len = length()
        guard len > 0 else { return self }
        return SCNVector3(x / len, y / len, z / len)
    }
    
    /// 点积
    func dot(_ other: SCNVector3) -> Float {
        return x * other.x + y * other.y + z * other.z
    }
    
    /// 叉积
    func cross(_ other: SCNVector3) -> SCNVector3 {
        return SCNVector3(
            y * other.z - z * other.y,
            z * other.x - x * other.z,
            x * other.y - y * other.x
        )
    }
    
    /// 向量加法
    static func + (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        return SCNVector3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }
    
    /// 向量减法
    static func - (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        return SCNVector3(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }
    
    /// 标量乘法
    static func * (lhs: SCNVector3, rhs: Float) -> SCNVector3 {
        return SCNVector3(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
    }
}
