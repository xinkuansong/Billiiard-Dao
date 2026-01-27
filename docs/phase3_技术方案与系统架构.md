# 阶段3：技术方案与系统架构设计

## 一、技术栈确认

| 层级 | 技术选择 | 说明 |
|------|---------|------|
| 开发语言 | Swift 5.x | iOS原生 |
| UI框架 | SwiftUI + UIKit | 混合使用 |
| 游戏引擎 | **SceneKit** | Apple原生3D框架 |
| 物理引擎 | SceneKit Physics + 自定义扩展 | 台球专用物理 |
| 数据持久化 | SwiftData (iOS 17+) | 本地存储 |
| 架构模式 | MVVM + Coordinator | 解耦导航 |
| 最低支持 | iOS 16.0 | 覆盖主流设备 |

### 选择SceneKit的原因

- 纯代码驱动，Claude Code开发友好
- Apple原生框架，性能优秀
- 支持2D/3D视角切换
- 文档丰富，调试方便

---

## 二、系统架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                        表现层 (Presentation)                     │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │  SwiftUI    │  │  SceneKit   │  │   UIKit     │              │
│  │   Views     │  │    Scene    │  │  (复杂交互)  │              │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘              │
│         └────────────────┼────────────────┘                     │
│                          ▼                                      │
├─────────────────────────────────────────────────────────────────┤
│                        业务层 (Business)                         │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │ CourseManager│  │ TrainingMgr  │  │ ProgressMgr  │           │
│  │   课程管理    │  │   训练管理    │  │   进度管理   │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │ PhysicsEngine│  │ AimingSystem │  │ CameraControl│           │
│  │   物理引擎    │  │   瞄准系统    │  │   相机控制   │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
├─────────────────────────────────────────────────────────────────┤
│                        数据层 (Data)                             │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │  SwiftData   │  │  UserDefaults│  │  StoreKit 2  │           │
│  │   用户数据    │  │    设置      │  │   内购管理   │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

---

## 三、相机系统设计

### 视角模式

| 视角 | 角度 | 距离 | 用途 |
|------|------|------|------|
| **2D俯视** | 90° (垂直) | 远 | 走位规划、颗星计算 |
| **3D斜视** | 45° | 中 | 日常练习、观察效果 |
| **击球视角** | 15° | 近 | 模拟真实击球角度 |
| **自由视角** | 任意 | 任意 | 用户自定义 |

### 手势控制

| 手势 | 功能 |
|------|------|
| 单指拖动 | 旋转视角（环绕球台） |
| 双指捏合 | 缩放（调整距离） |
| 双指上下滑动 | 调整俯仰角度 |
| 双击 | 快速切换预设视角 |
| 长按球 | 聚焦该球 |

### 代码结构

```swift
class CameraController {
    
    enum ViewMode {
        case topDown      // 2D俯视 (90°)
        case perspective  // 3D斜视 (45°)
        case shooting     // 击球视角 (15°)
        case free         // 自由视角
    }
    
    var currentMode: ViewMode = .perspective
    var distance: Float = 3.0      // 相机距离
    var angle: Float = 45.0        // 俯仰角度
    var rotation: Float = 0.0      // 环绕角度
    var focusPoint: SCNVector3     // 焦点位置
    
    func switchTo(_ mode: ViewMode, animated: Bool = true)
    func handlePan(_ gesture: UIPanGestureRecognizer)
    func handlePinch(_ gesture: UIPinchGestureRecognizer)
}
```

---

## 四、物理引擎模块

### 目录结构

```
Core/Physics/
├── BilliardPhysics.swift       # 物理引擎主类
├── BallNode.swift              # 球节点（母球/目标球）
├── TableNode.swift             # 球台节点
├── CushionNode.swift           # 库边节点
├── PocketNode.swift            # 袋口节点
├── SpinSystem.swift            # 旋转系统
├── CollisionHandler.swift      # 碰撞处理
└── PhysicsConstants.swift      # 物理常量
```

### 关键物理参数

| 参数 | 说明 | 参考值 |
|------|------|-------|
| 球直径 | 标准台球直径 | 57.15mm |
| 球质量 | 标准台球质量 | 170g |
| 台面摩擦系数 | 滑动摩擦 | 0.2 |
| 库边弹性系数 | 反弹损耗 | 0.85 |
| 球球弹性系数 | 碰撞损耗 | 0.95 |
| 旋转衰减率 | 旋转摩擦损耗 | 0.98/帧 |

### 旋转系统

```swift
struct SpinParameters {
    var topSpin: CGFloat      // 顺旋量 (-1.0 ~ 1.0)
    var sideSpin: CGFloat     // 侧旋量 (-1.0 ~ 1.0)
    var velocity: CGFloat     // 初速度
    var contactPoint: CGPoint // 击打点 (相对球心)
}

enum SpinEffect {
    case follow       // 高杆 - 顺旋前进
    case draw         // 低杆 - 逆旋后退
    case leftEnglish  // 左塞 - 库边右偏
    case rightEnglish // 右塞 - 库边左偏
    case stun         // 定杆 - 碰撞后停止
}
```

### 旋转对运动的影响

| 旋转类型 | 碰撞前影响 | 碰撞后影响 | 库边影响 |
|---------|-----------|-----------|---------|
| 高杆(顺旋) | 无 | 母球继续前进 | 角度变小 |
| 低杆(逆旋) | 无 | 母球后退 | 角度变大 |
| 左塞 | 轻微弧线 | 传递旋转 | 反弹角偏右 |
| 右塞 | 轻微弧线 | 传递旋转 | 反弹角偏左 |

---

## 五、瞄准系统设计

### 目录结构

```
Core/Aiming/
├── AimLine.swift           # 瞄准线渲染
├── GhostBall.swift         # 假想球显示
├── TrajectoryPredictor.swift # 轨迹预测
├── SeparationAngle.swift   # 分离角计算
└── DiamondSystem.swift     # 颗星公式计算
```

### 瞄准辅助显示

```
┌─────────────────────────────────────────┐
│                                         │
│     ○ 目标球                            │
│      ╲                                  │
│       ╲ 进袋线 (虚线)                   │
│    ◎ ───→ 瞄准点                        │
│   假想球  ↑                             │
│         击打方向                         │
│                                         │
│  ◉ 母球                                 │
│   ↑                                     │
│  击点显示 [●]                           │
│                                         │
│  分离角: 32°                            │
│  推荐杆法: 中杆偏高                      │
└─────────────────────────────────────────┘
```

### 颗星公式模块

```swift
class DiamondSystem {
    
    // 一库颗星计算
    func calculateOneRail(
        startPoint: DiamondPoint,
        targetPoint: DiamondPoint,
        spin: SpinParameters
    ) -> DiamondPoint {
        var aimPoint = startPoint.value - targetPoint.value
        aimPoint += spin.sideSpin * spinCorrectionFactor
        return DiamondPoint(value: aimPoint)
    }
    
    // 二库颗星计算
    func calculateTwoRail(...) -> DiamondPoint
    
    // 三库颗星计算
    func calculateThreeRail(...) -> DiamondPoint
}
```

---

## 六、数据模型设计

```swift
// 用户数据
@Model
class UserProfile {
    var id: UUID
    var nickname: String
    var level: Int
    var experience: Int
    var createdAt: Date
    
    var progress: CourseProgress?
    var statistics: UserStatistics?
    var purchases: [PurchaseRecord]
}

// 课程进度
@Model
class CourseProgress {
    var completedLessons: [Int]
    var currentLesson: Int
    var lessonScores: [Int: Int]
}

// 用户统计
@Model
class UserStatistics {
    var totalShots: Int
    var successfulShots: Int
    var practiceTime: TimeInterval
    var straightShotRate: Double
    var angleShotRates: [Int: Double]
    var spinUsage: [String: Int]
}

// 训练记录
@Model
class TrainingSession {
    var id: UUID
    var type: TrainingType
    var startTime: Date
    var endTime: Date
    var shots: [ShotRecord]
    var score: Int
}

// 单次击球记录
struct ShotRecord: Codable {
    var timestamp: Date
    var targetBall: BallPosition
    var cueBall: BallPosition
    var aimPoint: CGPoint
    var spin: SpinParameters
    var power: CGFloat
    var result: ShotResult
    var cueBallFinal: BallPosition
}
```

---

## 七、项目目录结构

```
BilliardTrainer/
├── App/
│   ├── BilliardTrainerApp.swift
│   └── AppDelegate.swift
│
├── Features/
│   ├── Home/
│   ├── Course/
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   └── Models/
│   ├── Training/
│   ├── Challenge/
│   ├── Statistics/
│   └── Settings/
│
├── Core/
│   ├── Physics/
│   │   ├── BilliardPhysics.swift
│   │   ├── SpinSystem.swift
│   │   └── CollisionHandler.swift
│   ├── Aiming/
│   │   ├── AimLine.swift
│   │   └── DiamondSystem.swift
│   ├── Camera/
│   │   └── CameraController.swift
│   ├── Scene/
│   │   ├── TableScene.swift
│   │   ├── BallNode.swift
│   │   └── CueNode.swift
│   └── Audio/
│
├── Services/
│   ├── DataService.swift
│   ├── IAPService.swift
│   └── AnalyticsService.swift
│
├── Models/
│   ├── UserProfile.swift
│   ├── CourseProgress.swift
│   └── TrainingSession.swift
│
├── Resources/
│   ├── Assets.xcassets
│   ├── Sounds/
│   └── Lessons/
│
└── Utilities/
    ├── Extensions/
    └── Constants/
```

---

## 八、关键技术难点与解决方案

| 难点 | 说明 | 解决方案 |
|------|------|---------|
| **旋转物理** | SceneKit原生不支持台球旋转 | 自定义旋转系统，在update循环中计算 |
| **库边旋转修正** | 塞球碰库边角度变化 | 基于真实物理公式实现修正算法 |
| **轨迹预测** | 需要预测多次碰撞 | 独立物理模拟器，快进计算轨迹 |
| **触控精度** | 打点选择需要精确 | 放大镜UI + 精细触控区域 |
| **性能优化** | 物理计算量大 | 帧率控制 + 简化远距离计算 |
| **2D/3D切换** | 相机平滑过渡 | SCNAction动画 + 插值计算 |

---

## 九、开发工作量估算

| 模块 | 预估工时 | 说明 |
|------|---------|------|
| 项目搭建 | 0.5周 | Xcode项目+基础架构 |
| 场景渲染 | 2周 | 球台、球体、材质、光照 |
| 物理引擎核心 | 3-4周 | 最复杂，需要反复调试 |
| 旋转系统 | 1-2周 | 自定义实现 |
| 相机系统 | 1周 | 多视角+手势控制 |
| 瞄准系统 | 2周 | 瞄准线+轨迹预测 |
| 颗星公式 | 1周 | 计算+可视化 |
| 课程系统 | 2周 | 8课内容+交互 |
| 训练场 | 2周 | 2个训练场 |
| 数据统计 | 1周 | 进度+统计 |
| 内购系统 | 1周 | StoreKit 2 |
| UI界面 | 2周 | 全部界面 |
| 测试调优 | 2周 | 物理参数+性能优化 |
| **V1.0 总计** | **20-23周** | 约5-6个月 |

---

## 十、开发里程碑

| 里程碑 | 时间 | 交付物 |
|--------|------|--------|
| M1 | 第4周 | 基础场景+物理引擎原型 |
| M2 | 第8周 | 完整物理+瞄准系统 |
| M3 | 第12周 | 课程系统+训练场 |
| M4 | 第16周 | 数据统计+内购 |
| M5 | 第20周 | 测试完成+准备上架 |
