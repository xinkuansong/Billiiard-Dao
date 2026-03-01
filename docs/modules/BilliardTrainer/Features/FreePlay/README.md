# FreePlay 模块

> 代码路径：`BilliardTrainer/Features/FreePlay/`
> 文档最后更新：2026-02-27

## 模块定位

FreePlay 模块提供完整的中式八球自由练习模式，集成游戏规则管理（`EightBallGameManager`）和3D场景渲染，支持开球、选球、击球、犯规判定、自由球、游戏结束等完整游戏流程。该模块不处理训练场景配置和星级评价（由 Training 模块处理），专注于完整游戏规则的实现和游戏状态管理。

## 入口文件

| 文件 | 职责 | 行数 |
|------|------|------|
| `Views/FreePlayView.swift` | 自由练习模式全屏视图，集成 SceneKit 场景与 HUD（球组显示、剩余球数、犯规提示、暂停菜单、游戏结束浮层），强制横屏，根据游戏状态显示/隐藏控件 | ~490 |
| `ViewModels/FreePlayViewModel.swift` | 自由练习视图模型，连接 `BilliardSceneViewModel` 与 `EightBallGameManager`，管理击球数、进球数、暂停状态、犯规提示，处理击球完成事件并更新游戏阶段 | ~290 |

## 核心概念与术语

| 术语 | 含义 |
|------|------|
| **游戏阶段（Game Phase）** | `waitingBreak`（等待开球）、`openTable`（开球后花色未定）、`playing(group)`（进行中，指定球组）、`eightBallStage`（打8号球阶段）、`gameOver`（游戏结束） |
| **球组（Ball Group）** | `solids`（全色球，1-7号）、`stripes`（花色球，9-15号），开球后首次进球确定球组 |
| **自由球（Ball in Hand）** | 犯规后的惩罚，玩家可以将母球放置在台面任意位置（某些情况下限制在开球线后） |
| **选球验证（Ball Selection Validation）** | 根据当前游戏阶段和球组，验证玩家选择的球是否符合规则（如不能选择对方球组、不能提前打8号球） |
| **犯规提示（Foul Flash）** | 犯规后显示的视觉提示横幅，显示犯规原因，2秒后自动消失 |
| **游戏结束判定** | 通过 `EightBallGameManager.isGameOver` 和 `didWin` 判断游戏是否结束及胜负结果 |

## 端到端流程

```
用户进入自由练习（FreePlayView）
  ↓
FreePlayViewModel 初始化：创建 BilliardSceneViewModel 和 EightBallGameManager
  ↓
startNewGame()：重置场景、设置开球布局、进入放置模式
  ↓
用户放置母球（开球线后）→ 切换到瞄准态
  ↓
用户瞄准 → 选择打点 → 调整力度 → 开球
  ↓
BilliardSceneViewModel 执行物理模拟
  ↓
场景事件回调 → FreePlayViewModel.onShotFinished()
  ↓
gameManager.processShot(events:) 处理击球事件
  ├─ 开球阶段：判定首次进球球组，切换到 playing 阶段
  ├─ 进行中：判定进球、犯规、自由球
  └─ 8号球阶段：判定8号球进袋、胜负
  ↓
更新游戏阶段和状态 → 检查游戏结束
  ↓
若犯规：显示犯规提示 → 进入自由球模式（放置母球）
  ↓
若正常：准备下一击
  ↓
游戏结束：显示游戏结束浮层（胜利/失败）
```

## 对外能力（Public API）

### FreePlayViewModel

- `init()`：初始化自由练习视图模型，创建场景视图模型和游戏管理器，设置事件绑定
- `startNewGame()`：开始新游戏，重置所有状态，设置场景布局，进入放置模式
- `resetGame()`：重置游戏（等同于 `startNewGame()`）
- `pauseGame()`：暂停游戏
- `resumeGame()`：恢复游戏
- `replayLastShot()`：回放上一击（调用 `sceneViewModel.playLastShotReplay()`）
- `var phase: GamePhase`：当前游戏阶段（只读，来自 `gameManager.phase`）
- `var playerGroupName: String`：当前玩家球组名称（只读）
- `var remainingSolids: Int`：剩余全色球数（只读）
- `var remainingStripes: Int`：剩余花色球数（只读）
- `var statusMessage: String`：状态消息（只读，来自 `gameManager.statusMessage`）
- `var isBallInHand: Bool`：是否自由球（只读）
- `var isGameOver: Bool`：游戏是否结束（只读）
- `var didWin: Bool`：是否胜利（只读）
- `var accuracy: String`：进球率（格式化字符串，如 "68%"）

### FreePlayView

- `init()`：创建自由练习视图，初始化 `FreePlayViewModel`
- 子视图组件：
  - `FreePlayTopHUD`：顶部HUD，显示球组、剩余球数、暂停/视角切换/回放/重置按钮
  - `FoulBanner`：犯规提示横幅，显示犯规消息
  - `FreePlayBottomHint`：底部提示，显示当前阶段和操作提示
  - `FreePlayPauseOverlay`：暂停菜单浮层
  - `GameOverOverlay`：游戏结束浮层，显示胜负结果

## 依赖与边界

- **依赖**：
  - `Core/Scene`：`BilliardSceneViewModel`（场景状态管理、物理模拟、事件回调、球选择验证）
  - `Core/Game`：`EightBallGameManager`（游戏规则管理、阶段判定、犯规判定、游戏结束判定）
  - `SwiftUI`：视图框架
  - `Combine`：响应式状态订阅
  - `SceneKit`：3D场景渲染
- **被依赖**：
  - `Features/Home`：`HomeView` 通过快捷入口导航到自由练习
  - `App/ContentView`：可能通过导航或 Tab 访问自由练习
- **共享组件**：
  - `PowerGaugeView`：与 `Training` 模块共享力度滑块控件
  - `CuePointSelectorView`：与 `Training` 模块共享打点选择器控件
- **禁止依赖**：不应依赖 `Features` 层其他业务模块（如 `Training`、`Course`）

## 与其他模块的耦合点

- **Scene 模块**：
  - `FreePlayViewModel` 持有 `BilliardSceneViewModel`，通过 `setupRackLayout()` 设置开球布局，通过 `enterPlacingMode()` 进入放置模式，订阅 `$gameState` 和事件回调（`onTargetBallPocketed`、`onShotCompleted`）
  - `FreePlayView` 嵌入 `BilliardSceneView`，通过 `sceneViewModel` 访问场景状态
  - 球选择验证通过 `sceneViewModel.ballSelectionValidator` 闭包实现，根据游戏阶段和球组验证选球合法性
- **Game 模块（EightBallGameManager）**：
  - `FreePlayViewModel` 持有 `EightBallGameManager`，在 `onShotFinished()` 中调用 `gameManager.processShot(events:)` 处理击球事件
  - 游戏阶段、球组、犯规状态、游戏结束状态均来自 `gameManager`，ViewModel 通过计算属性暴露给视图
- **Training 模块**：
  - 共享 `PowerGaugeView` 和 `CuePointSelectorView` 组件，但游戏逻辑独立，不依赖训练配置

## 关键数据结构

| 结构/枚举 | 字段/Case | 单位/生命周期 |
|-----------|-----------|---------------|
| `FreePlayViewModel` | `@Published` 状态：`shotCount`, `pocketedCount`, `isPaused`, `showGameOverOverlay`, `foulFlash` | 游戏会话生命周期内持续更新 |
| `GamePhase` | `.waitingBreak`, `.openTable`, `.playing(group)`, `.eightBallStage`, `.gameOver` | 游戏阶段枚举，由 `EightBallGameManager` 管理 |
| `BallGroup` | `.solids`, `.stripes` | 球组枚举，开球后首次进球确定 |

## 最近变更记录

| 日期 | 变更摘要 | 影响面 |
|------|----------|--------|
| 2026-02-27 | 创建模块文档 | 无代码变更 |
