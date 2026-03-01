# Camera（相机系统）

> 代码路径：`BilliardTrainer/Core/Scene/Camera/`
> 文档最后更新：2026-02-27

## 模块定位

独立的相机子系统，负责管理训练场中的相机视角切换、瞄准控制、观察模式与自动对齐。不处理物理渲染细节（由 Scene 层负责），不处理用户输入原始事件（由 ViewModel 层负责）。

## 入口文件

| 文件 | 职责 | 行数 |
|------|------|------|
| `CameraStateMachine.swift` | 相机状态机：管理 Aiming/Adjusting/Shooting/Observing/ReturnToAim 状态转换 | 281 |
| `AimingController.swift` | 瞄准控制器：水平滑动瞄准 + 动态灵敏度（基于目标球距离） | 90 |
| `ObservationController.swift` | 观察视角控制器：击球后斜俯视观察 + 软限制 pivot + 用户接管标志 | 127 |
| `ViewTransitionController.swift` | 视角过渡控制器：垂直滑动在第一人称/第三人称间连续过渡，zoom 记忆 | 43 |
| `AutoAlignController.swift` | 自动对齐控制器：球停后自动对齐最近可击打球方向（功能开关控制） | 66 |

## 核心概念与术语

| 术语 | 含义 |
|------|------|
| CameraState | 相机状态：aiming（瞄准）、adjusting（调整视角）、shooting（击球中）、observing（观察）、returnToAim（回归瞄准） |
| CameraContext | 相机上下文：包含 mode（aim3D/observe3D/topDown2D）、phase（ballPlacement/aiming/shotRunning/postShot）、interaction（none/draggingCueBall/draggingTargetBall/rotatingCamera）等 |
| CameraPose | 相机姿态：yaw（世界 Y 轴弧度）、pitch（yawNode 局部 X 轴弧度）、radius（pivot 到 camera 的轨道距离）、pivot（世界坐标） |
| CameraIntent | 相机意图：由 InputRouter 将手势转换为相机操作意图（dragCueBall/selectTarget/rotateYaw/zoom 等） |
| PivotAnchor | 枢轴锚点：cueBall（白球）、tableCenter（台面中心）、fixedPoint（固定点）、selectedBall（选中球） |
| 动态灵敏度 | 根据瞄准方向前方是否有目标球，自动调整水平滑动灵敏度（有球区域低灵敏度，无球区域高灵敏度） |
| 软限制（soft clamp） | 观察模式下 pivot 超出边界时的软性回拉（factor=0.2），避免硬性截断导致的视角跳跃 |
| 用户接管标志 | 观察模式下用户手动旋转/缩放相机后，系统不再自动调整视角 |

## 端到端流程

```
用户手势 → InputRouter.routePan/routeTap → CameraIntent → CameraStateMachine.handleEvent → 状态转换 → 对应 Controller 更新 CameraRig → 相机视角更新
```

### 状态转换流程

```
Aiming --[垂直滑动开始]--> Adjusting
Aiming --[击球]--> Shooting
Adjusting --[垂直滑动结束]--> Aiming
Shooting --[球开始移动]--> Observing
Observing --[目标选择/球停]--> ReturnToAim
ReturnToAim --[动画完成]--> Aiming
```

## 对外能力（Public API）

- `CameraStateMachine`：状态机管理，`handleEvent(_:)` 处理状态转换，`onStateChanged` 回调通知状态变化
- `AimingController`：`handleHorizontalSwipe()` 处理水平滑动瞄准，`computeSensitivity()` 计算动态灵敏度
- `ObservationController`：`enterObservation()` 进入观察视角，`updateObservation()` 每帧更新，`beginReturnToAim()` 开始回归瞄准态
- `ViewTransitionController`：`handleVerticalSwipe()` 处理垂直滑动，`saveCurrentZoom()` / `restoreZoom()` 管理 zoom 记忆
- `AutoAlignController`：`computeAlignYaw()` 计算自动对齐目标 yaw（功能开关控制）

## 依赖与边界

- **依赖**：
  - `CameraRig`（相机支架，实际控制 SceneKit 相机节点）
  - `TrainingCameraConfig`（相机配置常量：灵敏度、过渡速度、功能开关等）
  - `TablePhysics`（台面物理常量：高度、尺寸等）
  - `BallPhysics`（球的物理常量：半径等）
- **被依赖**：
  - `BilliardScene` / `BilliardSceneView`（场景视图层，调用相机控制器）
  - `TrainingViewModel`（训练视图模型，触发状态机事件）
- **禁止依赖**：
  - 不直接依赖 `SceneKit` 渲染细节（通过 `CameraRig` 抽象）
  - 不依赖 `Features` 层业务逻辑（保持 Core 层独立性）

## 与其他模块的耦合点

- **Scene 层（BilliardScene）**：通过 `CameraRig` 间接控制 SceneKit 相机节点，耦合点在于相机姿态同步与动画过渡
- **Training 模块**：`TrainingViewModel` 监听物理事件（球开始移动/停止）并触发 `CameraStateMachine` 事件，耦合点在于状态机事件时序
- **Physics 模块**：读取球的位置用于动态灵敏度计算与自动对齐，耦合点在于球位置数据的实时性

## 关键数据结构

| 结构/枚举 | 字段/Case | 单位/生命周期 |
|-----------|-----------|---------------|
| `CameraState` | aiming, adjusting, shooting, observing, returnToAim | 状态机生命周期 |
| `CameraContext` | mode, phase, interaction, selectedBallId, pivotAnchor, shotAnchorPose, transition, savedAimPose, observeTargetBallId 等 | 每帧更新 |
| `CameraPose` | yaw（弧度）, pitch（弧度）, radius（米）, pivot（米） | SceneKit 坐标系 |
| `CameraEvent` | verticalSwipeBegan, shotFired, ballsStartedMoving, ballsStopped, targetSelected, returnAnimationCompleted | 事件驱动 |
| `CameraIntent` | none, dragCueBall, selectTarget(String), rotateYaw(Float), rotateYawPitch, panTopDown, zoom(Float) | 手势路由结果 |
| `PivotAnchor` | cueBall, tableCenter, fixedPoint(SCNVector3), selectedBall(String) | 枢轴锚点类型 |

## 最近变更记录

| 日期 | 变更摘要 | 影响面 |
|------|----------|--------|
| 2026-02-27 | 初始文档创建 | 无（新建文档） |
