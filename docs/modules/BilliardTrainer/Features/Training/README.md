# Training 模块

> 代码路径：`BilliardTrainer/Features/Training/`
> 文档最后更新：2026-02-27

## 模块定位

Training 模块是 BilliardTrainer 的核心训练功能模块，提供瞄准、杆法、翻袋、K球、颗星等5种训练场景，支持1-5星难度分级、计时挑战、连击奖励、星级评价等完整的训练体系。该模块不处理游戏规则判定（由 FreePlay 模块处理），专注于训练场景的配置、状态管理和结果统计。

## 入口文件

| 文件 | 职责 | 行数 |
|------|------|------|
| `Models/TrainingConfig.swift` | 训练配置模型，包含训练类型、难度、球位布局、目标区域、时间限制、目标进球数等配置项，提供5种预设配置工厂方法 | ~334 |
| `ViewModels/TrainingViewModel.swift` | 训练状态管理，订阅场景事件，管理得分、连击、计时器、训练完成判定，计算最终结果 | ~330 |
| `Views/TrainingListView.swift` | 训练场列表视图，展示5种训练场卡片、难度星级、最佳记录、锁定状态，包含挑战专区 | ~294 |
| `Views/TrainingDetailView.swift` | 训练详情页，难度选择器（1-5星）、训练说明、历史最佳记录、开始训练按钮，创建配置并打开训练场景 | ~303 |
| `Views/TrainingSceneView.swift` | 训练场景全屏视图，集成 SceneKit 场景与 HUD（得分、进度、暂停菜单、结果浮层），强制横屏，根据游戏状态显示/隐藏控件 | ~511 |
| `Views/PowerGaugeView.swift` | 力度滑块控件，垂直0-100力度条，触摸拖拽控制，Canvas 渐变绘制，释放时触发击球 | ~215 |
| `Views/CuePointSelectorView.swift` | 打点选择器，圆形母球横截面视图，拖拽选择击球点，映射到0-1范围并限制在圆内，显示旋转标签（中杆/高杆/低杆/左塞/右塞） | ~129 |

## 核心概念与术语

| 术语 | 含义 |
|------|------|
| **训练场（Training Ground）** | 5种训练类型：瞄准、杆法、翻袋、K球、颗星，每种有独立的难度分级和最佳记录 |
| **难度星级（Difficulty Stars）** | 1-5星难度等级，影响得分加成和训练目标，一星瞄准训练仅2球布局 |
| **连击（Combo）** | 连续进球数，每次进球增加连击，未进球或母球落袋重置，连击数影响得分奖励 |
| **目标区域（Target Zone）** | 用于走位训练的可选区域，定义中心位置、半径和颜色，用于判定走位精度 |
| **训练结果（Training Result）** | 包含得分、进球数、总击球数、用时、星级评价、进球率等统计信息 |
| **球位布局（Ball Position Layout）** | 训练场景中球的初始位置配置，支持预设布局和随机两球布局（一星瞄准） |
| **星级评价算法** | 根据得分与最大可能得分的比例计算1-5星：≥90%为5星，75-90%为4星，60-75%为3星，40-60%为2星，<40%为1星 |

## 端到端流程

```
用户选择训练场（TrainingListView）
  ↓
选择难度（TrainingDetailView）
  ↓
创建 TrainingConfig（预设工厂方法）
  ↓
打开 TrainingSceneView（fullScreenCover）
  ↓
TrainingViewModel 初始化并设置场景
  ↓
开始训练：启动计时器、设置球位、切换到瞄准态
  ↓
用户瞄准 → 选择打点 → 调整力度 → 击球
  ↓
BilliardSceneViewModel 执行物理模拟
  ↓
场景事件回调 → TrainingViewModel 处理进球/未进球
  ↓
进球：增加得分、连击、进球数；检查是否完成目标
  ↓
未进球或母球落袋：重置连击
  ↓
击球完成 → 准备下一击或结束训练
  ↓
训练完成：计算结果、显示结果浮层、保存记录
```

## 对外能力（Public API）

### TrainingConfig

- `init(groundId:difficulty:ballPositions:targetZone:timeLimit:goalCount:trainingType:)`：创建训练配置
- `static func aimingConfig(difficulty:) -> TrainingConfig`：瞄准训练预设配置
- `static func spinConfig(difficulty:) -> TrainingConfig`：杆法训练预设配置
- `static func bankShotConfig(difficulty:) -> TrainingConfig`：翻袋训练预设配置
- `static func kickShotConfig(difficulty:) -> TrainingConfig`：K球训练预设配置
- `static func diamondConfig(difficulty:) -> TrainingConfig`：颗星训练预设配置

### TrainingViewModel

- `init(config: TrainingConfig)`：初始化训练视图模型
- `startTraining()`：开始训练，重置状态，设置场景，启动计时器
- `pauseTraining()`：暂停训练，停止计时器
- `resumeTraining()`：恢复训练，重启计时器
- `endTraining()`：结束训练，停止计时器，显示结果
- `restartTraining()`：重新开始训练
- `calculateFinalResult() -> TrainingResult`：计算最终训练结果

### TrainingSceneType

- `case aiming`：瞄准训练
- `case spin`：杆法训练
- `case bankShot`：翻袋训练
- `case kickShot`：K球训练
- `case diamond`：颗星训练
- `var iconName: String`：图标名称
- `var description: String`：训练说明

### BallPosition

- `init(ballNumber:position:)`：创建球位配置
- `init(ballNumber:x:z:)`：从x/z坐标创建球位（自动设置y高度）
- `static func randomTwoBallLayout() -> [BallPosition]`：随机生成2球布局（白球+目标球，避免重叠）

### TrainingResult

- `var accuracy: Double`：进球率（0-1）
- `var formattedAccuracy: String`：格式化进球率（百分比）
- `var formattedDuration: String`：格式化时长（MM:SS）
- `static func calculateStars(score:maxScore:) -> Int`：根据得分计算星级

## 依赖与边界

- **依赖**：
  - `Core/Scene`：`BilliardSceneViewModel`（场景状态管理、物理模拟、事件回调）
  - `Core/Physics`：`PhysicsConstants`（`TablePhysics`、`BallPhysics`，用于球位高度计算）
  - `SwiftUI`：视图框架
  - `Combine`：响应式状态订阅
- **被依赖**：
  - `Features/Home`：`HomeView` 通过快捷入口导航到训练列表
  - `App/ContentView`：`MainTabView` 包含 `TrainingListView` 作为 Tab 页
- **共享组件**：
  - `PowerGaugeView`：与 `FreePlay` 模块共享力度滑块控件
  - `CuePointSelectorView`：与 `FreePlay` 模块共享打点选择器控件
- **禁止依赖**：不应依赖 `Features` 层其他业务模块（如 `FreePlay`、`Course`）

## 与其他模块的耦合点

- **Scene 模块**：
  - `TrainingViewModel` 持有 `BilliardSceneViewModel`，通过 `setupTrainingScene()` 设置场景，订阅 `$gameState` 和事件回调（`onTargetBallPocketed`、`onCueBallPocketed`、`onShotCompleted`）
  - `TrainingSceneView` 嵌入 `BilliardSceneView`，通过 `sceneViewModel` 访问场景状态
  - 球位布局通过 `BallPosition` 数组传递给场景，场景负责应用布局并隐藏未使用的球
- **PhysicsConstants**：
  - `BallPosition` 使用 `TablePhysics.height` 和 `BallPhysics.radius` 计算球位y坐标，必须与物理引擎保持一致
- **FreePlay 模块**：
  - 共享 `PowerGaugeView` 和 `CuePointSelectorView` 组件，但训练模块的击球逻辑独立，不依赖游戏规则

## 关键数据结构

| 结构/枚举 | 字段/Case | 单位/生命周期 |
|-----------|-----------|---------------|
| `TrainingConfig` | `groundId: String`, `difficulty: Int`, `ballPositions: [BallPosition]`, `targetZone: TargetZone?`, `timeLimit: Int?`, `goalCount: Int`, `trainingType: TrainingSceneType` | 难度：1-5星，时间限制：秒，目标进球数：整数，训练生命周期内保持不变 |
| `TrainingSceneType` | `.aiming`, `.spin`, `.bankShot`, `.kickShot`, `.diamond` | 枚举，训练类型标识 |
| `BallPosition` | `ballNumber: Int`, `position: SCNVector3` | 球号：0=母球，1-15=目标球，位置：米（m），SceneKit 坐标系 |
| `TargetZone` | `center: SCNVector3`, `radius: Float`, `color: (r,g,b,a)` | 中心：米（m），半径：米（m），颜色：RGBA 0-1，可选配置项 |
| `TrainingResult` | `score: Int`, `pocketedCount: Int`, `totalShots: Int`, `duration: Int`, `stars: Int` | 得分：整数，进球数/击球数：整数，用时：秒，星级：1-5，训练结束时计算 |
| `TrainingViewModel` | `@Published` 状态：`currentScore`, `remainingBalls`, `timeRemaining`, `shotCount`, `pocketedCount`, `isTrainingComplete`, `isPaused`, `showResult`, `comboCount`, `maxCombo` | 训练会话生命周期内持续更新 |

## 内部结构

### 模型层（Models）
- **TrainingConfig.swift**：训练配置模型，包含所有训练参数和预设配置工厂方法
- **TrainingSceneType**：训练类型枚举，定义5种训练场景
- **BallPosition**：球位配置结构，支持预设位置和随机布局生成
- **TargetZone**：目标区域结构，用于走位训练的区域判定
- **TrainingResult**：训练结果结构，包含统计信息和星级计算算法

### 视图模型层（ViewModels）
- **TrainingViewModel.swift**：训练状态管理，订阅场景事件，管理得分、连击、计时器，计算最终结果

### 视图层（Views）
- **TrainingListView.swift**：训练场列表，展示训练场卡片和挑战专区
- **TrainingDetailView.swift**：训练详情页，难度选择和开始训练
- **TrainingSceneView.swift**：训练场景全屏视图，集成3D场景和HUD覆盖层
- **PowerGaugeView.swift**：力度滑块控件（共享组件）
- **CuePointSelectorView.swift**：打点选择器（共享组件）

## 最近变更记录

| 日期 | 变更摘要 | 影响面 |
|------|----------|--------|
| 2026-02-27 | 创建模块文档 | 无代码变更 |
