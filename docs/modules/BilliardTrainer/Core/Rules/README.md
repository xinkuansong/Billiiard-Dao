# Rules（规则系统）

> 代码路径：`BilliardTrainer/Core/Rules/`
> 文档最后更新：2026-02-27

## 模块定位

台球规则判定系统，提供中式八球规则的状态机管理和犯规检测。不处理物理模拟（由 Physics 模块负责），不处理 UI 显示（由 ViewModel 层负责）。

## 入口文件

| 文件 | 职责 | 行数 |
|------|------|------|
| `GameRules.swift` | 游戏规则：犯规枚举、游戏事件枚举、八球规则判定（isLegalShot） | 100 |
| `EightBallGameManager.swift` | 八球游戏管理器：完整游戏状态机（waitingBreak/openTable/playing/eightBallStage/gameOver）、击球处理、状态更新 | 429 |

## 核心概念与术语

| 术语 | 含义 |
|------|------|
| BallGroup | 球组：solids（全色球 1-7）、stripes（花色球 9-15）、open（未定） |
| Foul | 犯规：cueBallPocketed（白球落袋）、wrongFirstHit（首碰错误）、noCushionAfterContact（无库边）、noBallHit（空杆） |
| GameEvent | 游戏事件：ballBallCollision（球球碰撞）、ballCushionCollision（球库碰撞）、ballPocketed（球进袋）、cueBallPocketed（白球落袋） |
| GamePhase | 游戏阶段：waitingBreak（等待开球）、openTable（花色未定）、playing（进行中）、eightBallStage（打8号球）、gameOver（游戏结束） |
| ShotResult | 击球结果：legal（是否合法）、fouls（犯规列表）、pocketedBalls（进袋球列表）、cueBallPocketed（白球是否落袋）、eightBallPocketed（8号球是否落袋）、firstHitBall（首碰球）、cushionHitAfterContact（是否碰库） |
| Ball-in-Hand | 自由球：犯规后可以自由放置白球（开球犯规时限制在开球线后） |

## 端到端流程

```
输入事件（GameEvent 数组） → analyzeShotEvents() → 提取进袋球、首碰球、库边碰撞等信息 → 根据当前阶段判定犯规 → processShot() → 阶段特定处理（processBreakShot/processOpenTableShot/processPlayingShot/processEightBallShot） → 更新游戏状态（phase、remainingSolids/Stripes、isBallInHand） → 返回是否继续击球
```

### 状态转换流程

```
waitingBreak --[开球合法]--> openTable（或直接 playing，如果开球进袋确定花色）
openTable --[确定花色]--> playing(group)
playing(group) --[清台]--> eightBallStage
eightBallStage --[打进8号球]--> gameOver(won)
任意阶段 --[犯规/游戏结束条件]--> gameOver(won) 或 openTable（开球犯规）
```

## 对外能力（Public API）

- `EightBallRules.isLegalShot()`：判定击球是否合法，返回（legal: Bool, fouls: [Foul]）
- `EightBallGameManager.processShot()`：处理击球事件，更新游戏状态，返回是否继续击球
- `EightBallGameManager.reset()`：重置游戏状态
- `EightBallGameManager.phase`：当前游戏阶段（只读）
- `EightBallGameManager.playerGroup`：当前玩家球组（只读）
- `EightBallGameManager.isBallInHand`：是否处于自由球状态（只读）
- `EightBallGameManager.statusMessage`：状态消息（用于 UI 显示）
- `EightBallGameManager.remainingPlayerBalls`：剩余玩家球数（只读）
- `EightBallGameManager.isGameOver` / `didWin`：游戏结束状态（只读）

## 依赖与边界

- **依赖**：
  - `Foundation`（基础类型）
- **被依赖**：
  - `FreePlayViewModel`（自由游戏视图模型，调用规则判定）
- **禁止依赖**：
  - 不依赖 `Physics` 模块（仅消费事件，不直接访问物理状态）
  - 不依赖 `Features` 层业务逻辑（保持 Core 层独立性）

## 与其他模块的耦合点

- **Physics 模块**：消费 `GameEvent` 事件（由 Physics 模块产生），耦合点在于事件格式和时序
- **FreePlay 模块**：`FreePlayViewModel` 调用 `processShot()` 并读取游戏状态，耦合点在于 API 接口稳定性
- **球命名兼容性**：支持 `ball_N` 和 `_N` 两种球名格式，耦合点在于球名解析逻辑

## 关键数据结构

| 结构/枚举 | 字段/Case | 单位/生命周期 |
|-----------|-----------|---------------|
| `BallGroup` | solids, stripes, open | 游戏阶段 |
| `Foul` | cueBallPocketed, wrongFirstHit, noCushionAfterContact, noBallHit | 犯规类型 |
| `GameEvent` | ballBallCollision(ball1, ball2, time), ballCushionCollision(ball, time), ballPocketed(ball, pocket, time), cueBallPocketed(time) | 事件时间序列 |
| `GamePhase` | waitingBreak, openTable, playing(group), eightBallStage, gameOver(won) | 游戏阶段 |
| `ShotResult` | legal, fouls, pocketedBalls, cueBallPocketed, eightBallPocketed, firstHitBall, cushionHitAfterContact | 击球分析结果 |

## 最近变更记录

| 日期 | 变更摘要 | 影响面 |
|------|----------|--------|
| 2026-02-27 | 初始文档创建 | 无（新建文档） |
