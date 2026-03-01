# FreePlay 模块 - 设计与约束

> 对应 README：[README.md](./README.md)
> 文档最后更新：2026-02-27

## 设计目标与非目标

- **目标**：
  - 实现完整的中式八球游戏规则，包括开球、选球、击球、犯规、自由球、游戏结束等流程
  - 通过 `EightBallGameManager` 集中管理游戏规则逻辑，ViewModel 仅负责状态同步和UI更新
  - 与 Scene 模块解耦，通过 ViewModel 和回调接口交互，不直接操作场景节点
  - 提供清晰的游戏状态反馈（球组、剩余球数、犯规提示、游戏结束）
- **非目标**：
  - 不处理训练场景配置和星级评价（由 Training 模块处理）
  - 不实现物理计算（由 Physics 模块处理）
  - 不管理用户数据和持久化（由 AppState 或其他数据层处理）
  - 不支持多人对战（单机单人模式）

## 不变量与约束（改动护栏）

### 单位与坐标系

- 游戏规则判定使用物理事件时间戳和球名，不涉及坐标计算（由 Physics 和 Scene 模块处理）
- 时间单位：秒（s），犯规提示显示时长2秒，游戏结束浮层延迟1.5秒显示

### 数值稳定性保护

- **球名解析保护**：`extractBallNumber()` 支持 `ball_N` 和 `_N` 两种格式，解析失败返回 `nil`，验证逻辑中处理 `nil` 情况（返回 `(true, nil)` 允许选择）
- **游戏状态一致性**：`onShotFinished()` 中先调用 `gameManager.processShot()` 更新游戏状态，再检查 `isGameOver`，确保状态同步
- **异步延迟保护**：使用 `DispatchQueue.main.asyncAfter` 延迟显示游戏结束浮层和进入自由球模式，使用 `[weak self]` 避免循环引用，延迟前检查 `isGameOver` 防止重复触发

### 时序与状态约束

- **游戏初始化时序**：`startNewGame()` 中必须先重置 `gameManager`，再重置场景和设置布局，最后进入放置模式，确保状态一致
- **击球处理时序**：`onShotFinished()` → `gameManager.processShot()` → 检查 `isGameOver` → 检查 `isBallInHand` → 延迟进入下一阶段，不可跳过 `processShot()` 直接检查状态
- **选球验证时序**：`ballSelectionValidator` 在用户点击球时触发，必须在 `gameManager.processShot()` 之前验证，确保选球合法性
- **自由球模式时序**：犯规后 `isBallInHand = true`，延迟1.5秒后调用 `enterPlacingMode()`，不可立即进入放置模式（需等待犯规提示显示）

### 常量与阈值清单

| 常量/阈值 | 值 | 来源/理由 | 改动影响 |
|-----------|-----|----------|----------|
| 犯规提示显示时长 | 2.0秒 | UI体验，足够用户阅读犯规消息 | 影响用户对犯规的感知，缩短可能错过提示 |
| 游戏结束浮层延迟 | 1.5秒 | UI体验，等待球完全静止后再显示结果 | 影响用户体验，缩短可能过早显示 |
| 自由球模式延迟 | 1.5秒 | UI体验，等待犯规提示显示后再进入放置模式 | 影响用户体验，缩短可能冲突 |
| 正常击球后延迟 | 1.0秒 | UI体验，等待球静止后再准备下一击 | 影响游戏节奏，缩短可能过快 |
| 球名格式 | `ball_N`, `_N` | 与 Scene 模块球节点命名一致 | 影响选球验证，必须与场景球名格式匹配 |

## 状态机 / 事件模型

### 游戏阶段状态机（由 EightBallGameManager 管理）

```
waitingBreak (等待开球)
  ↓ 开球
openTable (开球后花色未定)
  ↓ 首次进球确定球组
playing(.solids) 或 playing(.stripes) (进行中)
  ├─ 己方球组清台 → eightBallStage (打8号球阶段)
  └─ 8号球进袋 → gameOver (游戏结束)
```

### FreePlayViewModel 状态机

```
未开始 (初始状态)
  ↓ startNewGame()
进行中 (isPaused = false, showGameOverOverlay = false)
  ├─ pauseGame() → 暂停中 (isPaused = true)
  │   └─ resumeGame() → 进行中
  ├─ 击球完成 → onShotFinished() → 更新游戏阶段
  │   ├─ 犯规 → foulFlash = true → 延迟进入自由球模式
  │   └─ 游戏结束 → 延迟显示游戏结束浮层
  └─ 游戏结束 (showGameOverOverlay = true)
```

## 错误处理与降级策略

- **游戏管理器初始化失败**：`EightBallGameManager()` 初始化失败时，游戏无法开始，应在UI层显示错误提示
- **场景事件回调缺失**：`FreePlayViewModel` 依赖 `sceneViewModel` 的回调，若回调未设置或为nil，击球完成事件无法处理，游戏状态可能不一致，应在初始化时确保回调设置
- **选球验证失败**：`ballSelectionValidator` 返回 `(false, message)` 时，场景层应显示警告消息，阻止击球，用户需重新选择
- **游戏阶段转换异常**：`gameManager.processShot()` 返回异常阶段时，ViewModel 应记录错误日志，降级为 `gameOver` 状态，避免游戏卡死
- **异步延迟冲突**：多个延迟操作可能冲突（如游戏结束和自由球模式），使用 `isGameOver` 检查避免冲突，确保游戏结束后不再进入自由球模式

## 性能考量

- **Combine 订阅**：`FreePlayViewModel` 订阅 `sceneViewModel.$gameState`，使用 `[weak self]` 避免循环引用，在 `deinit` 中自动取消订阅（`cancellables` 集合销毁时）
- **状态更新频率**：`@Published` 属性变更会触发 SwiftUI 视图更新，击球完成事件频率较低（每秒最多1-2次），性能影响可接受
- **游戏管理器状态查询**：`FreePlayViewModel` 的计算属性（如 `phase`、`playerGroupName`）直接访问 `gameManager` 属性，无额外开销
- **选球验证性能**：`validateBallSelection()` 中球名解析和阶段判断均为 O(1) 操作，性能可忽略

## 参考实现对照（如适用）

| Swift 文件/函数 | 参考来源 | 偏离说明 |
|----------------|--------------|----------|
| `EightBallGameManager` | 游戏规则业务逻辑，无参考实现 | 中式八球规则实现，根据业务需求设计 |
| `ballSelectionValidator` 球名解析 | Scene 模块球节点命名规范 | 必须与场景球名格式一致（`ball_N`、`_N`） |

## 设计决策记录（ADR）

### ADR-001：FreePlayViewModel 持有 EightBallGameManager 而非通过依赖注入

- **背景**：`FreePlayViewModel` 需要访问游戏规则逻辑，需要持有 `EightBallGameManager`
- **候选方案**：
  1. `FreePlayViewModel` 内部创建 `EightBallGameManager`
  2. 通过依赖注入传入 `EightBallGameManager`
  3. 使用单例或全局访问
- **结论**：选择方案1，游戏管理器是自由练习模块的私有资源，不需要外部共享，简化依赖关系
- **后果**：每个游戏会话创建新的管理器实例，内存占用略高，但游戏会话生命周期短，可接受

### ADR-002：选球验证通过闭包回调而非事件通知

- **背景**：需要在用户点击球时验证选球合法性，阻止非法选球
- **候选方案**：
  1. 通过 `sceneViewModel.ballSelectionValidator` 闭包回调验证
  2. 通过事件通知（NotificationCenter 或 Combine）验证
  3. 在场景层直接访问 `gameManager` 验证
- **结论**：选择方案1，闭包回调简单直接，减少中间层，性能更好
- **后果**：ViewModel 需要设置闭包，但逻辑清晰，维护成本低

### ADR-003：游戏状态通过计算属性暴露而非 @Published

- **背景**：游戏状态（阶段、球组、剩余球数等）来自 `gameManager`，需要暴露给视图
- **候选方案**：
  1. 使用计算属性直接访问 `gameManager` 属性
  2. 使用 `@Published` 属性同步 `gameManager` 状态
  3. 订阅 `gameManager` 的状态变化并更新 `@Published` 属性
- **结论**：选择方案1，计算属性简单直接，无状态同步开销，`gameManager` 状态变更时通过 `objectWillChange.send()` 通知视图更新
- **后果**：视图更新可能略频繁（每次 `gameManager` 状态变更都触发），但游戏状态变更频率低，可接受
