# Training 模块 - 验证与回归

> 对应 README：[README.md](./README.md)
> 文档最后更新：2026-02-27

## 影响面清单

改动本模块时，必须检查以下影响面：

- [ ] 调用方：`TrainingListView`（训练列表）、`TrainingDetailView`（训练详情）、`TrainingSceneView`（训练场景）、`HomeView`（快捷入口导航）
- [ ] 共享常量/状态：`PhysicsConstants.TablePhysics.height`、`PhysicsConstants.BallPhysics.radius`（球位高度计算）、`BilliardSceneViewModel.GameState`（场景状态订阅）
- [ ] UI 交互链：训练列表 → 训练详情 → 训练场景 → 击球操作 → 结果展示 → 返回列表
- [ ] 持久化/数据映射：训练记录保存（如通过 `AppState` 或 SwiftData），最佳记录读取（`TrainingListView` 中的 `TrainingGround.bestScore`）
- [ ] 配置/开关：训练场锁定状态（`TrainingGround.isLocked`）、难度解锁条件

## 最小回归门禁

每次改动后必须验证（不可跳过）：

### 主路径验证

- [ ] **训练流程完整性**：从训练列表选择训练场 → 选择难度 → 开始训练 → 完成1次击球 → 进球 → 完成目标 → 查看结果 → 返回列表
- [ ] **一星瞄准训练特殊流程**：选择一星瞄准训练 → 验证仅2球布局（白球+目标球） → 完成1球目标 → 验证训练完成

### 相邻流程验证（至少 2 个）

- [ ] **暂停/恢复流程**：开始训练 → 暂停 → 验证计时器停止 → 恢复 → 验证计时器继续 → 完成训练
- [ ] **连击系统**：开始训练 → 连续进球3次 → 验证连击数递增 → 验证得分包含连击奖励 → 未进球 → 验证连击重置
- [ ] **限时训练**：选择限时训练（如30秒） → 开始训练 → 等待时间到 → 验证自动结束训练 → 验证结果包含用时统计
- [ ] **难度切换**：选择同一训练场的不同难度（1星 → 5星） → 验证得分加成变化 → 验证训练目标可能变化（一星瞄准例外）

## 测试入口

| 测试文件 | 覆盖内容 | 运行方式 |
|----------|----------|----------|
| `BilliardTrainerTests/Training/TrainingViewModelTests.swift` | `TrainingViewModel` 状态管理、得分计算、连击逻辑、计时器、训练完成判定 | `⌘U` / `swift test` |
| `BilliardTrainerTests/Training/TrainingConfigTests.swift` | `TrainingConfig` 预设配置、难度范围限制、球位布局生成 | `⌘U` / `swift test` |

## 可观测性

- 日志前缀：`[Training]`
- 关键观测点：
  - `TrainingViewModel.startTraining()`：训练开始，记录配置信息（训练类型、难度、目标进球数、时间限制）
  - `TrainingViewModel.handleBallPocketed()`：进球事件，记录得分、连击数、剩余球数
  - `TrainingViewModel.endTraining()`：训练结束，记录最终结果（得分、进球数、用时、星级）
  - `TrainingViewModel.calculateFinalResult()`：结果计算，记录得分、最大可能得分、星级
- 可视化开关：训练场景中的 HUD 显示实时得分、连击、进度、剩余时间，可用于调试状态

## 常见问题排查

| 症状 | 可能原因 | 排查路径 |
|------|----------|----------|
| 训练无法开始，场景未设置 | `setupScene()` 失败，`sceneViewModel.setupTrainingScene()` 返回错误 | 检查 `TrainingConfig` 参数有效性，检查场景初始化状态，查看 Scene 模块日志 |
| 进球后得分未更新 | `onTargetBallPocketed` 回调未触发或未设置 | 检查 `TrainingViewModel.setupBindings()` 中回调设置，检查 `BilliardSceneViewModel` 事件触发逻辑 |
| 连击未重置 | `didPocketThisShot` 标志未正确维护 | 检查 `handleBallPocketed()` 中设置 `didPocketThisShot = true`，检查 `onShotCompleted` 中重置逻辑 |
| 计时器不停止 | `deinit` 中未调用 `timer?.invalidate()` | 检查 `TrainingViewModel` 生命周期，确保 `deinit` 正确执行，检查是否有循环引用 |
| 一星瞄准训练显示16球 | `BallPosition.randomTwoBallLayout()` 未正确应用 | 检查 `TrainingConfig.aimingConfig(difficulty: 1)` 中 `ballPositions` 设置，检查场景布局应用逻辑 |
| 星级评价不正确 | `TrainingResult.calculateStars()` 阈值错误或 `maxScore` 计算错误 | 检查得分计算逻辑（基础分+连击奖励+难度加成），检查最大可能得分计算，验证星级阈值 |

## 未覆盖风险与待补测项

| 风险描述 | 等级 | 建议补测方式 |
|----------|------|-------------|
| 随机布局生成重叠（超过100次尝试） | 低 | 单元测试：模拟极端情况，验证返回布局的有效性，场景层应检测并拒绝重叠布局 |
| 场景事件回调时序问题（回调延迟或乱序） | 中 | 集成测试：模拟快速连续击球，验证事件处理顺序，检查状态一致性 |
| 训练记录持久化失败 | 中 | 集成测试：模拟数据保存失败场景，验证降级策略（如仅内存缓存，不持久化） |
| 多训练场景并发（理论上不可能，但需验证） | 低 | 代码审查：确保 `TrainingViewModel` 和 `BilliardSceneViewModel` 实例隔离，无共享状态 |
| 计时器精度问题（系统时间变更） | 低 | 单元测试：模拟系统时间跳变，验证计时器行为，考虑使用 `Date` 差值而非累计计数 |

## 变更验证记录

| 日期 | 变更摘要 | 验证结果 | 未覆盖项 |
|------|----------|----------|----------|
| 2026-02-27 | 创建模块文档 | 文档创建完成，待代码验证 | 无 |
