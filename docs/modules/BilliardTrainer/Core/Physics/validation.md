# Physics 模块 - 验证与回归

> 对应 README：[README.md](./README.md)
> 文档最后更新：2026-02-27

## 影响面清单

改动本模块时，必须检查以下影响面：

- [ ] **调用方**：
  - `BilliardSceneViewModel`（`BilliardTrainer/Core/Scene/BilliardSceneView.swift`）：调用 `EventDrivenEngine.simulate()` 执行击球，读取 `resolvedEvents` 进行规则判定，使用 `firstBallBallCollisionTime` 控制相机切换
  - `BilliardScene`（`BilliardTrainer/Core/Scene/BilliardScene.swift`）：使用 `PhysicsEngine` 进行实时物理更新，同步球节点位置和状态
- [ ] **共享常量/状态**：
  - `PhysicsConstants`（`BilliardTrainer/Utilities/Constants/PhysicsConstants.swift`）：所有物理常量（球半径、质量、摩擦系数、台面尺寸等），改动需评估对碰撞检测、运动衰减、进袋判断的影响
  - `TableGeometry`（`BilliardTrainer/Core/Scene/TableGeometry.swift`）：台面几何信息（库边位置、袋口位置），影响碰撞检测和进袋判断
- [ ] **UI 交互链**：
  - 轨迹显示：`TrajectoryPlayback` 提供状态查询，影响轨迹可视化
  - 瞄准线：`PhysicsEngine.predictTrajectory()` 影响瞄准线预测
  - 相机切换：`EventDrivenEngine.firstBallBallCollisionTime` 影响观察视角切换时机
- [ ] **持久化/数据映射**：
  - 轨迹数据：`TrajectoryRecorder` 记录的轨迹数据可能用于训练记录存储（由 Features 层处理）
- [ ] **配置/开关**：
  - 无直接配置项，但物理常量可通过 `PhysicsConstants` 调整

## 最小回归门禁

每次改动后必须验证（不可跳过）：

### 主路径验证

- [ ] **主路径 1：执行击球 → 球正确运动 → 停止**
  - 操作步骤：
    1. 启动应用，进入训练场
    2. 瞄准母球，设置力度和方向
    3. 执行击球
    4. 观察球运动轨迹
    5. 等待所有球停止
  - 预期结果：
    - 母球按预期方向运动
    - 碰撞后球正确分离
    - 所有球最终停止（速度 < 0.005 m/s，角速度 < 0.1 rad/s）
    - 无穿透、无能量爆炸、无卡死

- [ ] **主路径 2：库边碰撞准确性**
  - 操作步骤：
    1. 瞄准母球，设置方向使其撞击库边
    2. 执行击球
    3. 观察库边碰撞后的反弹角度
  - 预期结果：
    - 库边碰撞角度符合物理规律（入射角 ≈ 反射角，考虑摩擦和旋转）
    - 无穿透库边
    - 碰撞后速度衰减合理

- [ ] **主路径 3：进袋检测**
  - 操作步骤：
    1. 瞄准目标球，使其直接进袋
    2. 执行击球
    3. 观察进袋事件触发
  - 预期结果：
    - 球进入袋口时正确触发进袋事件
    - 无误检（球未进袋但触发事件）
    - 无漏检（球进袋但未触发事件）

### 相邻流程验证（至少 2 个）

- [ ] **相邻流程 1：轨迹回放同步**
  - 操作步骤：
    1. 执行一次击球
    2. 使用 `TrajectoryPlayback` 查询不同时刻的球状态
    3. 对比回放状态与原始模拟状态
  - 预期结果：
    - 回放状态与原始模拟状态一致
    - 事件时刻的状态准确
    - 无时间跳跃或状态不一致

- [ ] **相邻流程 2：多球连续碰撞**
  - 操作步骤：
    1. 设置多球场景（如 3-4 个球）
    2. 执行击球，触发连续碰撞
    3. 观察碰撞顺序和能量守恒
  - 预期结果：
    - 碰撞顺序正确（按事件时间顺序）
    - 能量大致守恒（考虑摩擦损失）
    - 无穿透、无能量爆炸

- [ ] **相邻流程 3：状态转换准确性**
  - 操作步骤：
    1. 执行击球，观察球从滑动到滚动到旋转到静止的转换
    2. 验证转换时机是否符合物理规律
  - 预期结果：
    - 滑动→滚动转换时机正确（relSpeed <= 0.03）
    - 滚动→旋转转换时机正确（speed < 0.005 && angularSpeed >= 0.1）
    - 旋转→静止转换时机正确（angularSpeed < 0.1）

## 测试入口

| 测试文件 | 覆盖内容 | 运行方式 |
|----------|----------|----------|
| `EventDrivenEngineTests.swift` | 事件驱动引擎核心功能：事件查找、状态演化、事件解析 | `⌘U` / `swift test` |
| `CollisionDetectorTests.swift` | 碰撞检测：球-球碰撞时间、球-库边碰撞时间、四次方程求解 | `⌘U` / `swift test` |
| `CollisionResolverTests.swift` | 碰撞解析：球-球碰撞冲量、球-库边碰撞冲量、能量守恒 | `⌘U` / `swift test` |
| `CushionCollisionModelTests.swift` | 库边碰撞模型：Mathavan 2010 积分、压缩/恢复阶段 | `⌘U` / `swift test` |
| `QuarticSolverTests.swift` | 四次方程求解器：Ferrari 方法、Newton-Raphson 抛光、根筛选 | `⌘U` / `swift test` |
| `AnalyticalMotionTests.swift` | 解析运动：滑动/滚动/旋转方程、状态转换时间 | `⌘U` / `swift test` |
| `CueBallStrikeTests.swift` | 击球模型：初始速度/角速度计算、squirt 角度 | `⌘U` / `swift test` |
| `TrajectoryPlaybackTests.swift` | 轨迹回放：状态查询、事件时刻准确性 | `⌘U` / `swift test` |
| `PhysicsRegressionTests.swift` | 回归测试：已知场景的物理行为一致性 | `⌘U` / `swift test` |
| `PhysicsStabilityPerformanceTests.swift` | 稳定性与性能：零时刻事件保护、最大事件数、计算性能 | `⌘U` / `swift test` |
| `CrossEngineComparisonTests.swift` | 引擎对比：EventDrivenEngine vs PhysicsEngine 结果一致性 | `⌘U` / `swift test` |

## 可观测性

- **日志前缀**：`[PhysicsEngine]`、`[EventDrivenEngine]`、`[CollisionDetector]`、`[CollisionResolver]`、`[CushionCollisionModel]`、`[QuarticSolver]`、`[AnalyticalMotion]`、`[CueBallStrike]`、`[TrajectoryPlayback]`、`[TrajectoryRecorder]`
- **关键观测点**：
  - 零时刻事件计数：`[EventDrivenEngine] zeroTimeEventStreak = N`
  - 碰撞检测失败：`[CollisionDetector] quartic solver failed, using fallback`
  - 库边积分不收敛：`[CushionCollisionModel] integration reached max steps`
  - 重叠分离失败：`[EventDrivenEngine] failed to separate overlapping balls`
  - 事件队列溢出：`[EventDrivenEngine] reached max events limit`
- **可视化开关**：
  - 轨迹可视化：由 Scene 模块负责，Physics 模块提供 `TrajectoryPlayback` 接口
  - 事件标记：可在 Scene 模块中添加事件时刻的可视化标记

## 常见问题排查

| 症状 | 可能原因 | 排查路径 |
|------|----------|----------|
| **球穿透** | 碰撞检测失败或时间计算错误 | 1. 检查 `CollisionDetector` 日志，确认碰撞时间计算 2. 验证 `QuarticSolver` 根筛选逻辑 3. 检查 fallback 碰撞检测是否触发 |
| **能量爆炸** | 碰撞解析错误或状态转换异常 | 1. 检查 `CollisionResolver` 冲量计算 2. 验证状态转换时机是否正确 3. 检查摩擦系数是否合理 |
| **零时刻事件循环** | 重叠球未正确分离或事件优先级错误 | 1. 检查 `separateOverlappingBalls()` 是否执行 2. 验证零时刻事件保护是否触发（阈值 80） 3. 检查事件优先级是否正确 |
| **进袋误检/漏检** | 袋口距离计算错误或阈值不合理 | 1. 检查 `TableGeometry` 袋口位置 2. 验证进袋检测距离阈值 3. 检查球位置计算是否准确 |
| **轨迹回放不同步** | 快照记录时机错误或状态查询逻辑错误 | 1. 检查 `TrajectoryRecorder.recordSnapshot()` 调用时机 2. 验证 `TrajectoryPlayback` 状态插值逻辑 3. 对比原始模拟与回放状态 |
| **库边碰撞角度异常** | Mathavan 模型积分错误或库边几何错误 | 1. 检查 `CushionCollisionModel` 积分步数和步长 2. 验证库边法向量计算 3. 检查库边摩擦系数 |
| **状态转换时机错误** | 转换阈值不合理或状态判断逻辑错误 | 1. 检查 `AnalyticalMotion` 转换时间计算 2. 验证状态判定阈值（滑动 0.03，静止 0.005/0.1） 3. 检查状态转换优先级 |

## 未覆盖风险与待补测项

| 风险描述 | 等级 | 建议补测方式 |
|----------|------|-------------|
| **极端碰撞角度** | 中 | 添加边界测试：球以极小角度擦过库边、球几乎正碰库边 |
| **高速多球场景** | 中 | 性能测试：10+ 球同时运动，验证事件队列性能和计算时间 |
| **长时间模拟** | 低 | 稳定性测试：模拟 30+ 秒，验证能量守恒和数值稳定性 |
| **pooltool 对照验证** | 高 | 交叉验证：使用相同初始条件，对比 Swift 与 Python 实现的结果差异 |
| **数值精度边界** | 中 | 精度测试：验证浮点数精度对碰撞时间计算的影响 |
| **内存泄漏** | 低 | 内存分析：长时间运行后检查 `EventCache` 和 `TrajectoryRecorder` 内存占用 |

## 变更验证记录

| 日期 | 变更摘要 | 验证结果 | 未覆盖项 |
|------|----------|----------|----------|
| 2026-02-27 | 创建模块文档 | 无代码变更 | 无 |
