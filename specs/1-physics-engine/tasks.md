# 任务列表：物理引擎 (Physics Engine)

**输入**: `specs/1-physics-engine/` 下的设计文档  
**说明**: 本文档为追溯性任务列表，所有任务均已标记为已完成 [x]

## 格式：`[ID] [P?] [Story] 描述`

- **[P]**: 可并行执行（不同文件，无依赖）
- **[Story]**: 所属用户故事（如 US1, US2, US3）
- 路径基于 `current_work/BilliardTrainer/`

---

## 阶段 1：基础设施

**目的**: 常量与运动状态定义

- [x] T001 [P] 定义 PhysicsConstants：BallPhysics、TablePhysics、SpinPhysics、CuePhysics（Utilities/Constants/PhysicsConstants.swift）
- [x] T002 [P] 定义 BallMotionState 枚举：stationary / sliding / rolling / spinning / pocketed（Core/Physics/BallMotionState.swift）
- [x] T003 [P] 实现 QuarticSolver（Ferrari 法），支持退化到三次/二次/一次（Core/Physics/QuarticSolver.swift）

---

## 阶段 2：运动与过渡

**目的**: 解析运动方程及状态转移时间

- [x] T004 实现 AnalyticalMotion.evolveSliding（滑动摩擦解析式）
- [x] T005 实现 AnalyticalMotion.evolveRolling（滚动摩擦解析式）
- [x] T006 实现 AnalyticalMotion.evolveSpinning（纯旋转衰减）
- [x] T007 实现 AnalyticalMotion.slideToRollTime、rollToSpinTime、spinToStationaryTime
- [x] T008 实现 AnalyticalMotion.surfaceVelocity、decaySpin 辅助函数

---

## 阶段 3：碰撞检测 (CCD)

**目的**: 连续碰撞检测，无穿透

- [x] T009 实现 CollisionDetector.ballBallCollisionTime（球-球，QuarticSolver）
- [x] T010 实现 CollisionDetector.ballLinearCushionTime（球-线性库边，二次方程）
- [x] T011 实现球-袋口 CCD（EventDrivenEngine 内 QuarticSolver 求袋口圆碰撞时间）

---

## 阶段 4：碰撞解析

**目的**: 球-球与球-库边碰撞响应

- [x] T012 实现 CollisionResolver.resolveBallBallPure（Alciatore 摩擦非弹性模型）
- [x] T013 实现 CollisionResolver.resolveCushionCollisionPure（Mathavan 模型调用 CushionCollisionModel）
- [x] T014 实现 CushionCollisionModel.solve（压缩-恢复两阶段冲量积分）
- [x] T015 实现 CollisionResolver SCNNode 包装（resolveBallBall、resolveCushionCollision）

---

## 阶段 5：击球与 Squirt

**目的**: 击球初状态与 Squirt 效应

- [x] T016 实现 CueBallStrike.strike（速度、角速度初值，参考 pooltool/Alciatore TP_A-30/A-31）
- [x] T017 实现 CueBallStrike.squirtAngle（侧旋导致的方向偏移）
- [x] T018 实现 CueBallStrike.actualDirection（应用 squirt 后的实际方向）
- [x] T019 实现 CueBallStrike.executeStrike（瞄准方向 + 力度 + 打点一站式接口）

---

## 阶段 6：事件驱动引擎

**目的**: EventDrivenEngine 主循环与事件调度

- [x] T020 定义 PhysicsEvent、PhysicsEventType、BallState
- [x] T021 实现 EventCache（球-球、球-库边、transition 缓存）
- [x] T022 实现 EventDrivenEngine.findNextEvent（枚举四类事件，取最早）
- [x] T023 实现 EventDrivenEngine.evolveAllBalls、resolveEvent、invalidateCache
- [x] T024 实现 EventDrivenEngine.resolveBallBallCollision、resolveBallCushionCollision、resolveTransition、resolvePocket
- [x] T025 实现 EventDrivenEngine.acceleration、determineMotionState
- [x] T026 实现 EventDrivenEngine.simulate 主循环

---

## 阶段 7：轨迹与回放

**目的**: 轨迹记录与 SceneKit 回放

- [x] T027 定义 BallFrame 与 TrajectoryRecorder（recordFrame、stateAt、isBallPocketed）
- [x] T028 实现 TrajectoryRecorder.action（生成 SCNAction 序列，含进袋淡出）
- [x] T029 在 EventDrivenEngine 中集成 TrajectoryRecorder（recordSnapshot）
- [x] T030 实现 SceneKitBridge（playTrajectory、playTrajectories）

---

## 阶段 8：引擎包装与预测

**目的**: PhysicsEngine 与轨迹预测

- [x] T031 实现 PhysicsEngine 包装（可选 SceneKit 物理更新、轨迹记录）
- [x] T032 实现 PhysicsEngine.predictTrajectory（使用 AnalyticalMotion + CCD 预测轨迹）
- [x] T033 集成 TableGeometry（线性库边、袋口参数）供 EventDrivenEngine 与 CCD 使用

---

## 依赖与执行顺序

### 阶段依赖

- **阶段 1**: 无依赖，可立即开始
- **阶段 2**: 依赖 T001、T002
- **阶段 3**: 依赖 T001、T003
- **阶段 4**: 依赖 T001、T002、T003
- **阶段 5**: 依赖 T001
- **阶段 6**: 依赖阶段 1–4
- **阶段 7**: 依赖阶段 6
- **阶段 8**: 依赖阶段 2、3、4、7

### 可并行任务

- T001、T002、T003 可并行
- T004–T008 内部部分可并行（不同函数）
- T009、T010、T011 可并行（不同检测器）
