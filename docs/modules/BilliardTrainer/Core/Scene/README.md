# Scene 模块

> 代码路径：`BilliardTrainer/Core/Scene/`（不含 Camera/ 子目录）
> 文档最后更新：2026-02-27

## 模块定位

Scene 模块负责台球场景的 3D 渲染与视觉呈现，包括 USDZ 模型加载、SceneKit 场景搭建、球体可视化、相机系统集成、轨迹回放与渲染质量管理。不负责物理计算（由 Physics 模块处理）和相机状态机逻辑（由 Camera 子模块处理）。

## 入口文件

| 文件 | 职责 | 行数 |
|------|------|------|
| `BilliardScene.swift` | SceneKit 场景核心管理器，负责台面/球/相机/灯光/物理碰撞体设置 | ~1940 |
| `BilliardSceneView.swift` | SwiftUI 包装的 SCNView，包含 ViewModel（GameState 管理）和 CADisplayLink 渲染循环 | ~1256 |
| `TableModelLoader.swift` | USDZ 模型加载器，Z-up → Y-up 坐标变换，球杆提取，缩放与表面高度验证 | ~300 |
| `TableGeometry.swift` | 球台几何定义（袋口位置、库边线段/圆弧），供物理引擎使用 | ~200 |
| `MaterialFactory.swift` | PBR 材质增强（球体清漆、台面法线贴图、库边木纹、袋口皮革） | ~250 |
| `EnvironmentLightingManager.swift` | IBL 立方体贴图与背景渐变生成，工作室风格光照预设 | ~150 |
| `RenderQualityManager.swift` | 渲染质量分级（低/中/高），基于帧时长的动态适配，特性开关 | ~200 |
| `CueStick.swift` | 3D 球杆模型，碰撞检测（最大仰角 30°），击球动画 | ~200 |
| `CameraRig.swift` | 相机轨道系统，zoom 0-1 驱动 pitch/radius/height/FOV 插值，平滑姿态过渡 | ~150 |

## 核心概念与术语

| 术语 | 含义 |
|------|------|
| **视觉/物理分离** | USDZ 模型提供视觉表现，代码生成物理碰撞体（球体、库边、袋口），两者独立管理 |
| **USDZ 流水线** | 台桌 USDZ 加载 → Z-up 转 Y-up → 缩放验证 → 目标球(`_1..._15`)提取 → 白球（兼容 `_0` / `BaiQiu`）提取 → 场景集成；白球提取失败时降级到 `cueball.usdz` |
| **渲染循环** | CADisplayLink 驱动的每帧更新：轨迹回放 → 阴影位置 → 相机姿态 → 球杆动画 → 渲染质量适配 |
| **延迟观察视角** | 击球后等待首次球-球碰撞时间再切换到观察视角，避免过早切换导致视角混乱 |
| **GameState** | 游戏状态机：`.idle` → `.placing` → `.aiming` → `.ballsMoving` → `.turnEnd` |
| **CameraMode** | 视角模式：`.aim`（瞄准态）、`.action`（兼容旧值）、`.topDown2D`（2D 俯视） |
| **轨迹回放** | 基于 `TrajectoryRecorder` 记录的物理事件，在 CADisplayLink 中逐帧驱动球节点位置/旋转 |
| **视觉中心对齐** | 球节点的 `position` 可能不在几何中心，通过 `visualCenter()` 计算真实中心用于物理计算 |

## 端到端流程

```
用户操作 → 手势识别（InputRouter）→ ViewModel 状态更新 → 场景视觉反馈
    ↓
击球触发 → EventDrivenEngine 物理模拟 → TrajectoryRecorder 记录 → TrajectoryPlayback 回放
    ↓
CADisplayLink 渲染循环 → 球位置更新 → 相机跟随 → 阴影更新 → 帧率监控 → 质量降级
    ↓
首次球-球碰撞 → 延迟观察视角触发 → 相机平滑过渡 → 用户观察球运动
    ↓
所有球静止 → GameState 切换 → 规则判定 → 回合结束回调
```

## 对外能力（Public API）

### BilliardScene

- `setupScene()`：初始化场景（环境/地面/台面/灯光/相机/物理）
- `setupTable()`：加载 USDZ 模型，提取球节点，设置物理碰撞体
- `setupModelBalls()`：从台桌 USDZ 提取 `_1..._15`（目标球）和白球（兼容 `_0` / `BaiQiu`），设置物理体并建立命名映射；白球提取失败时降级到 `cueball.usdz`
- `applyBallLayout(_:)`：应用训练场景的球布局，隐藏未使用的球
- `showAimLine(direction:power:)`：显示瞄准线（从母球指向目标方向）
- `showPredictedTrajectory(_:)`：显示预测轨迹（母球路径 + 目标球路径）
- `constrainBallsToSurface()`：将球约束到台面高度（TablePhysics.height + BallPhysics.radius）
- `updateShadowPositions()`：更新球影位置（每帧调用）
- `visualCenter(of:)`：计算球节点的真实视觉中心（用于物理计算）
- `resetScene()`：重置所有球到初始位置
- `captureCurrentCameraPose()`：捕获当前相机姿态（用于观察视角锚点）

### BilliardSceneViewModel

- `setupTrainingScene(type:ballPositions:)`：设置训练场景（重置球位置，应用布局，切换到瞄准态）
- `executeStroke(power:)`：执行击球（创建 EventDrivenEngine，记录轨迹，启动回放）
- `updateTrajectoryPlaybackFrame(timestamp:)`：每帧更新轨迹回放（由 CADisplayLink 调用）
- `transitionToAimState(animated:)`：切换到瞄准态
- `enterTopDownState(animated:)`：进入 2D 俯视态
- `gameState`：游戏状态（`.idle`、`.placing`、`.aiming`、`.ballsMoving`、`.turnEnd`）
- `shotEvents`：当前击球的事件记录（供规则判定使用）

### TableModelLoader

- `loadTableModel(from:)`：加载 USDZ 模型，执行坐标变换，验证缩放与表面高度
- `extractCueStick(from:)`：从模型中提取球杆节点

### TableGeometry

- `chineseEightBall()`：创建中式八球台面几何（袋口位置、库边线段/圆弧）

## 依赖与边界

- **依赖**：
  - `Core/Physics`：`EventDrivenEngine`（物理模拟）、`TrajectoryPlayback`（轨迹回放）、`TrajectoryRecorder`（轨迹记录）、`CueBallStrike`（击球计算）、`CollisionResolver`（碰撞解析）
  - `Core/Scene/Camera`：`CameraStateMachine`（相机状态机）、`AimingController`（瞄准控制）、`ObservationController`（观察控制）、`ViewTransitionController`（视角过渡）、`AutoAlignController`（自动对齐）
  - `Core/Audio`：`AudioManager`（击球音效）
  - `PhysicsConstants`：`TablePhysics`、`BallPhysics`、`SceneLayout`、`CueStickSettings`、`TrainingCameraConfig`
- **被依赖**：
  - `Features/Training`：`TrainingSceneView` 使用 `BilliardSceneView`
  - `Features/FreePlay`：`FreePlayView` 使用 `BilliardSceneView`
- **禁止依赖**：不应反向依赖 `Features` 层实现细节

## 与其他模块的耦合点

- **Physics 模块**：Scene 消费 `EventDrivenEngine` 的轨迹数据，通过 `TrajectoryPlayback` 回放。物理常量（`TablePhysics.height`、`BallPhysics.radius`）必须与 Physics 模块一致。
- **Camera 模块**：Scene 持有 `CameraStateMachine` 和各类控制器，但相机状态转换逻辑由 Camera 模块管理。Scene 负责视觉反馈（相机节点位置/旋转）。
- **Training/FreePlay**：通过 `BilliardSceneViewModel` 的 `setupTrainingScene()` 和 `executeStroke()` 接口交互，状态变化通过 `@Published` 属性通知 UI。

## 关键数据结构

| 结构/枚举 | 字段/Case | 单位/生命周期 |
|-----------|-----------|---------------|
| `GameState` | `.idle`、`.placing`、`.aiming`、`.ballsMoving`、`.turnEnd` | 游戏流程状态机 |
| `CameraMode` | `.aim`、`.action`、`.topDown2D` | 视角模式（兼容旧值） |
| `BallPosition` | `name: String`、`position: SCNVector3` | 训练场景球布局 |
| `TrajectoryRecorder` | `recordBallState(_:at:)`、`recordEvent(_:)` | 记录物理事件，供回放使用 |
| `TrajectoryPlayback` | `update(to:)`、`isComplete` | 基于记录数据驱动球节点位置 |

## 最近变更记录

| 日期 | 变更摘要 | 影响面 |
|------|----------|--------|
| 2026-02-27 | 初始文档创建 | 无 |
| 2026-02-27 | 白球加载改为独立 `cueball.usdz`，台桌模型仅提取目标球 `_1..._15` | `BilliardScene.setupModelBalls()`、`allBallNodes["cueBall"]` 初始化路径 |
