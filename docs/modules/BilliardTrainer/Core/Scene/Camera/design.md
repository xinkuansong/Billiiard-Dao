# Camera（相机系统）- 设计与约束

> 对应 README：[README.md](./README.md)
> 文档最后更新：2026-02-27

## 设计目标与非目标

- **目标**：
  - 提供流畅的相机视角切换体验（瞄准 → 观察 → 回归瞄准）
  - 支持动态灵敏度调整，提升瞄准精度（有球区域低灵敏度，无球区域高灵敏度）
  - 观察模式下支持用户手动接管相机控制，同时提供软限制防止视角越界
  - 通过状态机管理复杂的状态转换，确保状态一致性
- **非目标**：
  - 不处理物理渲染细节（由 Scene 层负责）
  - 不处理用户输入原始事件解析（由 ViewModel 层负责）
  - 不实现复杂的相机动画曲线（使用 `CameraRig` 提供的简单动画）

## 不变量与约束（改动护栏）

### 单位与坐标系

- 所有角度单位为弧度（rad），距离单位为米（m）
- 使用 SceneKit Y-up 坐标系
- `CameraPose.yaw`：世界 Y 轴旋转角度（弧度）
- `CameraPose.pitch`：yawNode 局部 X 轴旋转角度（弧度）
- `CameraPose.radius`：pivot 到 camera 的轨道距离（沿 rig -Z 方向，米）
- `CameraPose.pivot`：世界坐标（米）

### 数值稳定性保护

- **动态灵敏度计算**：`AimingController.computeSensitivity()` 中，`aimNorm.length() > 0.0001` 检查避免除零，`dot` 值限制在 [-1, 1] 范围内避免 `acosf()` 异常
- **软限制因子**：`ObservationController.softClampFactor = 0.2`，不可删除或随意修改，避免硬性截断导致的视角跳跃
- **用户接管标志**：`ObservationController.userHasTakenOverCamera`，一旦用户手动操作相机，系统不再自动调整，避免冲突
- **状态机转换保护**：`CameraStateMachine.nextState()` 中，未定义的状态转换返回当前状态，避免非法状态

### 时序与状态约束

- **状态转换顺序**：必须遵循 `Aiming → Adjusting/Shooting → Observing → ReturnToAim → Aiming` 的闭环，不可跳过中间状态
- **事件触发时机**：
  - `shotFired` 必须在 `ballsStartedMoving` 之前触发
  - `ballsStopped` 触发后，必须等待用户选择目标或自动触发 `returnToAim`
  - `returnAnimationCompleted` 必须在 `ReturnToAim` 状态下，且 `returnProgress >= 1.0` 时触发
- **保存瞄准上下文**：`CameraStateMachine.saveAimContext()` 必须在 `Shooting` 状态前调用，用于 `ReturnToAim` 恢复
- **观察模式进入**：`ObservationController.enterObservation()` 必须在 `Shooting → Observing` 转换时调用，且需要传入击球时的白球位置与瞄准方向

### 常量与阈值清单

| 常量/阈值 | 值 | 来源/理由 | 改动影响 |
|-----------|-----|----------|----------|
| `TrainingCameraConfig.highSensitivity` | 高灵敏度值 | 配置常量 | 影响无球区域的瞄准速度 |
| `TrainingCameraConfig.lowSensitivity` | 低灵敏度值 | 配置常量 | 影响有球区域的瞄准精度 |
| `TrainingCameraConfig.sensitivityTransitionAngle` | 灵敏度过渡角度（度） | 配置常量 | 影响灵敏度切换的平滑度 |
| `ObservationController.softClampFactor` | 0.2 | 软限制因子，避免硬性截断 | 影响观察模式下 pivot 越界时的回拉速度 |
| `TrainingCameraConfig.observationViewEnabled` | 功能开关 | 配置常量 | 控制观察模式是否启用 |
| `TrainingCameraConfig.autoAlignEnabled` | 功能开关 | 配置常量 | 控制自动对齐是否启用 |
| `TrainingCameraConfig.returnToAimDuration` | 回归动画时长（秒） | 配置常量 | 影响 `ReturnToAim` 动画时长 |
| `TrainingCameraConfig.cameraTransitionSpeed` | 相机过渡速度 | 配置常量 | 影响相机动画的平滑度 |

## 状态机 / 事件模型

```
Aiming --[verticalSwipeBegan]--> Adjusting
Aiming --[shotFired]--> Shooting
Adjusting --[verticalSwipeEnded]--> Aiming
Shooting --[ballsStartedMoving]--> Observing
Observing --[ballsStopped]--> Observing (保持观察，等待用户选择)
Observing --[targetSelected]--> ReturnToAim
ReturnToAim --[returnAnimationCompleted]--> Aiming
```

### 状态说明

- **Aiming（瞄准）**：默认状态，用户可水平滑动瞄准，垂直滑动进入 Adjusting
- **Adjusting（调整视角）**：垂直滑动调整 zoom（第一人称/第三人称），滑动结束后返回 Aiming
- **Shooting（击球中）**：击球瞬间，保存瞄准上下文，等待球开始移动
- **Observing（观察）**：球移动过程中，相机切换到观察视角，用户可手动旋转/缩放
- **ReturnToAim（回归瞄准）**：球停后，相机动画回归到瞄准视角

## 错误处理与降级策略

- **InputRouter 路由失败**：返回 `CameraIntent.none`，不执行任何操作
- **状态机非法转换**：`nextState()` 返回当前状态，保持状态稳定
- **观察模式功能关闭**：`ObservationController.enterObservation()` 中检查 `TrainingCameraConfig.observationViewEnabled`，功能关闭时直接返回
- **自动对齐功能关闭**：`AutoAlignController.computeAlignYaw()` 中检查 `TrainingCameraConfig.autoAlignEnabled`，功能关闭时返回 fallback 方向
- **相机过渡冲突**：`ObservationController.updateObservation()` 中检查 `isTransitionLocked`，过渡中不执行自动调整

## 性能考量

- **动态灵敏度计算**：`AimingController.computeSensitivity()` 遍历所有目标球计算最小角度，复杂度 O(n)，n 为目标球数量（通常 < 15），性能可接受
- **自动对齐计算**：`AutoAlignController.computeAlignYaw()` 遍历所有目标球找最近距离，复杂度 O(n)，仅在球停后调用一次，性能可接受
- **状态机更新**：状态转换仅在事件触发时执行，无每帧开销
- **观察模式更新**：`ObservationController.updateObservation()` 每帧调用，但大部分情况下因 `userHasTakenOverCamera` 或 `isTransitionLocked` 提前返回，实际开销很小

## 参考实现对照（如适用）

本模块不涉及物理引擎计算，无需对照 pooltool 参考实现。

## 设计决策记录（ADR）

### ADR-001：使用状态机管理相机状态

- **背景**：相机系统有多个状态（瞄准、调整、击球、观察、回归），状态转换复杂，需要确保状态一致性
- **候选方案**：
  1. 使用状态机（当前方案）
  2. 使用标志位组合（如 `isAiming && isAdjusting`）
  3. 使用命令模式
- **结论**：选择状态机方案，因为状态转换有明确的顺序约束，状态机能清晰表达这些约束，避免非法状态
- **后果**：状态转换必须通过 `CameraStateMachine.handleEvent()`，不能直接修改状态

### ADR-002：动态灵敏度调整

- **背景**：瞄准时，有球区域需要高精度（低灵敏度），无球区域需要快速移动（高灵敏度）
- **候选方案**：
  1. 固定灵敏度（简单但体验差）
  2. 基于目标球距离的动态灵敏度（当前方案）
  3. 基于目标球角度的动态灵敏度
- **结论**：选择基于目标球角度的动态灵敏度，因为角度更能反映"瞄准方向前方是否有球"的语义
- **后果**：需要每帧计算目标球角度，但目标球数量有限，性能可接受

### ADR-003：观察模式软限制

- **背景**：观察模式下，pivot 可能超出台面边界，需要限制但避免硬性截断导致的视角跳跃
- **候选方案**：
  1. 硬限制（直接截断到边界）
  2. 软限制（当前方案，factor=0.2 的线性插值）
  3. 不限制（允许越界）
- **结论**：选择软限制，因为硬限制会导致视角突然跳跃，不限制会导致视角越界影响体验
- **后果**：需要每帧检查并应用软限制，但计算简单，性能可接受
