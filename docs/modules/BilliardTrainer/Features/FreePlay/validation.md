# FreePlay 模块 - 验证与回归

> 对应 README：[README.md](./README.md)
> 文档最后更新：2026-02-27

## 影响面清单

改动本模块时，必须检查以下影响面：

- [ ] 调用方：`FreePlayView`（自由练习视图）、`HomeView`（快捷入口导航）
- [ ] 共享常量/状态：`BilliardSceneViewModel.GameState`（场景状态订阅）、`EightBallGameManager`（游戏规则状态）
- [ ] UI 交互链：进入自由练习 → 放置母球 → 开球 → 选球 → 击球 → 犯规处理 → 游戏结束 → 返回
- [ ] 持久化/数据映射：游戏记录保存（如通过 `AppState` 或 SwiftData），统计数据（击球数、进球数、进球率）
- [ ] 配置/开关：无特殊配置项

## 最小回归门禁

每次改动后必须验证（不可跳过）：

### 主路径验证

- [ ] **完整游戏流程**：开始新游戏 → 放置母球 → 开球 → 首次进球确定球组 → 连续进球 → 清台 → 打8号球 → 8号球进袋 → 游戏结束 → 显示结果
- [ ] **开球流程**：开始新游戏 → 验证开球布局（15球排列） → 开球 → 验证首次进球确定球组逻辑

### 相邻流程验证（至少 2 个）

- [ ] **犯规处理流程**：进行中 → 犯规（如母球落袋） → 验证犯规提示显示 → 验证自由球模式 → 放置母球 → 继续游戏
- [ ] **选球验证流程**：确定球组后 → 尝试选择对方球组 → 验证警告提示 → 尝试选择8号球（未清台） → 验证警告提示 → 选择正确球组 → 验证允许击球
- [ ] **游戏结束流程**：清台后 → 打8号球 → 8号球进袋 → 验证游戏结束浮层显示 → 验证胜负判定正确
- [ ] **暂停/恢复流程**：进行中 → 暂停 → 验证游戏状态冻结 → 恢复 → 验证游戏继续

## 测试入口

| 测试文件 | 覆盖内容 | 运行方式 |
|----------|----------|----------|
| 暂无专用测试文件 | 待补充 | 待补充 |

**注意**：FreePlay 模块目前没有专用的单元测试文件，建议补充以下测试：
- `FreePlayViewModelTests.swift`：ViewModel 状态管理、击球处理、选球验证、游戏阶段转换
- `FreePlayIntegrationTests.swift`：完整游戏流程集成测试

## 可观测性

- 日志前缀：`[FreePlay]`
- 关键观测点：
  - `FreePlayViewModel.startNewGame()`：游戏开始，记录初始状态
  - `FreePlayViewModel.onShotFinished()`：击球完成，记录事件数量、游戏阶段变化
  - `FreePlayViewModel.validateBallSelection()`：选球验证，记录验证结果和警告消息
  - `gameManager.processShot()`：游戏规则处理，记录阶段转换、犯规判定、游戏结束判定
- 可视化开关：游戏场景中的 HUD 显示球组、剩余球数、状态消息，可用于调试状态

## 常见问题排查

| 症状 | 可能原因 | 排查路径 |
|------|----------|----------|
| 游戏无法开始，场景未设置 | `startNewGame()` 中场景设置失败 | 检查 `sceneViewModel.scene.setupRackLayout()` 是否成功，检查场景初始化状态，查看 Scene 模块日志 |
| 击球完成后游戏状态未更新 | `onShotFinished()` 回调未触发或 `gameManager.processShot()` 失败 | 检查 `setupBindings()` 中 `onShotCompleted` 回调设置，检查 `gameManager` 初始化状态，查看游戏管理器日志 |
| 选球验证不生效 | `ballSelectionValidator` 闭包未设置或验证逻辑错误 | 检查 `setupBindings()` 中 `ballSelectionValidator` 设置，检查 `validateBallSelection()` 逻辑，验证球名解析 |
| 犯规提示不显示 | `foulFlash` 状态未更新或UI未响应 | 检查 `onShotFinished()` 中 `isBallInHand` 判断，检查 `foulFlash` 状态更新，检查 `FoulBanner` 显示条件 |
| 游戏结束浮层不显示 | `showGameOverOverlay` 状态未更新或延迟未触发 | 检查 `onShotFinished()` 中 `isGameOver` 判断，检查延迟逻辑，检查 `GameOverOverlay` 显示条件 |
| 自由球模式未进入 | `enterPlacingMode()` 未调用或延迟未触发 | 检查 `onShotFinished()` 中 `isBallInHand` 判断，检查延迟逻辑，检查 `isGameOver` 冲突检查 |

## 未覆盖风险与待补测项

| 风险描述 | 等级 | 建议补测方式 |
|----------|------|-------------|
| 游戏规则逻辑错误（EightBallGameManager） | 高 | 单元测试：覆盖所有游戏阶段转换、犯规判定、游戏结束判定场景 |
| 选球验证边界情况（球名格式异常） | 中 | 单元测试：测试各种球名格式（`ball_N`、`_N`、无效格式），验证解析和验证逻辑 |
| 异步延迟冲突（游戏结束和自由球模式） | 中 | 集成测试：模拟快速连续犯规和游戏结束，验证延迟逻辑和冲突检查 |
| 游戏状态不一致（gameManager 和 sceneViewModel 不同步） | 高 | 集成测试：验证击球完成后游戏状态同步，检查状态一致性 |
| 场景事件回调时序问题（回调延迟或乱序） | 中 | 集成测试：模拟快速连续击球，验证事件处理顺序，检查状态一致性 |

## 变更验证记录

| 日期 | 变更摘要 | 验证结果 | 未覆盖项 |
|------|----------|----------|----------|
| 2026-02-27 | 创建模块文档 | 文档创建完成，待代码验证 | 无 |
