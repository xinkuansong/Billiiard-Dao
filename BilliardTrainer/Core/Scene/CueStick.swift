//
//  CueStick.swift
//  BilliardTrainer
//
//  球杆 3D 模型与动画
//

import SceneKit

/// 球杆 3D 模型
/// 支持两种模式：
/// 1. 使用 USDZ 模型的球杆（优先）
/// 2. 程序化生成的球杆（降级方案）
class CueStick {
    
    // MARK: - Nodes
    
    /// 球杆根节点（用于整体定位和旋转）
    let rootNode: SCNNode
    
    /// 是否使用 USDZ 模型球杆
    private let usesModelCueStick: Bool
    
    /// USDZ 模型球杆节点
    private var modelNode: SCNNode?
    
    /// 杆身节点（程序化模式）
    private var shaftNode: SCNNode?
    
    /// 皮头节点（程序化模式）
    private var tipNode: SCNNode?
    
    /// 先角（铜箍）节点（程序化模式）
    private var ferruleNode: SCNNode?
    
    // MARK: - State
    
    /// 当前后拉距离
    private var currentPullBack: Float = 0
    
    // MARK: - Initialization
    
    /// 使用 USDZ 模型球杆初始化
    /// - Parameter modelCueStickNode: 从 USDZ 模型提取的球杆容器节点
    init(modelCueStickNode: SCNNode) {
        rootNode = SCNNode()
        rootNode.name = "cueStick"
        usesModelCueStick = true
        
        // 将模型球杆作为子节点
        // 模型的旋转/缩放已保留，位置已归零，所以 rootNode.position 可直接控制球杆位置
        modelNode = modelCueStickNode
        rootNode.addChildNode(modelCueStickNode)
        
        // 诊断日志：显示模型球杆的边界框，帮助调整定位
        let (bMin, bMax) = modelCueStickNode.boundingBox
        let sizeX = bMax.x - bMin.x
        let sizeY = bMax.y - bMin.y
        let sizeZ = bMax.z - bMin.z
        print("[CueStick] 使用 USDZ 模型球杆")
        print("[CueStick]   boundingBox: min=\(bMin), max=\(bMax)")
        print("[CueStick]   size: X=\(sizeX), Y=\(sizeY), Z=\(sizeZ)")
        print("[CueStick]   modelNode scale=\(modelCueStickNode.scale)")
    }
    
    /// 程序化球杆（降级方案）
    init() {
        rootNode = SCNNode()
        rootNode.name = "cueStick"
        usesModelCueStick = false
        
        // 创建杆身 - SCNCone 实现渐变粗细
        let shaftLength = CueStickSettings.length
        let shaftGeometry = SCNCone(
            topRadius: CGFloat(CueStickSettings.tipRadius),     // 前端细
            bottomRadius: CGFloat(CueStickSettings.buttRadius), // 尾端粗
            height: CGFloat(shaftLength)
        )
        
        // 杆身材质 - 木纹色
        let shaftMaterial = SCNMaterial()
        shaftMaterial.diffuse.contents = UIColor(red: 0.72, green: 0.53, blue: 0.28, alpha: 1.0)
        shaftMaterial.specular.contents = UIColor(white: 0.4, alpha: 1.0)
        shaftMaterial.shininess = 0.6
        shaftMaterial.roughness.contents = 0.4
        shaftGeometry.materials = [shaftMaterial]
        
        let shaft = SCNNode(geometry: shaftGeometry)
        shaft.name = "shaft"
        shaftNode = shaft
        
        // 创建先角（铜箍）- 连接皮头和杆身的小环
        let ferruleHeight: Float = 0.015
        let ferruleGeometry = SCNCylinder(
            radius: CGFloat(CueStickSettings.tipRadius + 0.001),
            height: CGFloat(ferruleHeight)
        )
        let ferruleMaterial = SCNMaterial()
        ferruleMaterial.diffuse.contents = UIColor(red: 0.85, green: 0.75, blue: 0.55, alpha: 1.0)
        ferruleMaterial.specular.contents = UIColor.white
        ferruleMaterial.shininess = 0.8
        ferruleGeometry.materials = [ferruleMaterial]
        
        let ferrule = SCNNode(geometry: ferruleGeometry)
        ferrule.name = "ferrule"
        ferruleNode = ferrule
        
        // 创建皮头 - 蓝色小圆柱
        let tipGeometry = SCNCylinder(
            radius: CGFloat(CueStickSettings.tipRadius),
            height: CGFloat(CueStickSettings.tipHeight)
        )
        let tipMaterial = SCNMaterial()
        tipMaterial.diffuse.contents = UIColor(red: 0.2, green: 0.35, blue: 0.65, alpha: 1.0)
        tipMaterial.roughness.contents = 0.9
        tipGeometry.materials = [tipMaterial]
        
        let tip = SCNNode(geometry: tipGeometry)
        tip.name = "tip"
        tipNode = tip
        
        // 组装
        rootNode.addChildNode(shaft)
        rootNode.addChildNode(ferrule)
        rootNode.addChildNode(tip)
        
        // 不参与物理碰撞
        shaft.physicsBody = nil
        ferrule.physicsBody = nil
        tip.physicsBody = nil
        
        print("[CueStick] 使用程序化球杆")
    }
    
    // MARK: - Update Position
    
    /// 更新球杆位置和朝向
    /// - Parameters:
    ///   - cueBallPosition: 母球位置
    ///   - aimDirection: 瞄准方向（归一化，XZ 平面）
    ///   - pullBack: 后拉距离 (0 ~ maxPullBack)
    func update(cueBallPosition: SCNVector3, aimDirection: SCNVector3, pullBack: Float) {
        currentPullBack = pullBack
        
        if usesModelCueStick {
            updateModelCueStick(cueBallPosition: cueBallPosition, aimDirection: aimDirection, pullBack: pullBack)
        } else {
            updateProgrammaticCueStick(cueBallPosition: cueBallPosition, aimDirection: aimDirection, pullBack: pullBack)
        }
    }
    
    /// 更新 USDZ 模型球杆的位置
    private func updateModelCueStick(cueBallPosition: SCNVector3, aimDirection: SCNVector3, pullBack: Float) {
        let tipOffset = CueStickSettings.tipOffset + pullBack
        
        // 球杆根节点位于母球中心
        rootNode.position = cueBallPosition
        
        // 计算球杆朝向（球杆从母球向后延伸）
        let backDirection = SCNVector3(0, 0, 0) - aimDirection
        let yaw = atan2(backDirection.x, backDirection.z)
        rootNode.eulerAngles = SCNVector3(0, yaw, 0)
        
        // 模型球杆在 rootNode 的局部坐标系中
        // 模型的旋转/缩放由 container 内的 transform 控制
        // 位置由 rootNode 控制（rootNode.position = cueBallPosition）
        // 后拉距离沿 +Z 方向偏移（+Z = 远离击球方向）
        if let model = modelNode {
            // 保持模型的缩放不变，只调整局部位置（后拉效果）
            model.position = SCNVector3(0, 0, tipOffset)
        }
    }
    
    /// 更新程序化球杆的位置（保持原有逻辑）
    private func updateProgrammaticCueStick(cueBallPosition: SCNVector3, aimDirection: SCNVector3, pullBack: Float) {
        let tipOffset = CueStickSettings.tipOffset + pullBack
        let shaftLength = CueStickSettings.length
        let tipHeight = CueStickSettings.tipHeight
        let ferruleHeight: Float = 0.015
        
        rootNode.position = cueBallPosition
        
        let backDirection = SCNVector3(0, 0, 0) - aimDirection
        let yaw = atan2(backDirection.x, backDirection.z)
        rootNode.eulerAngles = SCNVector3(0, yaw, 0)
        
        tipNode?.position = SCNVector3(0, 0, tipOffset + tipHeight / 2)
        tipNode?.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        
        ferruleNode?.position = SCNVector3(0, 0, tipOffset + tipHeight + ferruleHeight / 2)
        ferruleNode?.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        
        shaftNode?.position = SCNVector3(0, 0, tipOffset + tipHeight + ferruleHeight + shaftLength / 2)
        shaftNode?.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
    }
    
    // MARK: - Animation
    
    /// 蓄力后拉动画（逐步增加 pullBack）
    func animatePullBack(to pullBack: Float, cueBallPosition: SCNVector3, aimDirection: SCNVector3) {
        update(cueBallPosition: cueBallPosition, aimDirection: aimDirection, pullBack: pullBack)
    }
    
    /// 击球前冲动画
    /// - Parameters:
    ///   - cueBallPosition: 母球位置
    ///   - aimDirection: 瞄准方向
    ///   - completion: 动画完成回调
    func animateStroke(cueBallPosition: SCNVector3, aimDirection: SCNVector3, completion: @escaping () -> Void) {
        // 快速前冲到母球位置
        SCNTransaction.begin()
        SCNTransaction.animationDuration = CueStickSettings.strokeDuration
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeIn)
        
        update(cueBallPosition: cueBallPosition, aimDirection: aimDirection, pullBack: -0.01)
        
        SCNTransaction.completionBlock = { [weak self] in
            // 击球后隐藏球杆
            self?.hide()
            completion()
        }
        SCNTransaction.commit()
    }
    
    // MARK: - Visibility
    
    /// 显示球杆
    func show() {
        rootNode.isHidden = false
        rootNode.opacity = 1.0
    }
    
    /// 隐藏球杆
    func hide() {
        rootNode.isHidden = true
    }
}
