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
    
    /// USDZ 球杆皮头在模型局部坐标的点位（用于三维对齐白球中心）
    private var modelTipLocalPoint: SCNVector3 = SCNVector3Zero
    
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
        // 与程序化球杆一致：+Z 是杆尾方向，皮头取较小 Z 端；
        // X/Y 用包围盒中心，确保皮头在三维空间对齐白球中心
        modelTipLocalPoint = SCNVector3(
            (bMin.x + bMax.x) * 0.5,
            (bMin.y + bMax.y) * 0.5,
            bMin.z
        )
        print("[CueStick] 使用 USDZ 模型球杆")
        print("[CueStick]   boundingBox: min=\(bMin), max=\(bMax)")
        print("[CueStick]   size: X=\(sizeX), Y=\(sizeY), Z=\(sizeZ)")
        print("[CueStick]   tipLocalPoint=\(modelTipLocalPoint)")
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
    ///   - elevation: 仰角（弧度，正值 = 杆尾抬高）
    func update(cueBallPosition: SCNVector3, aimDirection: SCNVector3, pullBack: Float, elevation: Float = 0) {
        currentPullBack = pullBack
        
        if usesModelCueStick {
            updateModelCueStick(cueBallPosition: cueBallPosition, aimDirection: aimDirection, pullBack: pullBack, elevation: elevation)
        } else {
            updateProgrammaticCueStick(cueBallPosition: cueBallPosition, aimDirection: aimDirection, pullBack: pullBack, elevation: elevation)
        }
    }
    
    /// 将任意瞄准向量约束到台面 XZ 平面并归一化
    private func normalizedTableAim(_ aimDirection: SCNVector3) -> SCNVector3 {
        let flat = SCNVector3(aimDirection.x, 0, aimDirection.z)
        let len = flat.length()
        if len < 0.0001 {
            return SCNVector3(1, 0, 0)
        }
        return flat / len
    }
    
    /// 更新 USDZ 模型球杆的位置
    private func updateModelCueStick(cueBallPosition: SCNVector3, aimDirection: SCNVector3, pullBack: Float, elevation: Float) {
        let tipOffset = CueStickSettings.tipOffset + pullBack
        let aim = normalizedTableAim(aimDirection)
        
        rootNode.position = cueBallPosition
        
        let backDirection = -aim
        let yaw = atan2(backDirection.x, backDirection.z)
        // elevation 使杆尾抬高：负 pitch 使 +Z（杆尾）方向朝上
        rootNode.eulerAngles = SCNVector3(-elevation, yaw, 0)
        
        if let model = modelNode {
            model.position = SCNVector3(
                -modelTipLocalPoint.x,
                -modelTipLocalPoint.y,
                tipOffset - modelTipLocalPoint.z
            )
        }
    }
    
    /// 更新程序化球杆的位置
    private func updateProgrammaticCueStick(cueBallPosition: SCNVector3, aimDirection: SCNVector3, pullBack: Float, elevation: Float) {
        let tipOffset = CueStickSettings.tipOffset + pullBack
        let shaftLength = CueStickSettings.length
        let tipHeight = CueStickSettings.tipHeight
        let ferruleHeight: Float = 0.015
        let aim = normalizedTableAim(aimDirection)
        
        rootNode.position = cueBallPosition
        
        let backDirection = -aim
        let yaw = atan2(backDirection.x, backDirection.z)
        rootNode.eulerAngles = SCNVector3(-elevation, yaw, 0)
        
        tipNode?.position = SCNVector3(0, 0, tipOffset + tipHeight / 2)
        tipNode?.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        
        ferruleNode?.position = SCNVector3(0, 0, tipOffset + tipHeight + ferruleHeight / 2)
        ferruleNode?.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        
        shaftNode?.position = SCNVector3(0, 0, tipOffset + tipHeight + ferruleHeight + shaftLength / 2)
        shaftNode?.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
    }
    
    // MARK: - Collision Detection
    
    /// 计算球杆避免碰撞所需的最小仰角
    /// 在瞄准方向的垂直平面中，检测球杆是否会碰到其他球或库边，
    /// 若有碰撞则返回使杆身完全避开障碍物的最小仰角。
    /// - Parameters:
    ///   - cueBallPosition: 母球中心位置
    ///   - aimDirection: 瞄准方向（XZ 平面）
    ///   - pullBack: 当前后拉距离
    ///   - ballPositions: 所有目标球的世界坐标
    /// - Returns: 所需仰角（弧度），0 表示无碰撞
    static func calculateRequiredElevation(
        cueBallPosition: SCNVector3,
        aimDirection: SCNVector3,
        pullBack: Float,
        ballPositions: [SCNVector3]
    ) -> Float {
        let aim = SCNVector3(aimDirection.x, 0, aimDirection.z).normalized()
        guard aim.length() > 0.0001 else { return 0 }
        let backDir = -aim
        
        let totalTipOffset = CueStickSettings.tipOffset + pullBack
        let stickLength = CueStickSettings.length
        let tipR = CueStickSettings.tipRadius
        let buttR = CueStickSettings.buttRadius
        let ballR = BallPhysics.radius
        let clearance: Float = 0.003
        
        let tipWorldY = cueBallPosition.y
        let tipWorldXZ = SCNVector3(
            cueBallPosition.x + backDir.x * totalTipOffset,
            0,
            cueBallPosition.z + backDir.z * totalTipOffset
        )
        
        var maxElevation: Float = 0
        
        // --- 检测目标球 ---
        for ballPos in ballPositions {
            let dx = ballPos.x - tipWorldXZ.x
            let dz = ballPos.z - tipWorldXZ.z
            
            let dAlong = dx * backDir.x + dz * backDir.z
            if dAlong < 0 || dAlong > stickLength { continue }
            
            let perpX = dx - backDir.x * dAlong
            let perpZ = dz - backDir.z * dAlong
            let dPerp = sqrtf(perpX * perpX + perpZ * perpZ)
            
            let stickR = tipR + (buttR - tipR) * (dAlong / stickLength)
            let collisionDist = ballR + stickR + clearance
            if dPerp >= collisionDist { continue }
            
            let rCross = sqrtf(max(0, ballR * ballR - min(ballR * ballR, dPerp * dPerp)))
            let ballTop = ballPos.y + rCross
            let requiredHeight = ballTop + stickR + clearance - tipWorldY
            
            if requiredHeight > 0 && dAlong > 0.001 {
                let sinTheta = min(1.0, requiredHeight / dAlong)
                let theta = asinf(sinTheta)
                maxElevation = max(maxElevation, theta)
            }
        }
        
        // --- 检测库边 ---
        let cushionTop = TablePhysics.height + TablePhysics.cushionHeight
        let heightAboveCushion = cushionTop - tipWorldY
        if heightAboveCushion > 0 {
            let halfL = TablePhysics.innerLength / 2
            let halfW = TablePhysics.innerWidth / 2
            
            let rails: [(normal: (Float, Float), offset: Float)] = [
                ((1, 0), halfL),    // +X rail
                ((-1, 0), halfL),   // -X rail
                ((0, 1), halfW),    // +Z rail
                ((0, -1), halfW),   // -Z rail
            ]
            
            for rail in rails {
                let nx = rail.normal.0
                let nz = rail.normal.1
                let denominator = backDir.x * nx + backDir.z * nz
                guard denominator > 0.001 else { continue }
                let tipDot = tipWorldXZ.x * nx + tipWorldXZ.z * nz
                let dCrossing = (rail.offset - tipDot) / denominator
                
                if dCrossing > 0 && dCrossing < stickLength {
                    let stickR = tipR + (buttR - tipR) * (dCrossing / stickLength)
                    let required = heightAboveCushion + stickR + clearance
                    if required > 0 && dCrossing > 0.001 {
                        let sinTheta = min(1.0, required / dCrossing)
                        let theta = asinf(sinTheta)
                        maxElevation = max(maxElevation, theta)
                    }
                }
            }
        }
        
        let maxAllowedElevation: Float = 30 * .pi / 180
        return min(maxElevation, maxAllowedElevation)
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
