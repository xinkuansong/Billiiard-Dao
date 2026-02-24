# 物理测试基线清单（冻结版）

本文件用于冻结当前测试基线，作为后续 Cross-Engine 对比、回归门禁和参数调整的参照。

## 覆盖现状

- 已有核心模块测试：
  - `BilliardTrainerTests/Physics/AnalyticalMotionTests.swift`
  - `BilliardTrainerTests/Physics/CollisionDetectorTests.swift`
  - `BilliardTrainerTests/Physics/CollisionResolverTests.swift`
  - `BilliardTrainerTests/Physics/CushionCollisionModelTests.swift`
  - `BilliardTrainerTests/Physics/CueBallStrikeTests.swift`
  - `BilliardTrainerTests/Physics/EventDrivenEngineTests.swift`
  - `BilliardTrainerTests/Physics/PhysicsRegressionTests.swift`
  - `BilliardTrainerTests/Physics/QuarticSolverTests.swift`
- 现有缺口：
  - `TrajectoryPlayback` 缺乏独立测试（已纳入新增任务）。
  - Swift 与 pooltool 之间缺乏自动化一致性比较（已纳入新增任务）。

## 容差统一配置

容差已统一到 `BilliardTrainerTests/TestHelpers.swift` 中的 `PhysicsTestTolerance`：

- `position = 1e-3 m`
- `velocity = 5e-3 m/s`
- `angularVelocity = 5e-2 rad/s`
- `eventTimeCritical = 1e-4 s`
- `eventTimeGeneral = 5e-4 s`

备注：旧测试中的局部容差（如 `0.01`、`0.05`）逐步迁移到统一配置；新测试默认使用统一配置。

## 回归场景基线

当前固定场景以 `PhysicsRegressionTests` 为主，核心场景包括：

- S1 中心直球
- S2 上旋跟进
- S3 拉杆回退
- S4 侧旋偏移
- S5 一库反弹
- S6 多球开球无穿透

新增回归场景（两库/三库、袋口擦边、连续碰撞）将纳入后续增量基线。

## Cross-Engine 基线原则

- 对齐对象：事件类型、事件时刻、球状态（位置/速度/角速度/运动状态）、最终进袋集合。
- 对比阈值遵循统一容差与计划阈值。
- baseline 文件放置目录：
  - `BilliardTrainerTests/Fixtures/CrossEngine/`
- 输出与差异报告产物：
  - `*.swift-output.json`
  - `*.pooltool-output.json`
  - `*.diff.json`

