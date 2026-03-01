# Physics 模块

> 代码路径：`BilliardTrainer/Core/Physics/`
> 文档最后更新：2026-02-27

## 模块定位

Physics 模块是 BilliardTrainer 的核心物理引擎，提供事件驱动的连续碰撞检测（CCD）和精确的台球物理模拟。它实现了基于解析运动方程的高精度物理计算，支持滑动、滚动、旋转、静止等多种运动状态，以及球-球碰撞、球-库边碰撞、进袋检测等关键事件。该模块不处理游戏规则判定、UI 交互或数据持久化，专注于物理计算的准确性和数值稳定性。

## 入口文件

| 文件 | 职责 | 行数 |
|------|------|------|
| `PhysicsEngine.swift` | 基于定时器的物理引擎包装器，60Hz 更新，应用解析摩擦模型，管理球状态转换，提供轨迹预测 | ~512 |
| `EventDrivenEngine.swift` | 事件驱动物理引擎（CCD），查找精确碰撞时间，按优先级处理事件，解析演化球状态 | ~1145 |
| `AnalyticalMotion.swift` | 滑动/滚动/旋转的解析运动方程，位置/速度/角速度演化的闭式解，状态转换时间计算 | ~300 |
| `CollisionDetector.swift` | 球-球和球-库边的 CCD，求解四次/二次方程获取精确碰撞时间 | ~400 |
| `CollisionResolver.swift` | 球-球碰撞解析（Alciatore 摩擦非弹性模型）和球-库边碰撞解析（Mathavan 2010） | ~200 |
| `CushionCollisionModel.swift` | Mathavan 2010 库边碰撞模型，压缩/恢复阶段的冲量积分 | ~300 |
| `QuarticSolver.swift` | Ferrari 方法四次方程求解器，带 Newton-Raphson 抛光 | ~200 |
| `BallMotionState.swift` | 球运动状态枚举：静止、旋转、滑动、滚动、进袋 | ~17 |
| `CueBallStrike.swift` | 母球击打模型（pooltool instantaneous_point），根据球杆参数计算初始速度/角速度 | ~200 |
| `TrajectoryPlayback.swift` | 使用事件快照和解析运动的回放系统，任意时间 t 的精确球状态 | ~150 |
| `TrajectoryRecorder.swift` | 模拟过程中记录轨迹帧，用于回放 | ~100 |

## 核心概念与术语

| 术语 | 含义 |
|------|------|
| **CCD (Continuous Collision Detection)** | 连续碰撞检测，通过解析方程求解精确碰撞时间，避免离散时间步长导致的穿透问题 |
| **事件驱动模拟** | 按事件发生时间顺序处理物理事件（碰撞、状态转换、进袋），而非固定时间步长更新 |
| **解析运动** | 基于物理方程的闭式解计算球的位置、速度、角速度，避免数值积分误差 |
| **状态转换** | 球在滑动、滚动、旋转、静止之间的转换，由速度与角速度关系决定 |
| **事件优先级** | 同时刻事件的处理顺序：-1（重叠分离）< 0（碰撞）< 1（滑动→滚动）< 2（滚动→旋转/进袋）< 3（旋转→静止） |
| **零时刻事件保护** | 连续零时刻事件超过阈值（80 次）时触发时间微调（0.0005s），避免主线程卡死 |
| **轨迹快照** | 事件发生时刻的完整球状态记录，用于精确回放和规则判定 |

## 端到端流程

```
击球输入（CueBallStrike）
  ↓
计算初始速度/角速度
  ↓
EventDrivenEngine.simulate()
  ↓
循环：查找下一事件 → 演化到事件时间 → 解析事件 → 记录快照
  ├─ 球-球碰撞（CollisionDetector → CollisionResolver）
  ├─ 球-库边碰撞（CollisionDetector → CushionCollisionModel）
  ├─ 状态转换（AnalyticalMotion 计算转换时间）
  └─ 进袋检测（TableGeometry 距离判断）
  ↓
所有球静止或达到最大事件数/时间
  ↓
TrajectoryRecorder 输出轨迹数据
  ↓
TrajectoryPlayback 提供任意时刻状态查询
```

## 对外能力（Public API）

### PhysicsEngine（定时器引擎）
- `init(scene: BilliardScene)`：初始化物理引擎
- `startSimulation()`：开始 60Hz 定时器更新
- `stopSimulation()`：停止模拟
- `latestTrajectoryRecorder() -> TrajectoryRecorder?`：获取最近轨迹记录
- `handleBallCollision(ballA:ballB:contactPoint:)`：处理球-球碰撞
- `handleCushionCollision(ball:cushion:contactPoint:normal:)`：处理球-库边碰撞
- `predictTrajectory(from:direction:velocity:spin:steps:) -> [SCNVector3]`：预测轨迹

### EventDrivenEngine（事件驱动引擎）
- `init(tableGeometry: TableGeometry)`：初始化事件驱动引擎
- `setBall(_ ball: BallState)`：添加或更新球状态
- `getBall(_ name: String) -> BallState?`：获取球状态
- `getAllBalls() -> [BallState]`：获取所有球状态
- `simulate(maxEvents:maxTime:)`：运行模拟直到最大事件数或最大时间
- `getTrajectoryRecorder() -> TrajectoryRecorder`：获取轨迹记录器
- `resolvedEvents: [PhysicsEventType]`：已解析事件历史（用于规则判定）
- `firstBallBallCollisionTime: Float?`：首次球-球碰撞时间（用于相机延迟切换）

### CueBallStrike（击球模型）
- `static func strike(velocity:direction:cuePoint:tableGeometry:) -> (velocity:angularVelocity:)`：计算击球后的初始速度/角速度

### TrajectoryPlayback（轨迹回放）
- `init(recorder: TrajectoryRecorder)`：从记录器初始化
- `getBallState(at time: Float, ballName: String) -> BallState?`：获取指定时刻的球状态
- `getAllBallStates(at time: Float) -> [BallState]`：获取指定时刻所有球状态

### CollisionResolver（碰撞解析）
- `static func resolveBallBall(ballA:ballB:)`：解析球-球碰撞
- `static func resolveCushionCollision(ball:normal:)`：解析球-库边碰撞

## 依赖与边界

- **依赖**：
  - `PhysicsConstants`（`BilliardTrainer/Utilities/Constants/PhysicsConstants.swift`）：物理常量（球半径、质量、摩擦系数、台面尺寸等）
  - `TableGeometry`（`BilliardTrainer/Core/Scene/TableGeometry.swift`）：台面几何信息（库边、袋口位置）
  - `SceneKit`：3D 场景和物理体表示
  - `Foundation`：基础数据类型和工具
- **被依赖**：
  - `BilliardSceneViewModel`（`BilliardTrainer/Core/Scene/BilliardSceneView.swift`）：使用 EventDrivenEngine 执行击球模拟
  - `BilliardScene`（`BilliardTrainer/Core/Scene/BilliardScene.swift`）：使用 PhysicsEngine 进行实时物理更新
- **禁止依赖**：
  - `Features` 层模块（训练、规则判定等业务逻辑）
  - UI 层组件（视图、手势处理）
  - 数据持久化层（SwiftData、UserDefaults）

## 与其他模块的耦合点

- **Scene 模块**：
  - `BilliardSceneViewModel` 调用 `EventDrivenEngine.simulate()` 执行击球，读取 `resolvedEvents` 进行规则判定
  - `BilliardScene` 使用 `PhysicsEngine` 进行实时物理更新，需要同步球节点的位置和状态
  - `TableGeometry` 提供库边和袋口几何信息，影响碰撞检测和进袋判断
- **PhysicsConstants**：
  - 所有物理常量集中定义，Physics 模块改动常量时需评估对 Scene 模块的影响（如球半径影响碰撞检测、摩擦系数影响运动衰减）

## 关键数据结构

| 结构/枚举 | 字段/Case | 单位/生命周期 |
|-----------|-----------|---------------|
| `BallMotionState` | `.stationary`, `.spinning`, `.sliding`, `.rolling`, `.pocketed` | 枚举，球生命周期内状态转换 |
| `PhysicsEventType` | `.ballBall(ballA:ballB:)`, `.ballCushion(ball:cushionIndex:normal:)`, `.transition(ball:fromState:toState:)`, `.pocket(ball:pocketId:)` | 事件类型，模拟过程中创建 |
| `PhysicsEvent` | `type: PhysicsEventType`, `time: Float`, `priority: Int` | 时间单位：秒（s），优先级：整数，事件队列中排序 |
| `BallState` | `position: SCNVector3`, `velocity: SCNVector3`, `angularVelocity: SCNVector3`, `state: BallMotionState`, `name: String` | 位置：米（m），速度：m/s，角速度：rad/s，球生命周期内持续更新 |
| `EventCache` | 缓存已计算的事件，避免重复计算 | 模拟过程中维护，事件解析后失效 |

## 内部结构

### 引擎核心（Engine Core）
- **PhysicsEngine.swift**：定时器驱动的物理引擎，60Hz 更新循环，应用解析摩擦模型，管理球状态转换
- **EventDrivenEngine.swift**：事件驱动引擎，CCD 核心，事件队列管理，状态演化控制
- **BallMotionState.swift**：球运动状态枚举定义

### 碰撞与求解（Collision & Solving）
- **CollisionDetector.swift**：CCD 碰撞检测，求解四次/二次方程获取精确碰撞时间
- **CollisionResolver.swift**：碰撞解析，球-球和球-库边的冲量计算
- **CushionCollisionModel.swift**：Mathavan 2010 库边碰撞模型，压缩/恢复阶段积分
- **QuarticSolver.swift**：Ferrari 方法四次方程求解器，Newton-Raphson 抛光
- **AnalyticalMotion.swift**：解析运动方程，状态转换时间计算

### 击球与轨迹（Strike & Trajectory）
- **CueBallStrike.swift**：母球击打模型，初始速度/角速度计算
- **TrajectoryPlayback.swift**：轨迹回放系统，基于事件快照的精确状态查询
- **TrajectoryRecorder.swift**：轨迹记录器，事件时刻快照存储

## 最近变更记录

| 日期 | 变更摘要 | 影响面 |
|------|----------|--------|
| 2026-02-27 | 创建模块文档 | 无代码变更 |
