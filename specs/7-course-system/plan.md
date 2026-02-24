# 实施计划：课程系统 (Course System)

**分支**: `7-course-system` | **日期**: 2025-02-20 | **规格**: [spec.md](./spec.md)  
**说明**: 课程系统技术实施方案，定义数据模型、场景架构与实现阶段

## 摘要

课程系统在现有 BilliardScene、EventDrivenEngine、TrainingSceneView 基础上构建课程场景框架。采用「教学内容数据 + 练习场景配置」分离设计，LessonData 描述课时结构，LessonScenario 描述练习任务。课程场景通过 CourseSceneView 承载，内部状态机管理教学→练习→完成三阶段流转。L1-L8 内容以 JSON 或 Swift 静态数据形式定义，便于后续扩展。

## 技术上下文

| 项目 | 说明 |
|------|------|
| **语言/版本** | Swift 5.x |
| **UI 框架** | SwiftUI |
| **3D 渲染** | SceneKit |
| **持久化** | SwiftData (iOS 17+) |
| **目标平台** | iOS 17+ |
| **物理引擎** | EventDrivenEngine（事件驱动，非 SCNPhysicsWorld） |
| **瞄准系统** | AimingSystem、DiamondSystem |
| **训练框架** | TrainingSceneView、TrainingViewModel、TrainingConfig、BilliardSceneView |

## 项目结构

### 课程模块目录

```text
current_work/BilliardTrainer/
├── Features/
│   └── Course/
│       ├── Models/
│       │   ├── Course.swift              # Course 模型（已有，可扩展）
│       │   ├── LessonData.swift          # 课时内容数据模型
│       │   ├── LessonStep.swift          # 教学步骤模型
│       │   ├── LessonScenario.swift      # 练习场景模型
│       │   └── LessonContentProvider.swift # 课时内容提供者（L1-L8 数据）
│       ├── Views/
│       │   ├── CourseListView.swift      # 课程列表（已存在）
│       │   ├── CourseSceneView.swift    # 课程场景主视图
│       │   ├── TeachingPhaseView.swift  # 教学阶段 UI
│       │   ├── PracticePhaseView.swift  # 练习阶段 UI（复用/包装 BilliardSceneView）
│       │   └── CompletionPhaseView.swift # 完成阶段 UI
│       └── ViewModels/
│           ├── CourseSceneViewModel.swift   # 课程场景状态机
│           └── CourseProgressService.swift # 进度读写封装
```

### 与现有模块的关系

```text
Core/
├── Scene/
│   ├── BilliardScene.swift          # 球桌、球、相机、瞄准线
│   ├── BilliardSceneView.swift      # SceneKit 视图容器
│   └── TableModelLoader.swift
├── Physics/
│   ├── EventDrivenEngine.swift      # 物理模拟、进袋检测
│   └── ...
└── Aiming/
    └── AimingSystem.swift

Features/
├── Course/                          # 课程模块（本功能）
│   └── 依赖 BilliardScene、EventDrivenEngine、TrainingConfig 能力
└── Training/
    ├── TrainingSceneView.swift     # 训练场景（可复用结构）
    ├── TrainingViewModel.swift
    └── TrainingConfig.swift        # BallPosition、TargetZone 等
```

## 数据模型设计

### LessonData

课时内容根模型，描述单节课程的全部流程。

```swift
struct LessonData {
    let lessonId: Int
    let title: String
    let duration: Int  // 分钟
    let steps: [LessonStep]           // 教学步骤
    let scenarios: [LessonScenario]    // 练习场景
    let passCondition: PassCondition   // 通过条件
}

enum PassCondition {
    case quizCorrectRate(minimum: Double)   // 测验正确率，如 0.8
    case pocketCount(required: Int)        // 进球数，如 3、10
    case hitRate(minimum: Double)           // 命中率，如 0.5
    case techniqueCount(technique: SpinType, minCount: Int)  // 某技法成功次数
    case allScenariosComplete             // 完成所有子场景
    case positionSuccessCount(minimum: Int) // 走位成功次数
}
```

### LessonStep

单步教学内容，支持文本、插图、动画、测验。

```swift
struct LessonStep {
    let stepType: LessonStepType
    let content: String
    let mediaRef: String?            // 插图/动画资源名
    let quizOptions: [String]?       // 测验选项（仅 quiz 类型）
    let correctOptionIndex: Int?     // 正确答案索引
}

enum LessonStepType {
    case text
    case illustration
    case animation
    case quiz
}
```

### LessonScenario

单次练习任务配置，与 TrainingConfig 概念类似但更具体。

```swift
struct LessonScenario {
    let scenarioType: LessonScenarioType
    let ballPositions: [BallPosition]
    let targetZone: TargetZone?
    let taskPrompt: String
    let scoringRule: ScenarioScoringRule
    let passThreshold: Int?          // 本场景通过阈值（可选）
}

enum LessonScenarioType {
    case straightShot(count: Int)
    case angleShot(angle: Float, count: Int)
    case spinTechnique(SpinType, minSuccess: Int)
    case separationAnglePrediction(count: Int)
    case englishCushionDrill
    case positionPlay(minSuccess: Int)
}
```

### LessonContentProvider

集中提供 L1-L8 的 LessonData，便于加载与扩展。

```swift
struct LessonContentProvider {
    static func load(lessonId: Int) -> LessonData?
    static var allLessonIds: [Int] { get }
}
```

## 课程场景与现有组件的集成

### 场景流程状态机

```
CourseSceneViewModel 状态:
  - phase: .teaching | .practice | .completion
  - currentStepIndex: Int
  - currentScenarioIndex: Int
  - scenarioScore: [场景内得分]
  - totalScore: Int
  - passed: Bool
```

### 教学阶段 (TeachingPhaseView)

- 展示 LessonStep：文本 + 可选插图 + 可选动画
- quiz 类型：显示选项，用户选择后校验 correctOptionIndex
- 下一步按钮推进 currentStepIndex，直到 steps 结束 → 切换 phase = .practice

### 练习阶段 (PracticePhaseView)

- 将 LessonScenario 转为 TrainingConfig 等价配置
- 嵌入 BilliardSceneView，复用：
  - BilliardScene 球桌、球、瞄准线、打点选择
  - EventDrivenEngine 物理模拟
  - 进袋/碰撞检测
- 根据 scenarioType 初始化球位（ballPositions）
- 显示 taskPrompt 作为 HUD 提示
- 每击完成后，根据 scoringRule 判定得分、是否通过本场景
- 全部 scenarios 完成且满足 passCondition → phase = .completion

### 完成阶段 (CompletionPhaseView)

- 显示得分、星级（1-5）
- 调用 CourseProgress.markCompleted(score:)
- 返回列表 / 下一课按钮

### 与 BilliardScene 的集成方式

- **方案 A**: Course 的 PracticePhaseView 内嵌一个「课程版」BilliardSceneView，传入 CourseSceneViewModel 中的 sceneViewModel（类似 TrainingViewModel.sceneViewModel）
- **方案 B**: 新建 CourseBilliardSceneView，继承或组合 BilliardSceneView，增加课程专用 HUD（任务提示、场景进度）
- **推荐**: 方案 A，通过 ViewModel 桥接，最小化对 Training 模块的侵入

### 与 EventDrivenEngine 的集成

- EventDrivenEngine 已支持进袋检测（PhysicsEventType.pocket）、球-球碰撞、球-库碰撞
- 课程场景需要：
  1. 初始化球位（根据 LessonScenario.ballPositions）
  2. 监听进袋事件，判定目标球进袋 / 母球进袋
  3. 根据进球结果更新 scenarioScore、判断通过条件
- BilliardSceneViewModel（或 Training 中的等价）已与 EventDrivenEngine 对接，课程可复用该桥接层

## 阶段 0：研究项

- **R0-1**: 确认 EventDrivenEngine 与 BilliardScene 的进袋回调机制，确定课程如何注册「进球」事件
- **R0-2**: 确认 BilliardScene 的 resetScene、球位初始化的 API，能否从外部传入 BallPosition 列表动态布置
- **R0-3**: 确认 TrainingConfig / TrainingViewModel 的球位配置方式，课程场景是否可直接复用 BallPosition、TargetZone
- **R0-4**: 评估 L1 测验的 UI 形式：独立 QuizView 还是嵌入 TeachingPhaseView 的弹窗/内联

## 阶段 1：设计决策

### D1-1: 课程内容存储形式

- **选项**: JSON 文件 / Swift 静态结构 / SwiftData
- **建议**: Swift 静态结构（LessonContentProvider 内 hardcode 或从 Bundle 读取 JSON）。V1 优先用 Swift 便于类型安全，后续可迁移 JSON 以支持远程更新

### D1-2: 课程场景与训练场景的复用边界

- **决策**: Course 的 PracticePhaseView 复用 BilliardSceneView + 现有 ViewModel 桥接，不复制 TrainingViewModel，而是新建 CourseSceneViewModel 持有类似的 scene 控制逻辑
- **理由**: 课程有「多场景顺序执行」「通过条件校验」等差异，需要独立状态机

### D1-3: IAP 产品 ID 与解锁逻辑

- **产品 ID**: `basic_course_pack`（或项目内约定 ID）
- **解锁**: UserProfile.hasPurchased("basic_course_pack") 为 true 时，L4-L8 可进入
- **StoreKit 2**: 建议使用 StoreKit 2 的 Transaction.currentEntitlements 验证，具体实现可放在单独的 IAP 服务中

### D1-4: 课程列表与 CourseProgress 的绑定

- **当前**: CourseListView 使用 Course 静态数据，isCompleted 为硬编码
- **目标**: CourseListView 注入 ModelContext，按 userId 查询 CourseProgress，动态设置每课的 isCompleted、bestScore
- **实现**: CourseCard 接收 CourseProgress?，有则显示完成状态与最高分

## 与现有代码的衔接点

| 现有组件 | 课程系统使用方式 |
|----------|------------------|
| BilliardScene | 课程练习阶段需要动态设置球位，需确认 setupModelBalls / createTargetBall / 初始位置 API |
| BilliardSceneView | 作为 PracticePhaseView 的子视图嵌入 |
| EventDrivenEngine | 通过现有桥接监听 pocket 事件，课程层根据 ball name 判断进球 |
| TrainingConfig | LessonScenario 可转换为 BallPosition[]、TargetZone，构造类似 config |
| CourseProgress | 课程完成后 markCompleted，列表按 courseId 查询 |
| UserProfile | hasPurchased 检查 L4-L8 解锁 |
| OrientationHelper | 进入课程场景 forceLandscape，退出 restorePortrait |
