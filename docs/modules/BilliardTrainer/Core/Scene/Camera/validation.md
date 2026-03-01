# Camera（相机系统）- 验证与回归

> 对应 README：[README.md](./README.md)
> 文档最后更新：2026-02-27

## 影响面清单

改动本模块时，必须检查以下影响面：

- [ ] 调用方：`BilliardScene`、`BilliardSceneView`、`TrainingViewModel`（触发状态机事件）
- [ ] 共享常量/状态：`TrainingCameraConfig`（灵敏度、过渡速度、功能开关）、`TablePhysics`（台面尺寸）、`BallPhysics`（球半径）
- [ ] UI 交互链：水平滑动瞄准、垂直滑动调整视角、点击选择目标球、观察模式下的旋转/缩放手势
- [ ] 持久化/数据映射：无（相机状态不持久化）
- [ ] 配置/开关：`TrainingCameraConfig.observationViewEnabled`、`TrainingCameraConfig.autoAlignEnabled`

## 最小回归门禁

每次改动后必须验证（不可跳过）：

### 主路径验证

- [ ] **瞄准流程**：进入训练场 → 水平滑动瞄准 → 瞄准方向正确更新 → 灵敏度随目标球距离动态调整
- [ ] **视角调整流程**：瞄准状态下垂直滑动 → 进入 Adjusting 状态 → zoom 值变化 → 滑动结束返回 Aiming → zoom 值保存
- [ ] **击球观察流程**：瞄准状态下击球 → 进入 Shooting 状态 → 球开始移动进入 Observing 状态 → 相机切换到观察视角 → 用户可手动旋转/缩放 → 选择目标球或球停后进入 ReturnToAim → 动画回归瞄准视角

### 相邻流程验证（至少 2 个）

- [ ] **自动对齐流程**：球停后（功能开启时）→ 相机自动对齐最近可击打球方向 → 功能关闭时使用 fallback 方向
- [ ] **观察模式软限制**：观察模式下手动旋转相机使 pivot 超出边界 → 软限制生效，pivot 缓慢回拉 → 不会硬性截断
- [ ] **用户接管标志**：观察模式下手动旋转相机 → `userHasTakenOverCamera` 标志置为 true → 系统不再自动调整视角 → 选择目标球后标志重置

## 测试入口

| 测试文件 | 覆盖内容 | 运行方式 |
|----------|----------|----------|
| `CameraViewModelTests.swift` | 状态机转换逻辑、事件处理 | `⌘U` / CLI |
| `BilliardSceneCameraTests.swift` | 相机控制器集成测试、手势路由 | `⌘U` / CLI |

## 可观测性

- 日志前缀：`[Camera]`
- 关键观测点：
  - `CameraStateMachine.currentState`：当前状态
  - `CameraStateMachine.onStateChanged`：状态转换回调
  - `ObservationController.userHasTakenOverCamera`：用户接管标志
  - `CameraContext.transition?.isActive`：过渡状态
- 可视化开关：无（相机视角变化可直接观察）

## 常见问题排查

| 症状 | 可能原因 | 排查路径 |
|------|----------|----------|
| 瞄准时灵敏度不变 | `TrainingCameraConfig` 配置错误或目标球列表为空 | 检查配置值、检查 `targetBalls` 参数 |
| 观察模式不切换 | `TrainingCameraConfig.observationViewEnabled` 关闭 | 检查功能开关 |
| 回归瞄准动画不触发 | `returnProgress` 未达到 1.0 或 `returnAnimationCompleted` 事件未触发 | 检查 `updateReturnProgress()` 调用频率、检查动画时长配置 |
| 用户接管后系统仍自动调整 | `userHasTakenOverCamera` 标志未正确设置 | 检查 `handleObservationPan()` / `handleObservationPinch()` 调用 |
| 软限制不生效 | `softClampFactor` 为 0 或 `userHasTakenOverCamera` 为 true | 检查软限制因子值、检查用户接管标志 |

## 未覆盖风险与待补测项

| 风险描述 | 等级 | 建议补测方式 |
|----------|------|-------------|
| 状态机并发访问导致状态不一致 | 中 | 添加状态机锁保护，或确保单线程访问 |
| 观察模式下快速切换目标球导致视角跳跃 | 低 | 添加视角切换动画过渡 |
| 自动对齐计算在极端位置（如台面角落）可能不准确 | 低 | 添加边界检查，限制自动对齐范围 |
| 动态灵敏度计算在目标球重叠时可能不准确 | 低 | 添加目标球去重逻辑 |

## 变更验证记录

| 日期 | 变更摘要 | 验证结果 | 未覆盖项 |
|------|----------|----------|----------|
| 2026-02-27 | 初始文档创建 | 通过（新建文档） | 无 |
| 2026-03-01 | 修复初始 yaw 方向：CameraRig init yaw 从 π 改为 0，CameraContext.default.savedAimPose.yaw 从 π 改为 0，ViewModel 初始 aimDirection 从 (1,0,0) 改为 (-1,0,0)。修复后相机从白球后方看向球堆（-X 方向），符合台球击球视角 | 代码级检查通过：现有测试已使用 aimDirection=(-1,0,0)，与修改一致 | 待真机验证：初始视角正确性、瞄准旋转跟手性、观察视角切换 |
