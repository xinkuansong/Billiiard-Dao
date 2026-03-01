# 步骤2：SceneKit场景搭建

## 目标
搭建完整的3D台球场景，包括球台、球体、材质、光照系统。

**预计时间**: 3-4天
**优先级**: P0（必须完成）

---

## 一、创建基础场景

### 1.1 创建 BilliardScene.swift

**位置**: `Core/Scene/BilliardScene.swift`

**代码**:
```swift
import SceneKit

class BilliardScene: SCNScene {
    // 场景节点
    var tableNode: TableNode!
    var cueBall: BallNode!
    var targetBalls: [BallNode] = []

    // 相机节点
    var cameraNode: SCNNode!
    var cameraTarget: SCNNode!

    // 光照节点
    var ambientLight: SCNNode!
    var directionalLight: SCNNode!
    var spotLight: SCNNode!

    override init() {
        super.init()
        setupScene()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupScene() {
        // 设置背景色
        background.contents = UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)

        // 创建场景组件
        setupLighting()
        setupCamera()
        setupTable()
        setupBalls()
    }

    // MARK: - Lighting

    private func setupLighting() {
        // 环境光
        ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light!.type = .ambient
        ambientLight.light!.color = UIColor(white: 0.3, alpha: 1.0)
        rootNode.addChildNode(ambientLight)

        // 主光源（定向光）
        directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light!.type = .directional
        directionalLight.light!.color = UIColor(white: 0.8, alpha: 1.0)
        directionalLight.light!.castsShadow = true
        directionalLight.light!.shadowMode = .deferred
        directionalLight.light!.shadowSampleCount = 16
        directionalLight.position = SCNVector3(x: 0, y: 5, z: 0)
        directionalLight.eulerAngles = SCNVector3(x: -.pi / 4, y: 0, z: 0)
        rootNode.addChildNode(directionalLight)

        // 聚光灯（模拟台球桌上方的灯）
        spotLight = SCNNode()
        spotLight.light = SCNLight()
        spotLight.light!.type = .spot
        spotLight.light!.color = UIColor(white: 1.0, alpha: 1.0)
        spotLight.light!.spotInnerAngle = 45
        spotLight.light!.spotOuterAngle = 60
        spotLight.light!.castsShadow = true
        spotLight.position = SCNVector3(x: 0, y: 4, z: 0)
        spotLight.eulerAngles = SCNVector3(x: -.pi / 2, y: 0, z: 0)
        rootNode.addChildNode(spotLight)
    }

    // MARK: - Camera

    private func setupCamera() {
        // 创建相机目标点（用于相机跟随）
        cameraTarget = SCNNode()
        cameraTarget.position = SCNVector3(x: 0, y: 0, z: 0)
        rootNode.addChildNode(cameraTarget)

        // 创建相机
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera!.zNear = 0.1
        cameraNode.camera!.zFar = 100
        cameraNode.camera!.fieldOfView = 60
        cameraNode.position = SCNVector3(x: 0, y: 3, z: 5)
        cameraNode.look(at: cameraTarget.position)
        rootNode.addChildNode(cameraNode)
    }

    // MARK: - Table

    private func setupTable() {
        tableNode = TableNode()
        rootNode.addChildNode(tableNode)
    }

    // MARK: - Balls

    private func setupBalls() {
        // 创建主球（白球）
        cueBall = BallNode(type: .cue)
        cueBall.position = SCNVector3(x: 0, y: 0.03, z: 1.5)
        rootNode.addChildNode(cueBall)
    }

    // MARK: - Public Methods

    func addTargetBall(at position: SCNVector3, number: Int) {
        let ball = BallNode(type: .numbered(number))
        ball.position = position
        targetBalls.append(ball)
        rootNode.addChildNode(ball)
    }

    func resetBalls() {
        // 重置主球位置
        cueBall.position = SCNVector3(x: 0, y: 0.03, z: 1.5)
        cueBall.physicsBody?.velocity = SCNVector3Zero
        cueBall.physicsBody?.angularVelocity = SCNVector4Zero

        // 移除所有目标球
        targetBalls.forEach { $0.removeFromParentNode() }
        targetBalls.removeAll()
    }
}
```

**验收标准**:
- [ ] BilliardScene类已创建
- [ ] 场景初始化正常
- [ ] 光照系统配置完成
- [ ] 相机系统配置完成

---

## 二、创建球台节点

### 2.1 创建 TableNode.swift

**位置**: `Core/Physics/TableNode.swift`

**代码**:
```swift
import SceneKit

class TableNode: SCNNode {
    // 台球桌尺寸（标准9球桌：2.54m x 1.27m）
    static let tableLength: CGFloat = 2.54
    static let tableWidth: CGFloat = 1.27
    static let tableHeight: CGFloat = 0.8
    static let cushionHeight: CGFloat = 0.04
    static let pocketRadius: CGFloat = 0.06

    private var playingSurface: SCNNode!
    private var cushions: [SCNNode] = []
    private var pockets: [SCNNode] = []

    override init() {
        super.init()
        setupTable()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupTable() {
        createPlayingSurface()
        createCushions()
        createPockets()
        createTableBase()
    }

    // MARK: - Playing Surface

    private func createPlayingSurface() {
        let surface = SCNBox(
            width: Self.tableWidth,
            height: 0.01,
            length: Self.tableLength,
            chamferRadius: 0
        )

        // 台呢材质（绿色）
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(red: 0.0, green: 0.5, blue: 0.2, alpha: 1.0)
        material.roughness.contents = 0.8
        material.metalness.contents = 0.0
        surface.materials = [material]

        playingSurface = SCNNode(geometry: surface)
        playingSurface.position = SCNVector3(x: 0, y: 0, z: 0)

        // 添加物理体（静态）
        let physicsShape = SCNPhysicsShape(
            geometry: surface,
            options: [.type: SCNPhysicsShape.ShapeType.concavePolyhedron]
        )
        playingSurface.physicsBody = SCNPhysicsBody(type: .static, shape: physicsShape)
        playingSurface.physicsBody?.restitution = 0.8
        playingSurface.physicsBody?.friction = 0.4

        addChildNode(playingSurface)
    }

    // MARK: - Cushions

    private func createCushions() {
        let cushionWidth: CGFloat = 0.05
        let cushionMaterial = createCushionMaterial()

        // 长边cushions（上下）
        createCushion(
            width: Self.tableWidth - 2 * Self.pocketRadius,
            length: cushionWidth,
            position: SCNVector3(x: 0, y: Self.cushionHeight / 2, z: -Self.tableLength / 2),
            material: cushionMaterial
        )
        createCushion(
            width: Self.tableWidth - 2 * Self.pocketRadius,
            length: cushionWidth,
            position: SCNVector3(x: 0, y: Self.cushionHeight / 2, z: Self.tableLength / 2),
            material: cushionMaterial
        )

        // 短边cushions（左右）
        createCushion(
            width: cushionWidth,
            length: Self.tableLength - 2 * Self.pocketRadius,
            position: SCNVector3(x: -Self.tableWidth / 2, y: Self.cushionHeight / 2, z: 0),
            material: cushionMaterial
        )
        createCushion(
            width: cushionWidth,
            length: Self.tableLength - 2 * Self.pocketRadius,
            position: SCNVector3(x: Self.tableWidth / 2, y: Self.cushionHeight / 2, z: 0),
            material: cushionMaterial
        )
    }

    private func createCushion(width: CGFloat, length: CGFloat, position: SCNVector3, material: SCNMaterial) {
        let cushion = SCNBox(
            width: width,
            height: Self.cushionHeight,
            length: length,
            chamferRadius: 0.005
        )
        cushion.materials = [material]

        let cushionNode = SCNNode(geometry: cushion)
        cushionNode.position = position

        // 添加物理体
        let physicsShape = SCNPhysicsShape(geometry: cushion, options: nil)
        cushionNode.physicsBody = SCNPhysicsBody(type: .static, shape: physicsShape)
        cushionNode.physicsBody?.restitution = 0.9
        cushionNode.physicsBody?.friction = 0.1

        cushions.append(cushionNode)
        addChildNode(cushionNode)
    }

    private func createCushionMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(red: 0.0, green: 0.4, blue: 0.15, alpha: 1.0)
        material.roughness.contents = 0.6
        return material
    }

    // MARK: - Pockets

    private func createPockets() {
        let pocketPositions: [SCNVector3] = [
            // 四个角
            SCNVector3(x: -Self.tableWidth / 2, y: -0.02, z: -Self.tableLength / 2),
            SCNVector3(x: Self.tableWidth / 2, y: -0.02, z: -Self.tableLength / 2),
            SCNVector3(x: -Self.tableWidth / 2, y: -0.02, z: Self.tableLength / 2),
            SCNVector3(x: Self.tableWidth / 2, y: -0.02, z: Self.tableLength / 2),
            // 两个中袋
            SCNVector3(x: -Self.tableWidth / 2, y: -0.02, z: 0),
            SCNVector3(x: Self.tableWidth / 2, y: -0.02, z: 0)
        ]

        for position in pocketPositions {
            createPocket(at: position)
        }
    }

    private func createPocket(at position: SCNVector3) {
        let pocket = SCNCylinder(radius: Self.pocketRadius, height: 0.05)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.black
        pocket.materials = [material]

        let pocketNode = SCNNode(geometry: pocket)
        pocketNode.position = position
        pocketNode.eulerAngles = SCNVector3(x: .pi / 2, y: 0, z: 0)

        // 添加物理体（用于检测球进袋）
        pocketNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        pocketNode.physicsBody?.categoryBitMask = PhysicsCategory.pocket
        pocketNode.physicsBody?.contactTestBitMask = PhysicsCategory.ball

        pockets.append(pocketNode)
        addChildNode(pocketNode)
    }

    // MARK: - Table Base

    private func createTableBase() {
        let base = SCNBox(
            width: Self.tableWidth + 0.2,
            height: Self.tableHeight,
            length: Self.tableLength + 0.2,
            chamferRadius: 0.02
        )

        let material = SCNMaterial()
        material.diffuse.contents = UIColor(red: 0.4, green: 0.2, blue: 0.1, alpha: 1.0)
        material.roughness.contents = 0.7
        base.materials = [material]

        let baseNode = SCNNode(geometry: base)
        baseNode.position = SCNVector3(x: 0, y: -Self.tableHeight / 2 - 0.01, z: 0)
        addChildNode(baseNode)
    }
}

// MARK: - Physics Categories

struct PhysicsCategory {
    static let ball: Int = 1 << 0
    static let table: Int = 1 << 1
    static let cushion: Int = 1 << 2
    static let pocket: Int = 1 << 3
}
```

**验收标准**:
- [ ] TableNode类已创建
- [ ] 球台表面正确渲染
- [ ] 边库（cushions）正确创建
- [ ] 球袋位置正确
- [ ] 物理体配置正确

---

## 三、创建球体节点

### 3.1 创建 BallNode.swift

**位置**: `Core/Physics/BallNode.swift`

**代码**:
```swift
import SceneKit

enum BallType {
    case cue // 主球（白球）
    case numbered(Int) // 编号球（1-15）
    case eight // 8号球（黑球）
}

class BallNode: SCNNode {
    static let ballRadius: CGFloat = 0.028575 // 标准台球半径：57.15mm
    static let ballMass: CGFloat = 0.17 // 标准台球质量：170g

    let ballType: BallType
    var ballNumber: Int {
        switch ballType {
        case .cue:
            return 0
        case .numbered(let num):
            return num
        case .eight:
            return 8
        }
    }

    init(type: BallType) {
        self.ballType = type
        super.init()
        setupBall()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupBall() {
        // 创建球体几何
        let sphere = SCNSphere(radius: Self.ballRadius)
        sphere.segmentCount = 48 // 高质量球体

        // 设置材质
        sphere.materials = [createBallMaterial()]

        geometry = sphere

        // 设置物理体
        setupPhysics()
    }

    private func createBallMaterial() -> SCNMaterial {
        let material = SCNMaterial()

        switch ballType {
        case .cue:
            // 白球
            material.diffuse.contents = UIColor.white
            material.specular.contents = UIColor.white
            material.shininess = 1.0

        case .numbered(let number):
            // 彩球
            material.diffuse.contents = getBallColor(for: number)
            material.specular.contents = UIColor.white
            material.shininess = 0.8

        case .eight:
            // 黑球
            material.diffuse.contents = UIColor.black
            material.specular.contents = UIColor.white
            material.shininess = 1.0
        }

        material.roughness.contents = 0.2
        material.metalness.contents = 0.1

        return material
    }

    private func getBallColor(for number: Int) -> UIColor {
        switch number {
        case 1, 9:
            return UIColor.yellow
        case 2, 10:
            return UIColor.blue
        case 3, 11:
            return UIColor.red
        case 4, 12:
            return UIColor.purple
        case 5, 13:
            return UIColor.orange
        case 6, 14:
            return UIColor.green
        case 7, 15:
            return UIColor.brown
        default:
            return UIColor.gray
        }
    }

    private func setupPhysics() {
        let shape = SCNPhysicsShape(
            geometry: SCNSphere(radius: Self.ballRadius),
            options: [.collisionMargin: 0.001]
        )

        physicsBody = SCNPhysicsBody(type: .dynamic, shape: shape)
        physicsBody?.mass = Self.ballMass
        physicsBody?.restitution = 0.95 // 弹性系数
        physicsBody?.friction = 0.3 // 摩擦系数
        physicsBody?.rollingFriction = 0.01 // 滚动摩擦
        physicsBody?.damping = 0.1 // 线性阻尼
        physicsBody?.angularDamping = 0.1 // 角阻尼

        // 设置碰撞类别
        physicsBody?.categoryBitMask = PhysicsCategory.ball
        physicsBody?.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.table | PhysicsCategory.cushion
        physicsBody?.contactTestBitMask = PhysicsCategory.ball | PhysicsCategory.pocket
    }

    // MARK: - Public Methods

    func applyForce(_ force: SCNVector3) {
        physicsBody?.applyForce(force, asImpulse: true)
    }

    func applySpin(horizontal: Float, vertical: Float) {
        // 应用旋转（高杆、低杆、偏杆）
        let spinVector = SCNVector4(x: vertical, y: 0, z: horizontal, w: 10)
        physicsBody?.angularVelocity = spinVector
    }

    var isMoving: Bool {
        guard let velocity = physicsBody?.velocity else { return false }
        let speed = sqrt(velocity.x * velocity.x + velocity.y * velocity.y + velocity.z * velocity.z)
        return speed > 0.01
    }

    func stop() {
        physicsBody?.velocity = SCNVector3Zero
        physicsBody?.angularVelocity = SCNVector4Zero
    }
}
```

**验收标准**:
- [ ] BallNode类已创建
- [ ] 球体几何正确
- [ ] 材质和颜色正确
- [ ] 物理属性配置正确
- [ ] 支持不同类型的球

---

## 四、创建场景视图

### 4.1 创建 BilliardSceneView.swift

**位置**: `Core/Scene/BilliardSceneView.swift`

**代码**:
```swift
import SwiftUI
import SceneKit

struct BilliardSceneView: UIViewRepresentable {
    @Binding var scene: BilliardScene?

    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()

        // 配置场景视图
        sceneView.allowsCameraControl = false // 我们自己控制相机
        sceneView.autoenablesDefaultLighting = false // 使用自定义光照
        sceneView.showsStatistics = true // 开发时显示统计信息
        sceneView.backgroundColor = .black

        // 抗锯齿
        sceneView.antialiasingMode = .multisampling4X

        // 创建场景
        let billiardScene = BilliardScene()
        sceneView.scene = billiardScene
        scene = billiardScene

        // 设置代理
        sceneView.delegate = context.coordinator

        return sceneView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // 更新视图
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, SCNSceneRendererDelegate {
        var parent: BilliardSceneView

        init(_ parent: BilliardSceneView) {
            self.parent = parent
        }

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            // 每帧更新
        }
    }
}
```

**验收标准**:
- [ ] BilliardSceneView已创建
- [ ] 可以在SwiftUI中使用
- [ ] 场景正确渲染
- [ ] 代理方法正常工作

---

## 五、集成到应用

### 5.1 创建测试视图

**位置**: `Features/Training/Views/SceneTestView.swift`

**代码**:
```swift
import SwiftUI
import SceneKit

struct SceneTestView: View {
    @State private var scene: BilliardScene?

    var body: some View {
        VStack {
            BilliardSceneView(scene: $scene)
                .ignoresSafeArea()

            HStack(spacing: 20) {
                Button("添加球") {
                    addRandomBall()
                }
                .buttonStyle(.borderedProminent)

                Button("重置") {
                    scene?.resetBalls()
                }
                .buttonStyle(.bordered)

                Button("击球") {
                    shootBall()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding()
        }
    }

    private func addRandomBall() {
        guard let scene = scene else { return }

        let x = Float.random(in: -0.5...0.5)
        let z = Float.random(in: -1.0...1.0)
        let position = SCNVector3(x: x, y: 0.03, z: z)
        let number = Int.random(in: 1...15)

        scene.addTargetBall(at: position, number: number)
    }

    private func shootBall() {
        guard let scene = scene else { return }

        let force = SCNVector3(x: 0, y: 0, z: -5)
        scene.cueBall.applyForce(force)
    }
}

#Preview {
    SceneTestView()
}
```

### 5.2 更新 TrainingListView

修改 `Features/Training/Views/TrainingListView.swift`：

```swift
import SwiftUI

struct TrainingListView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("场景测试") {
                    SceneTestView()
                }

                Text("其他训练 - 待实现")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("训练")
        }
    }
}
```

**验收标准**:
- [ ] 测试视图已创建
- [ ] 可以从训练Tab进入
- [ ] 场景正确显示
- [ ] 可以添加球
- [ ] 可以击球
- [ ] 物理效果正常

---

## 六、优化材质和光照

### 6.1 添加环境贴图

在 `BilliardScene.swift` 中添加：

```swift
private func setupEnvironment() {
    // 添加环境贴图以增强反射效果
    lightingEnvironment.contents = UIColor(white: 0.2, alpha: 1.0)
    lightingEnvironment.intensity = 1.0
}
```

在 `setupScene()` 中调用：
```swift
private func setupScene() {
    background.contents = UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)

    setupEnvironment() // 添加这行
    setupLighting()
    setupCamera()
    setupTable()
    setupBalls()
}
```

### 6.2 优化球体材质

在 `BallNode.swift` 的 `createBallMaterial()` 中添加：

```swift
// 添加环境反射
material.reflective.contents = UIColor(white: 0.3, alpha: 1.0)
material.fresnelExponent = 2.0

// 添加法线贴图（可选，增强真实感）
// material.normal.contents = UIImage(named: "ball_normal")
```

**验收标准**:
- [ ] 环境光照优化完成
- [ ] 球体反射效果良好
- [ ] 整体视觉效果提升

---

## 七、性能优化

### 7.1 优化渲染设置

在 `BilliardSceneView.swift` 中优化：

```swift
func makeUIView(context: Context) -> SCNView {
    let sceneView = SCNView()

    // 基础配置
    sceneView.allowsCameraControl = false
    sceneView.autoenablesDefaultLighting = false
    sceneView.showsStatistics = true
    sceneView.backgroundColor = .black

    // 性能优化
    sceneView.antialiasingMode = .multisampling4X
    sceneView.preferredFramesPerSecond = 60
    sceneView.rendersContinuously = true

    // 创建场景
    let billiardScene = BilliardScene()
    sceneView.scene = billiardScene
    scene = billiardScene

    sceneView.delegate = context.coordinator

    return sceneView
}
```

### 7.2 优化物理计算

在 `BilliardScene.swift` 中添加：

```swift
override init() {
    super.init()

    // 优化物理世界
    physicsWorld.speed = 1.0
    physicsWorld.timeStep = 1.0 / 60.0
    physicsWorld.gravity = SCNVector3(x: 0, y: -9.8, z: 0)

    setupScene()
}
```

**验收标准**:
- [ ] 帧率稳定在60fps
- [ ] 物理计算流畅
- [ ] 无明显卡顿

---

## 八、测试场景

### 8.1 功能测试清单

测试以下功能：

1. **场景渲染**
   - [ ] 球台正确显示
   - [ ] 球体正确显示
   - [ ] 光照效果正常
   - [ ] 阴影效果正常

2. **物理效果**
   - [ ] 球可以移动
   - [ ] 球与球碰撞正常
   - [ ] 球与边库碰撞正常
   - [ ] 球会因摩擦减速
   - [ ] 球会停止

3. **性能**
   - [ ] 帧率稳定
   - [ ] 无内存泄漏
   - [ ] 多个球同时运动流畅

### 8.2 调试技巧

在开发过程中，可以启用以下调试选项：

```swift
// 在 BilliardSceneView.swift 中
sceneView.debugOptions = [
    .showPhysicsShapes,  // 显示物理形状
    .showBoundingBoxes,  // 显示边界框
    .showWireframe       // 显示线框（可选）
]
```

**验收标准**:
- [ ] 所有功能测试通过
- [ ] 物理效果符合预期
- [ ] 性能达标

---

## 九、常见问题和解决方案

### 问题1：球体穿透球台

**原因**: 物理体配置不正确或碰撞检测失效

**解决方案**:
```swift
// 确保球的初始位置在球台上方
ball.position = SCNVector3(x: x, y: BallNode.ballRadius + 0.01, z: z)

// 确保物理体的碰撞掩码正确设置
physicsBody?.collisionBitMask = PhysicsCategory.ball | PhysicsCategory.table | PhysicsCategory.cushion
```

### 问题2：球体旋转不自然

**原因**: 角阻尼设置不当

**解决方案**:
```swift
// 调整角阻尼值
physicsBody?.angularDamping = 0.1 // 增加此值会让旋转更快停止
physicsBody?.rollingFriction = 0.01 // 调整滚动摩擦
```

### 问题3：光照效果不理想

**原因**: 光源位置或强度不合适

**解决方案**:
```swift
// 调整光源参数
directionalLight.light!.intensity = 1000 // 增加强度
ambientLight.light!.intensity = 200 // 调整环境光

// 调整光源位置
directionalLight.position = SCNVector3(x: 0, y: 5, z: 2)
```

### 问题4：性能问题

**原因**: 球体分段数过高或阴影质量过高

**解决方案**:
```swift
// 降低球体分段数
let sphere = SCNSphere(radius: Self.ballRadius)
sphere.segmentCount = 32 // 从48降到32

// 优化阴影设置
directionalLight.light!.shadowSampleCount = 8 // 从16降到8
```

---

## 十、提交代码

### 10.1 检查代码

```bash
git status
git diff
```

### 10.2 提交代码

```bash
git add .
git commit -m "feat: Implement SceneKit billiard scene

- Created BilliardScene with lighting and camera setup
- Implemented TableNode with playing surface, cushions, and pockets
- Implemented BallNode with physics and materials
- Created BilliardSceneView for SwiftUI integration
- Added scene test view for development
- Optimized rendering and physics performance
"
```

**验收标准**:
- [ ] 代码已提交
- [ ] 提交信息清晰

---

## 十一、最终验收清单

- [ ] BilliardScene已创建并正常工作
- [ ] TableNode完整实现（表面、边库、球袋）
- [ ] BallNode完整实现（几何、材质、物理）
- [ ] BilliardSceneView可在SwiftUI中使用
- [ ] 光照系统配置完成
- [ ] 相机系统配置完成
- [ ] 物理系统正常工作
- [ ] 测试视图可用
- [ ] 性能优化完成
- [ ] 所有测试通过
- [ ] 代码已提交

---

## 下一步

完成本步骤后，继续进行：
- **步骤3**: 物理引擎实现
- **步骤4**: 瞄准系统实现

---

**预计完成时间**: 3-4天
**实际完成时间**: ___________
**遇到的问题**: ___________
**解决方案**: ___________
