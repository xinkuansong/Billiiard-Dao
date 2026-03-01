# Scene（场景渲染） - 验证与回归

> 对应 README：[README.md](./README.md)
> 文档最后更新：2026-02-27

## 影响面清单

改动本模块时，必须检查以下影响面：

- [ ] 调用方：`Features/Training/TrainingSceneView`、`Features/FreePlay/FreePlayView`
- [ ] 共享常量/状态：`PhysicsConstants`（TablePhysics、BallPhysics、SceneLayout、CueStickSettings）
- [ ] UI 交互链：瞄准线显示、轨迹预测渲染、球影更新、球杆动画、手势路由
- [ ] 物理模块耦合：`EventDrivenEngine`（模拟触发）、`TrajectoryPlayback`（回放同步）、`CollisionResolver`（碰撞效果）
- [ ] Camera 子模块：`CameraStateMachine`、`CameraRig`、所有 Controller
- [ ] 音效模块：`AudioManager`（碰撞/入袋/击球音效触发点）
- [ ] 配置/开关：`RenderQualityManager` 渲染质量档位、`SettingsView` 中的 aimLineEnabled / trajectoryEnabled

## 最小回归门禁

每次改动后必须验证（不可跳过）：

### 主路径验证

- [ ] 场景加载：App 启动 → 进入训练/自由练习 → 台球桌正确显示（模型朝向、球位置、材质）
- [ ] 击球流程：瞄准 → 调整力度 → 击球 → 球运动 → 停止 → 返回瞄准状态

### 相邻流程验证（至少 2 个）

- [ ] 轨迹回放：击球后轨迹回放与球实际运动同步，球入袋时正确淡出
- [ ] 相机切换：瞄准视角 ↔ 观察视角切换流畅，无穿模/黑屏
- [ ] 球杆显示：瞄准时球杆正确显示，击球动画正常，碰撞时自动抬升
- [ ] 球布局应用：`applyBallLayout()` 后球在正确位置，无重叠

## 测试入口

| 测试文件 | 覆盖内容 | 运行方式 |
|----------|----------|----------|
| `BilliardSceneCameraTests.swift` | 相机集成测试 | `⌘U` |
| `TableGeometryTests.swift` | 台面几何（袋口/库边段） | `⌘U` |

## 可观测性

- 日志前缀：`[BilliardScene]`、`[TableModelLoader]`、`[RenderQuality]`
- 关键观测点：
  - `TableModelLoader`：加载后的 `appliedScale`、`surfaceY`、容器变换矩阵
  - `BilliardScene.setupModelBalls()`：球可视中心偏移、对齐校正
  - `RenderQualityManager`：当前渲染档位、FPS 历史、档位切换事件
  - `BilliardSceneViewModel`：`gameState` 状态变化、轨迹回放进度
- 可视化开关：
  - 瞄准辅助线（`aimLineEnabled`）
  - 轨迹预测（`trajectoryEnabled`）
  - FPS 徽章（`TrainingSceneView` 中的 `FPSBadge`）

## 常见问题排查

| 症状 | 可能原因 | 排查路径 |
|------|----------|----------|
| 台面模型方向错误 | `TableModelLoader` 的 Z-up → Y-up 变换被修改 | 检查容器节点的 `eulerAngles.x` 是否为 `-π/2` |
| 球漂浮或陷入台面 | `surfaceY` 计算错误或 `constrainBallsToSurface()` 未调用 | 检查 `TablePhysics.height + BallPhysics.radius` 与实际 Y 值 |
| 球可视中心偏移 | `visualCenter(of:)` 计算错误或 USDZ 模型结构变更 | 检查球节点的 boundingBox 与 root position 差异 |
| 相机穿过台面 | 射线约束失效或 `minDistance` 未生效 | 检查 `CameraRig` 的 `applyCameraTransform()` 中的 raycast |
| 球影位置不对 | `updateShadowPositions()` 未随球运动调用 | 检查 render loop 中的调用顺序 |
| 渲染帧率下降 | 渲染档位未降级或材质着色器过重 | 查看 `RenderQualityManager` 的 FPS 记录和当前档位 |
| 轨迹回放不同步 | CADisplayLink 时间戳与回放时间不匹配 | 检查 `updateTrajectoryPlaybackFrame()` 的时间偏移 |

## 敏感区特别提醒

`TableModelLoader.swift` 属于敏感区文件（见 `09-sensitive-areas-do-not-touch-lightly.mdc`）：

- 不可随意变更 Z-up → Y-up 坐标变换链
- 不可删除 scale/surfaceY 范围验证（fallback 到程序化台面）
- 改动前必须说明变更理由与验证方式

## 未覆盖风险与待补测项

| 风险描述 | 等级 | 建议补测方式 |
|----------|------|-------------|
| BilliardScene.swift 1940 行无单测覆盖 | 高 | 拆分关键逻辑（球布局、影子更新）为可测试函数 |
| MaterialFactory 着色器兼容性 | 中 | 在低端设备（A12 以下）验证 clearcoat shader |
| EnvironmentLightingManager IBL 质量 | 低 | 对比 HDRI 与程序化 IBL 在不同场景的视觉差异 |
| 手势路由在不同 gameState 下的覆盖度 | 中 | 补充 InputRouter 的状态组合测试 |

## 变更验证记录

| 日期 | 变更摘要 | 验证结果 | 未覆盖项 |
|------|----------|----------|----------|
| 2026-02-27 | 初始文档创建 | - | 全部待首次验证填充 |
| 2026-02-27 | 白球加载改为 `Resources/cueball.usdz`（`setupModelBalls()` 改为仅提取 `_1..._15`） | 代码级检查通过：`cueBallNode` 与 `allBallNodes["cueBall"]` 仍在同一初始化流程注册；资源路径存在 | 未在真机/模拟器执行主路径与相邻流程（场景加载、击球流程、轨迹回放、相机切换） |
| 2026-03-01 | 白球加载改回从 `TaiQiuZhuo.usdz` 提取 `_0` 节点（`cueball.usdz` 不存在导致白球加载失败）；`loadCueBallFromResource()` 保留为降级方案；残留清理范围扩展为 `_0..._15` | 代码级检查通过：`extractCueBallFromModel()` 复用目标球提取逻辑，`cueBallNode`/`allBallNodes["cueBall"]`/`initialBallPositions["cueBall"]` 注册路径完整；白球放置于置球点 `(headStringX, correctY, 0)` | 待真机/模拟器验证：场景加载后白球正确显示、击球流程正常、相机跟随白球、轨迹回放同步 |
| 2026-03-01 | 修复开球方向：CameraRig 初始 yaw 从 π→0，ViewModel 初始 aimDirection 从 (1,0,0)→(-1,0,0)；修复视角控制：renderUpdate 相机更新不再依赖 cueBallNode（cueBall 为 nil 时使用台面中心作为 fallback pivot），rotateYaw 手势也增加 cueBall 缺失时的 fallback 路径 | 代码级检查通过 | 待真机验证：初始视角、瞄准旋转、缩放、观察视角切换 |
| 2026-03-01 | 修复白球命名兼容：`extractCueBallFromModel()` 从仅匹配 `_0` 扩展为匹配 `_0`/`BaiQiu`；白球失败日志与残留清理同步扩展（`_0`、`BaiQiu`） | 代码级检查通过：`TaiQiuZhuo.usdz` 的白球 prim 名为 `BaiQiu`，可被成功提取并注册到 `cueBallNode` / `allBallNodes["cueBall"]` | 待真机/模拟器验证：场景初始化白球可见、球杆显示、瞄准线与出杆流程恢复 |
| 2026-03-01 | 修复“白球成功加载但不可见”：模型白球提取后增加可见性修复（递归 `isHidden=false`、`opacity=1`、`material.transparency=1`）并强制 `alignVisualCenter` 对齐置球点；新增 `visualCenter/centerOffset` 诊断日志 | 代码级检查通过：白球节点注册路径不变，新增可见性与位置兜底不影响目标球提取 | 待真机/模拟器验证：白球在桌面可见且位于开球点；`centerOffset` 接近 0；出杆与球杆显示恢复 |
| 2026-03-01 | 彻底修复白球不可见：将白球提取从独立函数 `extractCueBallFromModel` 合并回主球提取循环 `setupModelBalls()`，与目标球复用完全相同的提取代码路径；删除独立函数消除潜在差异；`TableModelLoader.ballNodeNames` 增加 `BaiQiu` 确保边界框计算一致 | 编译通过；白球与目标球走相同提取路径，消除了独立函数可能引入的 closure/coordinate/visibility 差异 | 合并后仍不可见，根因为双重缩放 |
| 2026-03-01 | 修复双重缩放根因：BaiQiu Xform 自带 localScale≈0.001（网格顶点 28 单位），提取时 worldScale=0.001 已包含此 localScale，但 anchorNode reparent 后仍保留 0.001 的 localScale，导致 effectiveScale=0.001×0.001=0.000001（球仅 0.028mm）。修复方式：`anchorNode.removeFromParentNode()` 后立即 `anchorNode.transform = SCNMatrix4Identity` 重置为单位矩阵；增加 `ensureCueBallRenderable()` 后处理（诊断 + 强制不透明 + 程序化球兜底） | 编译通过；目标球 localScale≈1.0 不受影响；白球 effectiveScale 修复为 0.001×1.0=0.001（世界半径 28×0.001=0.028m 正确） | 待真机/模拟器验证：白球在桌面可见且尺寸正确 |
| 2026-03-02 | 修复渲染质量降级后帧率不恢复：(1) EnvironmentLightingManager 按 tier 缓存 IBL/背景立方体贴图；(2) reapplyRenderSettings 在自动降级时延迟材质重刷；(3) RenderQualityManager 新增球停后恢复评估机制 | 编译通过；影响面：RenderQualityManager、EnvironmentLightingManager、BilliardScene、BilliardSceneView | 待真机验证：开球 → 帧率降级 → 球停后自动恢复画质 |
