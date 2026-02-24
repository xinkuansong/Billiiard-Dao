# 实施计划：物理引擎 (Physics Engine)

**分支**: `1-physics-engine` | **日期**: 2025-02-20 | **规格**: [spec.md](./spec.md)  
**说明**: 本文档为追溯性计划，记录已实现物理引擎的技术上下文与架构决策

## 摘要

球道 App 物理引擎采用事件驱动 (EventDrivenEngine) + 解析运动方程 (AnalyticalMotion) 的架构，与 SceneKit 视觉层分离。引擎负责计算完整轨迹，SceneKit 仅负责渲染回放，实现无累积误差、无穿透的专业台球物理模拟。

## 技术上下文

**语言/版本**: Swift 5.x  
**主要依赖**: SceneKit（仅用于渲染与几何类型 SCNVector3/SCNVector4），无第三方物理引擎  
**测试**: XCTest（可扩展）  
**目标平台**: iOS 17+  
**项目类型**: 原生 iOS 应用  
**性能目标**: 单次击球模拟 < 100ms，轨迹记录支持 60fps 回放  
**约束**: 无联网依赖，纯本地计算；物理计算与渲染解耦  
**规模**: Core/Physics/ 目录约 10 个 Swift 文件

## 核心架构决策

### 1. 视觉-物理分离

- **决策**: EventDrivenEngine 计算完整轨迹，SceneKit 仅用于 3D 渲染
- **理由**: 
  - 避免 SceneKit 物理引擎的穿透与误差积累
  - 便于调试、重放、轨迹预测（AimingSystem.predictTrajectory）
  - 物理逻辑与平台无关，便于迁移或复用
- **实现**: EventDrivenEngine 持有 BallState，CollisionResolver 提供纯计算接口 (resolveBallBallPure / resolveCushionCollisionPure)，PhysicsEngine 作为 SceneKit 侧包装（可选使用 SCNPhysicsBody 或仅回放）

### 2. 事件驱动 vs 时间步进

- **决策**: 采用事件驱动，按「下一个事件」推进模拟
- **理由**:
  - 精确处理碰撞时刻，无离散时间步穿透
  - 状态转移（sliding→rolling→spinning→stationary）作为显式事件，便于缓存与优先级
- **实现**: findNextEvent 枚举 ball-ball、ball-cushion、ball-pocket、transition 四类事件，取最早发生者推进 currentTime

### 3. 解析运动方程 vs 帧累积

- **决策**: 使用 AnalyticalMotion 的解析式演化
- **理由**:
  - 滑动/滚动/旋转在恒定摩擦下均有闭式解
  - 无欧拉/龙格库塔累积误差
  - 可直接计算 transition 时间（slideToRollTime、rollToSpinTime、spinToStationaryTime）
- **实现**: evolveSliding / evolveRolling / evolveSpinning，以及对应的 transition time 函数

### 4. 连续碰撞检测 (CCD)

- **决策**: 球-球、球-袋口用四阶方程，球-库边用二次方程
- **理由**:
  - 球心轨迹为二次多项式，距离平方为时间 t 的四次多项式
  - 球-库边可化为二次方程（沿法向距离）
- **实现**: CollisionDetector.ballBallCollisionTime（QuarticSolver）、ballLinearCushionTime（solveQuadratic）、球-袋口（QuarticSolver 求 |p(t) - pocket|² = r²）

### 5. 碰撞模型选型

- **球-球**: Alciatore 摩擦非弹性模型，支持滑动/无滑动及滑移反转校正
- **球-库边**: Mathavan 2010 冲量积分模型，压缩-恢复两阶段，考虑台呢与库边摩擦

### 6. 无第三方物理库

- **决策**: 不引入 Bullet、PhysX 等
- **理由**: 台球为特定域，解析解与文献模型更贴合，且可控性高

## 项目结构

### 文档（本功能）

```text
specs/1-physics-engine/
├── spec.md      # 本功能规格（追溯）
├── plan.md      # 本实施计划（追溯）
└── tasks.md     # 任务列表（追溯）
```

### 源代码

```text
current_work/BilliardTrainer/
├── Core/Physics/
│   ├── EventDrivenEngine.swift   # 事件驱动引擎核心
│   ├── AnalyticalMotion.swift   # 解析运动方程（滑动/滚动/旋转）
│   ├── CollisionDetector.swift   # CCD（球-球、球-库边、球-袋口）
│   ├── CollisionResolver.swift   # 碰撞解析（Alciatore / Mathavan）
│   ├── CueBallStrike.swift       # 击球模型与 Squirt
│   ├── TrajectoryRecorder.swift # 轨迹记录与回放
│   ├── BallMotionState.swift    # 运动状态枚举
│   ├── QuarticSolver.swift      # 四阶方程求解（Ferrari 法）
│   ├── CushionCollisionModel.swift  # Mathavan 库边模型
│   └── PhysicsEngine.swift      # 引擎包装（SceneKit 集成 / 轨迹预测）
└── Utilities/Constants/
    └── PhysicsConstants.swift    # BallPhysics, TablePhysics, SpinPhysics, CuePhysics
```

### 结构说明

- **EventDrivenEngine**: 主循环，findNextEvent → evolveAllBalls → resolveEvent → recordSnapshot
- **AnalyticalMotion**: 纯函数，无状态
- **CollisionDetector / CollisionResolver**: 纯计算，无 SCNNode 依赖（Resolver 另有 SCNNode 包装）
- **CushionCollisionModel**: Mathavan 压缩-恢复两阶段冲量积分
- **QuarticSolver**: 退化处理（四次→三次→二次→一次），Ferrari 法求实根
