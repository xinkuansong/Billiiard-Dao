//
//  TableModelLoader.swift
//  BilliardTrainer
//
//  USDZ 球台模型加载器
//  负责加载 TaiQiuZhuo.usdz 3D 模型并将其适配到场景坐标系
//

import SceneKit

/// 球台 3D 模型加载器
/// 采用视觉与物理分离策略：USDZ 模型仅提供视觉渲染，物理碰撞由独立几何体处理
class TableModelLoader {
    
    // MARK: - Types
    
    struct TableModel {
        /// 视觉模型根节点（仅用于渲染，无物理体）
        let visualNode: SCNNode
        /// 模型实际应用的缩放
        let appliedScale: SCNVector3
        /// 台面中心在模型坐标中的 Y 偏移（用于对齐球的放置高度）
        let surfaceY: Float
        /// 从模型中提取的球杆节点（可选，nil 则使用程序化球杆）
        let cueStickNode: SCNNode?
    }
    
    // MARK: - Node Names
    
    /// 模型中需要移除的节点名（仅球杆，由代码动态生成）
    private static let removeNodeNames: Set<String> = [
        "QiuGan"
    ]
    
    /// 模型中球节点的名称（计算边界框时临时移除，之后恢复）
    private static let ballNodeNames: Set<String> = [
        "_0", "_1", "_2", "_3", "_4", "_5", "_6", "_7",
        "_8", "_9", "_10", "_11", "_12", "_13", "_14", "_15"
    ]
    
    // MARK: - Public
    
    /// 加载球台 USDZ 模型
    /// - Returns: 包含适配后视觉节点的 TableModel，加载失败返回 nil
    static func loadTable() -> TableModel? {
        guard let url = Bundle.main.url(forResource: "TaiQiuZhuo", withExtension: "usdz") else {
            print("[TableModelLoader] ❌ TaiQiuZhuo.usdz not found in bundle")
            return nil
        }
        print("[TableModelLoader] 📦 找到 USDZ 文件: \(url.lastPathComponent)")
        
        let modelScene: SCNScene
        do {
            modelScene = try SCNScene(url: url, options: [
                .checkConsistency: true
            ])
            print("[TableModelLoader] ✅ SCNScene 加载成功")
        } catch {
            print("[TableModelLoader] ❌ SCNScene 加载失败: \(error)")
            return nil
        }
        
        // ===== 关键：保留 rootNode 的 transform（Z-up → Y-up 旋转） =====
        // SceneKit 加载 Z-up 的 USDZ 时，会在 rootNode 上施加旋转矩阵来转换为 Y-up
        // 如果只克隆 rootNode 的子节点，会丢失这个旋转，导致模型表面朝向错误
        //
        // 解决方案：用一个 container 节点包裹子节点，并复制 rootNode 的 transform
        // visualNode (外层: 用于缩放和定位)
        //   └── container (中层: 保留 Z-up → Y-up 旋转)
        //         └── 模型子节点们
        
        let rootTransform = modelScene.rootNode.transform
        let isIdentity = SCNMatrix4IsIdentity(rootTransform)
        
        print("[TableModelLoader] Root node transform is identity: \(isIdentity)")
        
        // 创建容器节点
        let container = SCNNode()
        container.name = "modelContainer"
        
        if !isIdentity {
            // SceneKit 已自动施加 Z-up → Y-up 旋转，直接使用
            container.transform = rootTransform
            print("[TableModelLoader] 使用 rootNode 自带的坐标转换")
        } else {
            // ===== 关键修复 =====
            // rootNode.transform 是 identity，说明 SceneKit 没有自动转换 Z-up → Y-up
            // 需要手动旋转 -90° 绕 X 轴，将 Z-up 转换为 Y-up
            // 旋转效果：原 Z(上) → Y(上)，原 Y(前) → -Z(前)
            container.eulerAngles.x = -Float.pi / 2
            print("[TableModelLoader] ⚠️ 手动应用 Z-up → Y-up 旋转 (-90° X)")
        }
        
        for child in modelScene.rootNode.childNodes {
            container.addChildNode(child.clone())
        }
        
        // 创建外层视觉节点（用于缩放和定位）
        let visualNode = SCNNode()
        visualNode.name = "tableVisual"
        visualNode.addChildNode(container)
        
        // 打印模型结构（调试用）
        #if DEBUG
        inspectNodeHierarchy(visualNode)
        #endif
        
        // 提取球杆节点（用于动态控制，不是删除）
        let cueStickNode = extractCueStick(from: visualNode)
        
        // 临时移除球节点（避免影响边界框计算），之后恢复
        let removedBalls = detachBallNodes(from: visualNode)
        
        // 禁用所有物理体（视觉层不参与物理碰撞）
        disablePhysics(in: visualNode)
        
        // 移除模型中可能存在的相机和灯光节点（避免干扰场景相机）
        removeCamerasAndLights(from: visualNode)
        
        // ===== 计算边界框（此时已包含 Z-up → Y-up 旋转） =====
        // visualNode.boundingBox 会考虑 container 的 transform
        // 所以返回的边界框已经是 Y-up 坐标系下的值
        let (modelMin, modelMax) = visualNode.boundingBox
        let modelSizeX = modelMax.x - modelMin.x    // 球台长度方向
        let modelSizeY = modelMax.y - modelMin.y    // 球台高度方向（Y-up）
        let modelSizeZ = modelMax.z - modelMin.z    // 球台宽度方向
        
        print("[TableModelLoader] Model bounding box (Y-up coords): min=\(modelMin), max=\(modelMax)")
        print("[TableModelLoader] Model size: X=\(modelSizeX) (length), Y=\(modelSizeY) (height), Z=\(modelSizeZ) (width)")
        
        // 智能判断：如果 Z 维度很小（接近球台高度而非宽度），说明旋转可能没生效
        // 球台宽度应该 > 1m，高度应该 < 1m
        if modelSizeZ < 0.5 && modelSizeY > 1.0 {
            print("[TableModelLoader] ⚠️ 检测到模型可能仍然是 Z-up，Y 和 Z 维度交换")
            print("[TableModelLoader] 尝试使用 Y 维度作为宽度")
        }
        
        // 目标外框尺寸 = 打球面 + 库边 + 木框边
        let targetOuterLength: Float = TablePhysics.innerLength + 2 * TablePhysics.cushionThickness + 0.18
        let targetOuterWidth: Float = TablePhysics.innerWidth + 2 * TablePhysics.cushionThickness + 0.18
        
        // 确定长度和宽度维度
        // 正常情况（Y-up 转换成功）: X = 长度, Z = 宽度
        // 异常情况（Z-up 未转换）: X = 长度, Y = 宽度, Z = 高度
        let actualLength = modelSizeX       // 长度始终沿 X
        let actualWidth: Float
        if modelSizeZ > modelSizeY {
            // 正常：Z 是宽度（> 高度）
            actualWidth = modelSizeZ
            print("[TableModelLoader] 使用 Z 维度作为宽度: \(actualWidth)")
        } else {
            // Z-up 未转换：Y 是宽度
            actualWidth = modelSizeY
            print("[TableModelLoader] 使用 Y 维度作为宽度: \(actualWidth)")
        }
        
        let scaleX: Float
        let scaleW: Float
        
        if actualLength > 0.01 && actualWidth > 0.01 {
            scaleX = targetOuterLength / actualLength
            scaleW = targetOuterWidth / actualWidth
        } else {
            scaleX = 1.0
            scaleW = 1.0
        }
        
        // 使用统一缩放（取平均值），避免模型变形
        let uniformScale = (scaleX + scaleW) / 2.0
        
        print("[TableModelLoader] 📐 缩放计算: uniformScale=\(uniformScale), scaleX=\(scaleX), scaleW=\(scaleW)")
        print("[TableModelLoader] 📐 目标尺寸: length=\(targetOuterLength), width=\(targetOuterWidth)")
        print("[TableModelLoader] 📐 模型实际: length=\(actualLength), width=\(actualWidth)")
        
        // ===== 安全检查：缩放系数合理性 =====
        // 合理范围：0.0001 ~ 1000（模型可能以 mm/cm/m 为单位，放宽范围）
        // 超出范围说明模型尺寸异常，应回退到程序化球台
        if uniformScale < 0.0001 || uniformScale > 1000.0 || uniformScale.isNaN || uniformScale.isInfinite {
            print("[TableModelLoader] ⚠️ 异常缩放系数: \(uniformScale) (scaleX=\(scaleX), scaleW=\(scaleW))")
            print("[TableModelLoader] ⚠️ 模型尺寸不合理，放弃 USDZ 模型，回退到程序化球台")
            // 恢复球节点后返回 nil
            for (ball, parent) in removedBalls {
                parent.addChildNode(ball)
            }
            return nil
        }
        
        let appliedScale = SCNVector3(uniformScale, uniformScale, uniformScale)
        visualNode.scale = appliedScale
        
        // 验证：缩放后球桌外框尺寸是否与物理常数目标一致
        let scaledLength = actualLength * uniformScale
        let scaledWidth = actualWidth * uniformScale
        let lengthTolerance: Float = 0.02   // 2cm（因使用统一缩放，长宽可能略有偏差）
        let widthTolerance: Float = 0.02
        let lengthMatch = abs(scaledLength - targetOuterLength) <= lengthTolerance
        let widthMatch = abs(scaledWidth - targetOuterWidth) <= widthTolerance
        print("[TableModelLoader] 📐 球桌尺寸验证: 缩放后 长=\(String(format: "%.3f", scaledLength))m / 宽=\(String(format: "%.3f", scaledWidth))m")
        print("[TableModelLoader] 📐 球桌尺寸验证: 目标值 长=\(String(format: "%.3f", targetOuterLength))m / 宽=\(String(format: "%.3f", targetOuterWidth))m → 一致=\(lengthMatch && widthMatch ? "✓" : "✗") (长\(lengthMatch ? "✓" : "✗") 宽\(widthMatch ? "✓" : "✗"))")
        
        // 居中模型：将模型水平面中心对齐到场景原点
        let centerX = (modelMin.x + modelMax.x) / 2.0
        let centerZ = (modelMin.z + modelMax.z) / 2.0
        visualNode.position = SCNVector3(
            -centerX * uniformScale,
            0,  // Y 轴（高度）在外部由 setupTable 控制
            -centerZ * uniformScale
        )
        
        // ===== 台面高度计算 =====
        // 移除球后 modelMax.y = 库边/台框顶部（模型中最高点）
        // 台面（台泥）在库边顶部下方 cushionHeight 处
        // surfaceY = 库边顶部世界高度 - 库边高度
        let railTopInWorld = modelMax.y * uniformScale
        let surfaceY = railTopInWorld - TablePhysics.cushionHeight
        
        print("[TableModelLoader] 📐 高度计算: railTopInWorld=\(railTopInWorld), cushionHeight=\(TablePhysics.cushionHeight), surfaceY=\(surfaceY)")
        
        // ===== 安全检查：台面高度合理性 =====
        // surfaceY 应为正值且不超过 10m (放宽以支持更多模型格式)
        if surfaceY < -1.0 || surfaceY > 10.0 || surfaceY.isNaN {
            print("[TableModelLoader] ⚠️ 异常台面高度: surfaceY=\(surfaceY), railTop=\(railTopInWorld)")
            print("[TableModelLoader] ⚠️ 台面高度不合理，放弃 USDZ 模型，回退到程序化球台")
            for (ball, parent) in removedBalls {
                parent.addChildNode(ball)
            }
            return nil
        }
        
        print("[TableModelLoader] 库边顶部(世界): \(railTopInWorld), 库边高度: \(TablePhysics.cushionHeight), 台面: \(surfaceY)")
        
        // 说明：模型台面高度 surfaceY 可能任意（常见为 0 附近），BilliardScene 会用 yOffset 将整桌抬/降到 TablePhysics.height，故最终台面必对齐常数
        let yOffset = TablePhysics.height - surfaceY
        print("[TableModelLoader] 📐 球桌台面高度: 模型 surfaceY=\(String(format: "%.3f", surfaceY))m → 将用 yOffset=\(String(format: "%.3f", yOffset))m 对齐到 TablePhysics.height=\(String(format: "%.3f", TablePhysics.height))m ✓")
        
        // 恢复球节点（作为视觉装饰保留在模型中）
        for (ball, parent) in removedBalls {
            parent.addChildNode(ball)
        }
        print("[TableModelLoader] 恢复了 \(removedBalls.count) 个球节点到模型中")
        
        print("[TableModelLoader] ✅ 模型加载成功:")
        print("[TableModelLoader]   Target outer: \(targetOuterLength) x \(targetOuterWidth)")
        print("[TableModelLoader]   Actual model: \(actualLength) x \(actualWidth)")
        print("[TableModelLoader]   Uniform scale: \(uniformScale) (scaleX=\(scaleX), scaleW=\(scaleW))")
        print("[TableModelLoader]   Surface Y (scaled): \(surfaceY)")
        print("[TableModelLoader]   Visual position: \(visualNode.position)")
        
        // 处理提取的球杆节点
        var preparedCueStick: SCNNode? = nil
        if let cueNode = cueStickNode {
            // cueNode 已经有旋转/缩放保留（来自 worldTransform），位置已归零
            // 需要额外应用 visualNode 的统一缩放（使球杆与球台同比例缩放）
            let cueContainer = SCNNode()
            cueContainer.name = "cueStickModel"
            cueContainer.scale = appliedScale  // 与球台相同的统一缩放
            cueContainer.addChildNode(cueNode)
            
            disablePhysics(in: cueContainer)
            preparedCueStick = cueContainer
            
            print("[TableModelLoader] ✅ 球杆节点提取成功: \(cueNode.name ?? "unnamed")")
            print("[TableModelLoader]   应用统一缩放: \(uniformScale)")
        }
        
        return TableModel(
            visualNode: visualNode,
            appliedScale: appliedScale,
            surfaceY: surfaceY,
            cueStickNode: preparedCueStick
        )
    }
    
    // MARK: - Private Helpers
    
    /// 从视觉模型中提取球杆节点（移除并返回）
    /// - Returns: 提取的球杆节点（已保留旋转/缩放，位置已归零以便动态控制），未找到返回 nil
    private static func extractCueStick(from node: SCNNode) -> SCNNode? {
        var nodesToExtract: [SCNNode] = []
        collectNodes(in: node, matching: removeNodeNames, result: &nodesToExtract)
        
        guard let cueStickNode = nodesToExtract.first else {
            print("[TableModelLoader] ⚠️ 未找到球杆节点 'QiuGan'")
            return nil
        }
        
        // 记录世界变换（包含所有父节点的变换链：container旋转 + 中间节点 + 自身）
        let worldTF = cueStickNode.worldTransform
        let worldPos = SCNVector3(worldTF.m41, worldTF.m42, worldTF.m43)
        
        print("[TableModelLoader] 提取球杆节点: \(cueStickNode.name ?? "unnamed")")
        print("[TableModelLoader]   worldPosition: \(worldPos)")
        print("[TableModelLoader]   localPosition: \(cueStickNode.position)")
        print("[TableModelLoader]   boundingBox: \(cueStickNode.boundingBox)")
        
        cueStickNode.removeFromParentNode()
        
        // 应用世界变换但将位置归零
        // 保留旋转和缩放（Z-up → Y-up 等变换），但不保留场景中的绝对位置
        // 这样 CueStick 类可以通过 rootNode.position 自由控制球杆位置
        var tf = worldTF
        tf.m41 = 0  // 清除 X 位移
        tf.m42 = 0  // 清除 Y 位移
        tf.m43 = 0  // 清除 Z 位移
        cueStickNode.transform = tf
        
        return cueStickNode
    }
    
    /// 临时从树中分离球节点，返回 (球节点, 原父节点) 数组，用于之后恢复
    private static func detachBallNodes(from node: SCNNode) -> [(SCNNode, SCNNode)] {
        var balls: [(SCNNode, SCNNode)] = []
        collectBallNodes(in: node, result: &balls)
        for (ball, _) in balls {
            ball.removeFromParentNode()
        }
        return balls
    }
    
    /// 递归查找球节点，记录其父节点
    private static func collectBallNodes(in node: SCNNode, result: inout [(SCNNode, SCNNode)]) {
        for child in node.childNodes {
            if let name = child.name, ballNodeNames.contains(name) {
                result.append((child, node))
            } else {
                collectBallNodes(in: child, result: &result)
            }
        }
    }
    
    /// 递归查找匹配名称的节点
    private static func collectNodes(in node: SCNNode, matching names: Set<String>, result: inout [SCNNode]) {
        if let name = node.name, names.contains(name) {
            result.append(node)
            return
        }
        for child in node.childNodes {
            collectNodes(in: child, matching: names, result: &result)
        }
    }
    
    /// 递归禁用所有节点的物理体
    private static func disablePhysics(in node: SCNNode) {
        node.physicsBody = nil
        for child in node.childNodes {
            disablePhysics(in: child)
        }
    }
    
    /// 递归移除模型中嵌入的相机和灯光节点（它们会干扰场景相机设置）
    private static func removeCamerasAndLights(from node: SCNNode) {
        var toRemove: [SCNNode] = []
        collectCamerasAndLights(in: node, result: &toRemove)
        for n in toRemove {
            print("[TableModelLoader] Removing embedded camera/light: \(n.name ?? "unnamed")")
            n.removeFromParentNode()
        }
    }
    
    /// 递归查找相机和灯光节点
    private static func collectCamerasAndLights(in node: SCNNode, result: inout [SCNNode]) {
        if node.camera != nil || node.light != nil {
            result.append(node)
            return
        }
        for child in node.childNodes {
            collectCamerasAndLights(in: child, result: &result)
        }
    }
    
    /// 调试：打印节点层级结构
    private static func inspectNodeHierarchy(_ node: SCNNode, indent: String = "") {
        let geoInfo: String
        if let geo = node.geometry {
            let (gMin, gMax) = geo.boundingBox
            geoInfo = "geo:\(type(of: geo)), bounds:(\(gMin))->(\(gMax))"
        } else {
            geoInfo = "no geometry"
        }
        
        print("\(indent)[\(node.name ?? "unnamed")] pos:\(node.position) scale:\(node.scale) \(geoInfo)")
        
        for child in node.childNodes {
            inspectNodeHierarchy(child, indent: indent + "  ")
        }
    }
}
