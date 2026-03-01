# Scene 模块 - 设计与约束

> 对应 README：[README.md](./README.md)
> 文档最后更新：2026-02-27

## 设计目标与非目标

- **目标**：提供流畅的 3D 台球场景渲染，支持瞄准、观察、2D 俯视等多种视角，通过视觉/物理分离架构实现 USDZ 模型与物理引擎的独立管理。
- **非目标**：不负责物理计算（由 Physics 模块处理）、不负责相机状态机逻辑（由 Camera 子模块处理）、不负责规则判定（由 Rules 模块处理）。

## 不变量与约束（改动护栏）

### 单位与坐标系

- **坐标系**：SceneKit Y-up 坐标系（USDZ 模型从 Z-up 通过 `TableModelLoader` 变换为 Y-up）
- **长度单位**：米（m），与 Physics 模块一致
- **角度单位**：弧度（rad）
- **球 Y 坐标约束**：`TablePhysics.height + BallPhysics.radius`（球心高度 = 台面高度 + 球半径）
- **白球资源约束**：白球优先从 `TaiQiuZhuo.usdz` 中提取白球节点并注册为 `cueBall`，命名兼容 `_0` 与 `BaiQiu`；提取失败时降级到 `cueball.usdz`；业务层继续通过 `cueBallNode` / `allBallNodes["cueBall"]` 获取白球

### 数值稳定性保护

- **TableModelLoader 缩放验证**：缩放值必须在 `0.0001` 到 `1000` 之间，超出范围会触发断言。删除此保护可能导致模型尺寸异常，物理计算错误。
- **TableModelLoader 表面高度验证**：`surfaceY` 必须在 `-1` 到 `10` 米之间，超出范围会触发断言。删除此保护可能导致球位置异常，物理碰撞失效。
- **相机射线约束**：相机 raycast 必须限制在合理范围内，避免穿透或无限远。删除此保护可能导致相机控制异常。
- **渲染循环 deltaTime 限制**：`deltaTime` 限制在 `1/240` 到 `1/20` 秒之间，防止极端帧率导致动画跳跃。删除此保护可能导致轨迹回放不稳定。

### 时序与状态约束

- **延迟观察视角逻辑**：击球后必须等待首次球-球碰撞时间（`pendingObservationContactTime`）再切换视角，若无碰撞则使用后备延迟（`observationFallbackDelay = 0.8` 秒）。不可在无替代方案时删除此逻辑，否则会导致视角过早切换，用户体验混乱。
- **GameState 转换顺序**：`.idle` → `.placing` → `.aiming` → `.ballsMoving` → `.turnEnd`，不可跳过中间状态或反向转换。
- **轨迹回放时序**：必须在 `CADisplayLink` 的 `renderUpdate()` 中先调用 `updateTrajectoryPlaybackFrame()`，再更新阴影和相机，确保球位置先于视觉反馈更新。

### 常量与阈值清单

| 常量/阈值 | 值 | 来源/理由 | 改动影响 |
|-----------|-----|----------|----------|
| `TablePhysics.height` | 0.71 m | Physics 模块定义 | 球 Y 坐标约束，台面高度 |
| `BallPhysics.radius` | 0.028575 m | Physics 模块定义 | 球 Y 坐标约束，碰撞检测 |
| `CueStickSettings.maxElevation` | 30° | 球杆物理限制 | 球杆仰角上限 |
| `observationFallbackDelay` | 0.8 s | 延迟观察视角后备延迟 | 无碰撞时的视角切换时机 |
| `RenderQualityManager` 帧率阈值 | 低/中/高分级 | 动态质量适配 | 渲染性能与画质平衡 |
| `TableModelLoader` 缩放范围 | 0.0001-1000 | 模型加载验证 | 防止异常缩放导致物理错误 |
| `TableModelLoader` 表面高度范围 | -1 到 10 m | 模型加载验证 | 防止异常高度导致球位置错误 |

## 状态机 / 事件模型

### GameState 状态机

```
idle --[setupTrainingScene]--> placing
placing --[球位置确认]--> aiming
aiming --[executeStroke]--> ballsMoving
ballsMoving --[所有球静止]--> turnEnd
turnEnd --[重置/下一回合]--> idle/aiming
```

### CameraMode 视角模式

- `.aim`：瞄准态（CameraRig 驱动，用户可旋转/缩放）
- `.action`：兼容旧值（统一折叠为 `.aim3D` + `.shotRunning`）
- `.topDown2D`：2D 俯视（固定俯视角度，可缩放/平移）

### 延迟观察视角触发条件

1. 击球时记录 `pendingObservationContactTime = engine.firstBallBallCollisionTime`
2. 轨迹回放中，当 `currentShotTime >= pendingObservationContactTime` 时触发观察视角切换
3. 若无碰撞（`pendingObservationContactTime == nil`），则在 `observationFallbackDelay` 后触发

## 错误处理与降级策略

- **USDZ 模型加载失败**：触发断言，应用无法启动（关键资源缺失）。
- **目标球提取失败**：记录错误日志并跳过缺失球（模型结构异常时可继续运行，但布局可能不完整）。
- **白球资源加载失败**：记录错误日志，`cueBallNode` 为空；依赖白球的流程将被守卫提前返回（属于高风险可观测错误）。
- **物理碰撞体创建失败**：记录错误日志，降级为无碰撞体（球可能穿透台面）。
- **轨迹回放数据缺失**：跳过回放，直接进入回合结束状态（用户体验降级）。
- **渲染质量降级**：帧率低于阈值时自动降低画质（抗锯齿、阴影、后处理），保证流畅度。

## 性能考量

- **渲染循环热点**：`CADisplayLink.renderUpdate()` 每帧调用，包含轨迹回放、阴影更新、相机更新，复杂度 O(n)（n = 球数量）。
- **轨迹回放复杂度**：`TrajectoryPlayback.update(to:)` 线性查找时间点，复杂度 O(m)（m = 记录的事件数量）。
- **阴影更新**：每帧更新所有球影位置，复杂度 O(n)。
- **缓存策略**：
  - `visualCenter()` 结果可缓存（球节点位置不变时）
  - 轨迹预测节流：`lastTrajectoryPreviewTimestamp` 限制更新频率
  - 渲染质量分级：基于帧时长动态适配，避免持续高负载

## 参考实现对照（如适用）

| Swift 文件/函数 | pooltool 对应 | 偏离说明 |
|----------------|--------------|----------|
| `TableModelLoader.loadTableModel()` | 无直接对应（pooltool 无 3D 模型加载） | Scene 模块特有功能，坐标变换逻辑需与 pooltool 的坐标系约定一致（Y-up） |
| `BilliardScene.constrainBallsToSurface()` | 无直接对应（pooltool 物理引擎自动约束） | Scene 模块负责视觉约束，物理约束由 `EventDrivenEngine` 处理 |

## 设计决策记录（ADR）

### 视觉/物理分离架构

- **背景**：USDZ 模型提供视觉表现，但物理引擎需要精确的碰撞体（球体、库边、袋口），两者可能不完全一致。
- **候选方案**：
  1. 直接使用 USDZ 模型的几何体作为物理碰撞体（简单但可能不精确）
  2. 代码生成物理碰撞体，USDZ 仅用于视觉（复杂但精确）
- **结论**：选择方案 2，代码生成物理碰撞体，USDZ 仅用于视觉。理由：物理计算需要精确的几何体（球半径、库边位置、袋口位置），USDZ 模型可能包含装饰性几何，不适合直接用于物理。
- **后果**：需要维护视觉与物理的一致性（如球位置、台面高度），`visualCenter()` 用于对齐视觉中心与物理中心。

### 延迟观察视角

- **背景**：击球后立即切换到观察视角会导致视角混乱（母球可能还在原地），用户无法看清击球瞬间。
- **候选方案**：
  1. 立即切换观察视角（简单但体验差）
  2. 固定延迟切换（简单但可能过早或过晚）
  3. 等待首次球-球碰撞再切换（复杂但体验好）
- **结论**：选择方案 3，等待首次球-球碰撞时间再切换。理由：首次碰撞是用户最关心的时刻，此时切换视角能提供最佳观察体验。
- **后果**：需要记录碰撞时间，在轨迹回放中检测触发条件，若无碰撞则使用后备延迟。

### CADisplayLink 渲染循环

- **背景**：SceneKit 的 `SCNView` 有内置渲染循环，但需要精确控制轨迹回放时序（必须在渲染前更新球位置）。
- **候选方案**：
  1. 使用 SceneKit 的 `SCNSceneRendererDelegate`（简单但时序不可控）
  2. 使用 `CADisplayLink` 自定义渲染循环（复杂但时序可控）
- **结论**：选择方案 2，使用 `CADisplayLink` 自定义渲染循环。理由：需要精确控制轨迹回放、阴影更新、相机更新的时序，确保视觉反馈与物理计算同步。
- **后果**：需要手动管理 `CADisplayLink` 的生命周期（启动/停止），防止循环引用。

### 渲染质量动态适配

- **背景**：不同设备性能差异大，固定画质可能导致低端设备卡顿，高端设备浪费性能。
- **候选方案**：
  1. 固定画质（简单但体验差）
  2. 用户手动选择画质（简单但用户可能不知道如何选择）
  3. 基于帧时长自动适配（复杂但体验好）
- **结论**：选择方案 3，基于帧时长自动适配渲染质量。理由：自动适配能保证流畅度，用户无需关心性能问题。
- **后果**：需要实现帧时长监控、质量分级逻辑、特性开关管理。
