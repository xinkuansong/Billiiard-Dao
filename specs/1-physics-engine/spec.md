# 功能规格：物理引擎 (Physics Engine)

**功能分支**: `1-physics-engine`  
**创建日期**: 2025-02-20  
**状态**: 已完成（追溯文档）  
**说明**: 本文档为追溯性规格，记录已实现的球道 (Billiard Trainer) iOS  App 物理引擎功能

## 概述

球道 App 采用自研事件驱动物理引擎 (EventDrivenEngine)，基于解析运动方程实现台球运动的精确模拟。引擎与 SceneKit 视觉层分离，物理计算独立于渲染，确保无累积误差、无穿透（tunneling），并支持完整塞球效果与连续碰撞检测。

## 用户场景与测试 *(追溯)*

### 用户故事 1 - 击球与运动模拟 (优先级: P1)

用户在瞄准后击球，母球按物理规律运动，经历滑动→滚动→旋转→静止等状态，过程中与目标球、库边发生碰撞，最终可能进袋。

**独立测试**: 击球后观察母球及目标球轨迹是否符合真实台球物理，无明显穿透或异常反弹。

**验收场景**:
1. **Given** 母球与目标球静止，**When** 用户击打母球，**Then** 母球按初速度与打点产生相应线速度、角速度
2. **Given** 母球以一定速度运动，**When** 与库边碰撞，**Then** 根据 Mathavan 模型正确反弹
3. **Given** 两球接近，**When** 发生碰撞，**Then** 采用 Alciatore 模型正确交换速度与角速度

---

### 用户故事 2 - 塞球与 Squirt 效果 (优先级: P2)

用户通过打点控制母球旋转：高杆 (follow)、低杆 (draw)、左塞/右塞 (english)、斯登 (stun)、以及组合塞。

**独立测试**: 侧旋击球时母球偏离瞄准方向（Squirt 效应），可通过 `CueBallStrike.squirtAngle` 和 `actualDirection` 校验。

**验收场景**:
1. **Given** 瞄准方向与击球力度，**When** 施加侧旋 (spinX ≠ 0)，**Then** 母球实际运动方向因 Squirt 发生偏移
2. **Given** 高杆/低杆打点，**When** 击球，**Then** 母球获得相应 topspin/backspin 角速度

---

### 用户故事 3 - 轨迹记录与回放 (优先级: P3)

物理引擎在模拟过程中记录每个球在各时刻的位置、速度、角速度及运动状态，用于 SceneKit 视觉回放。

**独立测试**: 模拟结束后，TrajectoryRecorder 中保存的 BallFrame 序列可与 EventDrivenEngine 输出一致，且 SceneKitBridge 可正确生成 SCNAction 回放。

**验收场景**:
1. **Given** 一次完整击球模拟，**When** 查询 TrajectoryRecorder，**Then** 可获取每球的完整轨迹
2. **Given** 球进袋，**When** 回放，**Then** 球移动至袋口位置后淡出并移除

---

### 边界情况

- 球速极小、角速度极小：视为静止 (stationary)
- 袋口几何：使用 QuarticSolver 求解球心与袋口圆的 CCD 碰撞时间
- 多球同时碰撞：通过事件优先级 (ball-ball = 0, transition = 1–3) 排序处理

## 需求 *(追溯)*

### 功能需求

- **FR-001**: 系统必须实现事件驱动物理引擎 (EventDrivenEngine)，按事件顺序推进模拟
- **FR-002**: 系统必须使用解析运动方程 (AnalyticalMotion) 演化滑动、滚动、旋转状态，避免时间步累积误差
- **FR-003**: 系统必须实现连续碰撞检测 (CollisionDetector)，覆盖球-球、球-库边、球-袋口
- **FR-004**: 球-球碰撞必须采用 Alciatore 摩擦非弹性模型 (resolveBallBallPure)
- **FR-005**: 球-库边碰撞必须采用 Mathavan 2010 冲量积分模型 (CushionCollisionModel)
- **FR-006**: 击球模型 (CueBallStrike) 必须支持 Squirt 效应及打点与初状态的转换
- **FR-007**: 系统必须记录轨迹 (TrajectoryRecorder) 并支持 SCNAction 回放 (SceneKitBridge)
- **FR-008**: 球-球、球-袋口 CCD 必须使用 QuarticSolver (Ferrari 法) 求解碰撞时间
- **FR-009**: 物理引擎必须与 SceneKit 视觉层分离，不依赖 SCNPhysicsBody 做物理计算

### 关键实体

- **BallState**: 球的位置、速度、角速度、运动状态 (BallMotionState)
- **BallMotionState**: stationary | sliding | rolling | spinning | pocketed
- **PhysicsEvent**: 事件类型 (ballBall / ballCushion / transition / pocket)、发生时间、优先级
- **BallFrame**: 轨迹记录单帧（时间、位置、速度、角速度、状态）
- **TableGeometry**: 台面几何（线性库边、袋口参数）

## 成功标准 *(追溯)*

### 可衡量结果

- **SC-001**: 模拟过程无穿透：球与球、球与库边、球与袋口均通过 CCD 精确求解碰撞时刻
- **SC-002**: 运动演化无显式时间步误差：使用解析式 sliding/rolling/spinning 演化
- **SC-003**: 碰撞模型符合文献：Alciatore (球-球)、Mathavan 2010 (球-库边)
- **SC-004**: Squirt 效应可量化：CueBallStrike.squirtAngle 与 actualDirection 可正确修正击球方向
- **SC-005**: 轨迹回放流畅：TrajectoryRecorder 与 SceneKitBridge 可生成合理 SCNAction 序列

## 物理常数 *(已实现)*

| 参数 | 值 | 说明 |
|------|-----|------|
| 球直径 | 57.15 mm | BallPhysics.diameter |
| 球质量 | 170 g | BallPhysics.mass |
| 球-球弹性 | 0.95 | BallPhysics.restitution |
| 台呢摩擦 | 0.2 | TablePhysics.clothFriction / SpinPhysics.slidingFriction |
| 库边弹性 | 0.85 | TablePhysics.cushionRestitution |
| 库边摩擦 | 0.2 | TablePhysics.cushionFriction |
| 滚动摩擦 | 0.01 | SpinPhysics.rollingFriction |
