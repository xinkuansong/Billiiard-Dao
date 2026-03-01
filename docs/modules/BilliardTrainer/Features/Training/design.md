# Training 模块 - 设计与约束

> 对应 README：[README.md](./README.md)
> 文档最后更新：2026-02-27

## 设计目标与非目标

- **目标**：
  - 提供结构化的训练场景配置系统，支持5种训练类型和1-5星难度分级
  - 实现完整的训练状态管理，包括得分、连击、计时、进度追踪
  - 通过预设配置工厂方法简化训练场景创建，避免配置错误
  - 与 Scene 模块解耦，通过 ViewModel 和回调接口交互，不直接操作场景节点
- **非目标**：
  - 不处理游戏规则判定（由 FreePlay 模块的 `EightBallGameManager` 处理）
  - 不实现物理计算（由 Physics 模块处理）
  - 不管理用户数据和持久化（由 AppState 或其他数据层处理）

## 不变量与约束（改动护栏）

### 单位与坐标系

- 所有长度单位为米（m），角度为弧度（rad）
- `BallPosition.position` 使用 SceneKit 坐标系（Y-up），y坐标必须为 `TablePhysics.height + BallPhysics.radius + 0.001`
- `TargetZone.center` 的y坐标必须为 `TablePhysics.height + 0.001`（台面高度）
- 时间单位：秒（s），`timeLimit` 和 `duration` 均为整数秒

### 数值稳定性保护

- **难度范围限制**：`TrainingConfig.init()` 中 `difficulty` 自动限制在 1-5 范围内（`min(max(difficulty, 1), 5)`），防止无效难度值
- **随机布局重叠保护**：`BallPosition.randomTwoBallLayout()` 中两球最小中心距为 `2 * BallPhysics.radius + 0.01`，最多尝试100次避免重叠，防止无限循环
- **进球率计算保护**：`TrainingResult.accuracy` 和 `TrainingViewModel.accuracy` 中检查 `totalShots > 0`，避免除零错误
- **计时器生命周期**：`TrainingViewModel` 的 `deinit` 中必须调用 `timer?.invalidate()`，防止内存泄漏和后台继续运行

### 时序与状态约束

- **训练生命周期**：`startTraining()` → `pauseTraining()`/`resumeTraining()` → `endTraining()`，不可跳过初始化直接暂停
- **场景设置时序**：必须在 `startTraining()` 中先调用 `setupScene()`，再启动计时器，确保场景就绪后再开始计时
- **事件回调时序**：`onShotCompleted` 回调在物理模拟完成后触发，此时 `shotEvents` 已包含完整事件记录，`TrainingViewModel` 必须在此回调中处理连击重置
- **连击重置时机**：连击在以下情况重置：未进球（`onShotCompleted` 中 `didPocketThisShot == false`）、母球落袋（`onCueBallPocketed` 回调），不可在其他时机重置

### 常量与阈值清单

| 常量/阈值 | 值 | 来源/理由 | 改动影响 |
|-----------|-----|----------|----------|
| `difficulty` 范围 | 1-5 | 业务需求，5星难度体系 | 影响得分加成计算（`difficultyBonus = config.difficulty * 10`） |
| `goalCount` 默认值 | 10 | 训练目标设定，一星瞄准例外为1 | 影响训练完成判定和进度计算 |
| 基础得分 | 100 | 每次进球基础分 | 影响得分计算和星级评价 |
| 连击奖励系数 | 20 | 每连击额外得分 | 影响得分计算（`comboBonus = (comboCount - 1) * 20`） |
| 难度加成系数 | 10 | 每星难度额外得分 | 影响得分计算（`difficultyBonus = config.difficulty * 10`） |
| 星级评价阈值 | 90%/75%/60%/40% | `TrainingResult.calculateStars()` 中的比例阈值 | 影响星级评价结果，改动需同步更新UI显示逻辑 |
| 两球最小中心距 | `2 * BallPhysics.radius + 0.01` | 防止球重叠，0.01m安全余量 | 影响随机布局生成，必须与物理引擎球半径一致 |
| 随机布局最大尝试次数 | 100 | 防止无限循环 | 影响随机布局生成性能，超过100次可能返回重叠布局 |

## 状态机 / 事件模型

### TrainingViewModel 状态机

```
未开始 (初始状态)
  ↓ startTraining()
进行中 (isTrainingComplete = false, isPaused = false)
  ├─ pauseTraining() → 暂停中 (isPaused = true)
  │   └─ resumeTraining() → 进行中
  ├─ 进球 → 更新得分/连击 → 检查目标完成
  │   └─ pocketedCount >= goalCount → endTraining()
  ├─ 时间到 (timeRemaining == 0) → endTraining()
  └─ endTraining() → 已完成 (isTrainingComplete = true, showResult = true)
```

### 连击状态机

```
连击数 = 0 (初始/重置)
  ↓ 进球 (handleBallPocketed)
连击数 += 1, didPocketThisShot = true
  ↓ 再次进球
连击数 += 1 (持续累加)
  ├─ 未进球 (onShotCompleted, didPocketThisShot = false) → 重置为0
  └─ 母球落袋 (onCueBallPocketed) → 重置为0
```

## 错误处理与降级策略

- **场景设置失败**：`setupScene()` 中调用 `sceneViewModel.setupTrainingScene()` 失败时，训练无法开始，应在UI层显示错误提示
- **计时器创建失败**：`startTimer()` 中 `Timer.scheduledTimer` 失败时，无限时训练不受影响，限时训练应降级为无限时模式
- **随机布局生成失败**：`BallPosition.randomTwoBallLayout()` 超过100次尝试仍重叠时，返回可能重叠的布局，场景层应检测并拒绝无效布局
- **得分计算溢出**：得分计算使用 `Int`，理论上限为 `Int.max`，实际训练中不可能达到，无需特殊处理
- **场景事件回调缺失**：`TrainingViewModel` 依赖 `sceneViewModel` 的回调，若回调未设置或为nil，进球和击球完成事件无法处理，训练状态可能不一致，应在初始化时确保回调设置

## 性能考量

- **计时器频率**：使用 `Timer.scheduledTimer(withTimeInterval: 1.0)`，每秒更新一次，对性能影响可忽略
- **Combine 订阅**：`TrainingViewModel` 订阅 `sceneViewModel.$gameState`，使用 `[weak self]` 避免循环引用，在 `deinit` 中自动取消订阅（`cancellables` 集合销毁时）
- **状态更新频率**：`@Published` 属性变更会触发 SwiftUI 视图更新，进球和击球完成事件频率较低（每秒最多1-2次），性能影响可接受
- **随机布局生成**：`BallPosition.randomTwoBallLayout()` 平均尝试次数 < 10次，最坏情况100次，时间复杂度 O(1)，性能可接受

## 参考实现对照（如适用）

| Swift 文件/函数 | 参考来源 | 偏离说明 |
|----------------|--------------|----------|
| `BallPosition` 球位高度计算 | `PhysicsConstants.TablePhysics.height + BallPhysics.radius` | 与物理引擎保持一致，确保球位在台面上方 |
| `TrainingResult.calculateStars()` | 业务需求，无参考实现 | 星级评价算法为业务逻辑，根据得分比例计算 |

## 设计决策记录（ADR）

### ADR-001：使用预设配置工厂方法而非直接初始化

- **背景**：训练配置参数较多（7个参数），直接初始化容易出错，且不同训练类型有固定模式
- **候选方案**：
  1. 直接使用 `TrainingConfig.init()` 传入所有参数
  2. 使用预设配置工厂方法（`aimingConfig()`, `spinConfig()` 等）
  3. 使用 Builder 模式构建配置
- **结论**：选择方案2，预设工厂方法简化调用，减少配置错误，代码更清晰
- **后果**：新增训练类型需要添加新的工厂方法，但维护成本低

### ADR-002：TrainingViewModel 持有 BilliardSceneViewModel 而非通过依赖注入

- **背景**：`TrainingViewModel` 需要访问场景状态和设置场景，需要持有 `BilliardSceneViewModel`
- **候选方案**：
  1. `TrainingViewModel` 内部创建 `BilliardSceneViewModel`
  2. 通过依赖注入传入 `BilliardSceneViewModel`
  3. 使用单例或全局访问
- **结论**：选择方案1，训练场景是训练模块的私有资源，不需要外部共享，简化依赖关系
- **后果**：每个训练会话创建新的场景实例，内存占用略高，但训练场景生命周期短，可接受

### ADR-003：连击状态使用 didPocketThisShot 标志而非事件时间戳比较

- **背景**：需要在击球完成时判断本次击球是否有进球，以决定是否重置连击
- **候选方案**：
  1. 使用 `didPocketThisShot` Bool 标志，进球时设置为 true，击球完成时检查
  2. 比较 `onTargetBallPocketed` 和 `onShotCompleted` 的时间戳
  3. 在 `onShotCompleted` 回调参数中传入是否进球标志
- **结论**：选择方案1，简单可靠，不依赖时间戳精度，代码清晰
- **后果**：需要在多个回调中维护标志状态，但逻辑简单，维护成本低
