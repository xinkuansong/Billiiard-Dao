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
- **球杆两阶段出杆时序**：用户松手后进入 `isPreparingStroke` 阶段（gameState 仍为 `.aiming`），球杆以 `pullBackSpeed` 匀速回拉，同时后台预计算物理模拟。回拉完成后播放前冲动画并切换到 `.ballsMoving`。在 `isPreparingStroke` 期间：渲染循环不更新球杆位置（由 SCNTransaction 动画控制）、瞄准手势禁止、力度条禁用。
- **轨迹回放时序**：必须在 `CADisplayLink` 的 `renderUpdate()` 中先调用 `updateTrajectoryPlaybackFrame()`，再更新阴影和相机，确保球位置先于视觉反馈更新。

### 常量与阈值清单

| 常量/阈值 | 值 | 来源/理由 | 改动影响 |
|-----------|-----|----------|----------|
| `TablePhysics.height` | 0.71 m | Physics 模块定义 | 球 Y 坐标约束，台面高度 |
| `BallPhysics.radius` | 0.028575 m | Physics 模块定义 | 球 Y 坐标约束，碰撞检测 |
| `CueStickSettings.maxElevation` | 30° | 球杆物理限制 | 球杆仰角上限 |
| `CueStickSettings.pullBackSpeed` | 0.5 m/s | 真实击球节奏 | 球杆回拉动画速度（匀速） |
| `CueStickSettings.pullBackMinDuration` | 0.15 s | 最低可感知时长 | 极低力度时的回拉最短动画 |
| `observationFallbackDelay` | 0.8 s | 延迟观察视角后备延迟 | 无碰撞时的视角切换时机 |
| `RenderQualityManager` 帧率阈值 | 低/中/高分级 | 动态质量适配 | 渲染性能与画质平衡 |
| `TableModelLoader` 缩放范围 | 0.0001-1000 | 模型加载验证 | 防止异常缩放导致物理错误 |
| `TableModelLoader` 表面高度范围 | -1 到 10 m | 模型加载验证 | 防止异常高度导致球位置错误 |
| `MaterialFactory.normalIntensityFeltFallback` | 0.055 | 程序化 felt 法线兜底强度 | USDZ 有法线贴图时不写此值 |
| `MaterialFactory.normalIntensityWoodFallback` | 0.35 | 程序化木纹法线兜底强度 | USDZ 有法线贴图时不写此值 |
| Key Light pitch | -68° | 模拟 1m 灯箱自然斜照角度 | 改变高光位置与阴影方向 |
| Key Light yaw | 18° | 避免对称死亮点 | 轻微偏移让高光更自然 |
| Key Light intensity | 820 lm | 配合三联灯箱 IBL 提升后补偿 Key 强度 | 过高会过曝，过低会暗 |
| Key Light shadowBias | 0.008 | 消除 Peter Panning（球漂浮阴影） | 过大导致漂浮，过小导致自阴影噪声 |
| Key Light shadowColor alpha | 0.30 | 稍强阴影更好锚定球到台面 | 改变球阴影深度感 |
| Fill Light intensity | 130 lm | 补亮袋口/木边暗部，防死黑 | 过高降低对比度，过低袋口仍死黑 |
| Fill Light pitch/yaw | -30°/-40° | 从左前方补光，与 Rim 方向相反 | 改变桌面暗部分布 |
| Rim Light intensity | 120 lm | 轮廓分离光（Fill 加入后减弱） | 过高会过曝边缘 |
| IBL 三联灯箱 lampColor | (0.86, 0.84, 0.80) | 暖白灯箱主体色 | 影响球体镜面反射色温 |
| IBL 三联灯箱 coreColor | (0.98, 0.96, 0.92) | 灯管热点色（比 lamp ×1.15） | 影响球体高光中心亮度 |
| IBL 灯箱 w/h/r | 0.72/0.10/0.05 (UV) | 胶囊形灯箱尺寸 | 影响球体反射光斑形状（条形） |
| IBL 灯箱 y-offsets | [-0.12, 0.0, +0.12] | 三条灯箱中心偏移 | 影响反射条纹间距 |
| IBL halo w/h scale | 1.10/1.80 | 灯罩散射扩展倍率 | 影响灯箱外晕宽度 |
| IBL halo intensity | 0.14 | 灯罩散射强度 | 过高洗平高光，过低无散射感 |
| IBL bounce rx/ry | 0.55/0.40 | 天花反弹光椭圆半径 | 影响顶面整体亮度分布 |
| IBL bounce intensity | 0.08 | 天花反弹光强度 | 过高产生新硬高光 |
| IBL feather | 0.015 (UV) | smoothstep 柔边宽度 | 影响灯箱边缘锐度 |
| IBL ceilingBase | (0.10, 0.11, 0.13) | 天花板基底色（冷灰蓝） | 影响非灯区暗部 |
| IBL wallTop | (0.20, 0.21, 0.24) | 真实球厅墙壁为浅色 | 影响球体侧面反射 |
| IBL wallBot | (0.10, 0.10, 0.12) | 墙脚较暗 | 影响桌面边缘反射 |
| IBL floor | (0.06, 0.07, 0.08) | 地面反弹光 | 影响球底部环境光 |
| IBL intensity (low/medium/high) | 0.95 / 1.60 / 1.80 | 三联灯箱升级后重新校准（medium+0.15, high+0.20） | 影响全局环境光强度 |
| SSAO radius (medium/high) | 0.06 | 收窄至接触阴影尺度，避免大范围压暗 | 过大导致台布整体偏暗 |
| SSAO intensity (medium/high) | 0.22 | 补偿半径减小后的视觉强度 | 过高导致台布死黑 |
| High tier shadowSampleCount | 32 | 高端设备软阴影更平滑 | 增加 GPU 负载 |
| High tier shadowRadius | 12 | 略软化高端阴影边缘 | 过大影响阴影清晰度 |
| Ball roughness | 0.06 | 真实酚醛树脂球（0.05-0.08 区间） | 过低（0.033）产生不真实镜面感 |
| Contact shadow baseAlpha | 0.62 | 保留中心压暗，但让小半径阴影仍保持渐变 | 过低会重新变得不明显 |
| Contact shadow exponent | 2.2 | 保持明显的径向渐变，避免小阴影盘边缘发硬 | 过低会显得发灰 |
| Contact shadow radius multiplier | 0.48 × Ball radius | 将接触阴影收进球底中心区域，并比 0.42 稍微放大一点 | 过大又会回到黑盘感 |
| Contact shadow Y offset | TablePhysics.height + 0.003 m | 明确抬到台泥视觉表面之上，避免被模型网格盖住 | 过高会显得悬浮 |
| Contact shadow renderingOrder | 20 | 让透明阴影盘在台泥之后稳定叠加 | 过高且深度策略错误会穿帮 |
| Contact shadow blendMode | multiply | 以“压暗台泥”而非“叠黑片”的方式显示接触阴影 | 若贴图过黑会像污渍 |
| Contact shadow material transparency | 0.52 | 让 multiply 强度退回辅助层级 | 过低会看不见阴影 |

## 状态机 / 事件模型

### GameState 状态机

```
idle --[setupTrainingScene]--> placing
placing --[球位置确认]--> aiming
aiming --[松手触发 executeStrokeFromSlider]--> aiming(isPreparingStroke=true, 球杆匀速回拉)
aiming(isPreparingStroke) --[回拉完成 performForwardStroke]--> ballsMoving
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
- **物理模拟异步化**：`executeStroke()` 中的 `engine.simulate()` 在后台线程 (`DispatchQueue.global(.userInitiated)`) 执行，避免主线程阻塞 20-80ms（满台开球场景）。模拟完成后通过 `DispatchQueue.main.async` 回到主线程设置回放和事件。击球后立即设置 `gameState = .ballsMoving` 阻止重复击球，`trajectoryPlayback == nil` 期间帧循环安全跳过回放。
- **FPS 采样隔离**：异步模拟完成后设置 `needsTimestampReset` 标志，Coordinator 在下帧重置 `lastTimestamp`，防止模拟耗时被计入 FPS 采样导致误判 Tier 降级。
- **FPS 采样数据结构**：`RenderQualityManager` 使用 `FrameTimeRingBuffer`（固定容量 60 的环形缓冲区），`append` 和 `clear` 均为 O(1)。
- **缓存策略**：
  - `visualCenter()` 结果可缓存（球节点位置不变时）
  - 轨迹预测节流：`lastTrajectoryPreviewTimestamp` 限制更新频率
  - 渲染质量分级：基于帧时长动态适配，避免持续高负载
  - IBL 立方体贴图：`EnvironmentLightingManager` 按 Tier 维度缓存 IBL + 背景贴图（`iblCache`/`backgroundCache` 字典），启动时 `prewarmAllTiers()` 在后台预生成所有 Tier 的贴图，确保 Tier 切换时 100% 命中缓存
  - 法线贴图：`MaterialFactory` 按尺寸缓存 felt/wood 法线贴图（`feltNormalMapCache`/`woodNormalMapCache`），避免 Tier 切换时重复生成
  - 材质批量提交：`reapplyMaterialsAndEnvironment()` 使用 `SCNTransaction` 批量提交材质变更
- **相机射线检测优化**：`applyCameraRaycastRadiusConstraint()` 仅在相机位置变化 > 0.01m 时执行 `hitTestWithSegment`，相机静止时跳过（缓存 `lastHitTestCameraPosition`）

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

### ADR-005：渲染质量恢复机制与级联降级防护

- **背景**：开球等高负载场景导致帧率骤降 → 渲染质量降级 → `reapplyRenderSettings()` 触发昂贵的 IBL 立方体贴图重生成 + 全场景材质遍历 → 更多帧丢失 → 再次降级。降至 low 后，升级阈值（avgFPS > 48）在轨迹回放期间难以达到，导致画质永远无法恢复。
- **候选方案**：
  1. 降低升级阈值（简单但可能导致画质频繁抖动）
  2. 缓存 IBL 贴图 + 延迟材质重刷 + 球停后主动恢复评估（三管齐下）
  3. 完全禁用自动降级（简单但失去自适应能力）
- **结论**：选择方案 2，包含三项子修复：
  - `EnvironmentLightingManager` 按 tier 缓存 IBL/背景贴图，避免重复像素级生成
  - `reapplyRenderSettings(deferMaterials:)` 在自动降级时将材质工作异步延迟，不阻塞当前帧
  - `RenderQualityManager.requestUpgradeEvaluation()` 在球停后启动恢复评估，使用降低的阈值（`upgradeThreshold - 6`）和缩短的采样窗口（30 帧），给设备恢复画质的机会
- **后果**：降级不再引发级联帧丢失；球停后 2 秒开始恢复评估，若 FPS 达标则自动升级一级（失败则保持当前档位）。

### ADR-006：帧循环性能优化（2026-03-04）

- **背景**：基于 `docs/real-time-mainloop-spec.md` 的深度分析，帧循环存在多个性能瓶颈：(1) `engine.simulate()` 在主线程同步执行导致开球帧 20-80ms jank；(2) Tier 切换时 IBL 缓存未命中 + 全场景材质遍历在主线程执行；(3) 相机防穿墙 hitTest 每帧无条件执行；(4) FPS 采样数组使用 O(n) `removeFirst`。
- **候选方案**：完整改造方案或逐步优化。
- **结论**：逐步优化，按优先级分 4 阶段：
  - **P0-1**：`executeStroke()` 中的 `engine.simulate()` 异步化至 `DispatchQueue.global(.userInitiated)`，主线程仅做状态切换和 UI 更新。结合 P1-1：异步完成后设置 `needsTimestampReset` 标志防止 FPS 采样污染。
  - **P0-2**：`EnvironmentLightingManager.prewarmAllTiers()` 启动时后台预热所有 Tier 的 IBL 贴图，缓存从单 tier 扩展为 `[RenderTier: [UIImage]]` 字典。
  - **P0-3**：`MaterialFactory` 缓存 felt/wood 法线贴图；`reapplyMaterialsAndEnvironment()` 使用 `SCNTransaction` 批量提交。
  - **P1-2**：`applyCameraRaycastRadiusConstraint()` 增加相机位置变化阈值检查，静止时跳过 hitTest。
  - **P2-2**：`RenderQualityManager.recentFrameTimes` 从 `[CFTimeInterval]` 替换为 `FrameTimeRingBuffer`（O(1) append）。
- **后果**：开球帧 jank 从 20-80ms 降至 <1ms（主线程）；Tier 切换帧峰从 5-40ms 降至 ~1-3ms；正常帧逻辑预算从 ~1-4ms 减少约 0.2-1ms（hitTest 节省）。

### ADR-007：两阶段出杆（匀速回拉 → 前冲）（2026-03-04）

- **背景**：原实现中力度滑条与球杆位置实时联动（`pullBack = currentPower/100 * maxPullBack`），松手即出杆。这不符合真实台球击球节奏（先确定力度、再拉杆、再出杆），且出杆动作过于突然。
- **候选方案**：
  1. 保持原联动行为（简单但不自然）
  2. 松手后球杆匀速回拉到目标位置，回拉完成后前冲出杆；同时利用回拉时间预计算物理模拟（自然且性能更优）
- **结论**：选择方案 2。
  - 瞄准阶段球杆保持静止（`pullBack = 0`），不跟随滑条
  - 松手后进入 `isPreparingStroke` 阶段，球杆以 `pullBackSpeed = 0.5 m/s` 匀速回拉
  - 回拉期间后台 `DispatchQueue.global(.userInitiated)` 并行执行物理模拟
  - 回拉完成后 `performForwardStroke()`：前冲动画 + 应用预计算结果
  - `isPreparingStroke` 期间禁止瞄准手势、力度条交互，渲染循环不覆盖球杆动画
- **后果**：击球体验更自然（100% 力度回拉 0.6s → 前冲 0.12s）；物理模拟在回拉期间完成（典型 20-80ms），用户无感知延迟。

### ADR-008：台球厅灯光优化（2026-03-06）

- **背景**：原三灯系统（Key pitch -82° + Rim + IBL）中主光过于垂直，导致球高光在顶部集中为一点、阴影直落正下方，与参考图差异明显；缺少 Fill Light 使袋口和木边出现死黑区域；IBL 天花板灯笼暗淡，球体反射无明显灯箱轮廓；SSAO radius 0.12 过大导致台布整体压暗而非点接触阴影。
- **候选方案**：
  1. 使用真实 HDR 台球厅环境贴图（视觉最好，但需外部资源）
  2. 调整现有程序化 IBL + 四灯参数（无需外部资源，运行时生成）
- **结论**：选择方案 2，无需外部资源依赖，参数可调。
  - Key Light 从 pitch -82°/yaw 0° 改为 pitch -68°/yaw 18°，更接近真实灯箱斜照
  - 新增 Fill Light（intensity 130, pitch -30°, yaw -40°），补亮桌面暗部与袋口
  - Rim Light 强度从 150 降至 120，平衡 Fill 加入后的整体亮度
  - shadowBias 从 0.02 降至 0.008，消除球漂浮的 Peter Panning 现象
  - IBL 天花板灯笼核心从 0.72 升至 0.92，灯笼范围从 rx 0.18/ry 0.12 扩大至 rx 0.22/ry 0.15
  - IBL 墙面亮度提升（top: 0.15→0.20），地面微增（0.045→0.06）
  - SSAO radius 从 0.12 收窄至 0.06，intensity 从 0.18 升至 0.22（接触阴影更精准）
  - High tier shadow samples 从 16 升至 32，radius 从 10 升至 12
  - 球材质 roughness 从 0.033 调至 0.06（符合真实酚醛树脂球物理范围）
- **后果**：视觉效果更接近真实球厅，Ball 高光从顶部点变为侧面扩散区；Fill Light 消除死黑角；球影触地更真实；IBL 可在球面看到灯箱轮廓反射。不增加 shadow caster（Fill/Rim 无投影），性能影响极小。

### ADR-009：IBL 三联灯箱升级（2026-03-06）

- **背景**：ADR-008 将 IBL 天花板从暗淡小灯笼改为更亮的椭圆灯盘，但仍使用硬边 `d²<1` 切断，导致球面高光偏圆偏"贴图感"；缺少灯罩散射（softbox diffusion）和天花反弹光（ceiling bounce），与真实球厅三联长条灯箱差异明显。
- **候选方案**：
  1. 引入真实 HDR 环境贴图替代程序化 IBL（视觉最佳，但需外部资源且不可调参）
  2. 升级程序化 IBL 顶面为三联胶囊灯箱 + 灯罩散射 + 天花反弹光（无外部依赖，参数可调）
- **结论**：选择方案 2，仅修改 `EnvironmentLightingManager.renderIBLCeiling()`，不改变灯光/材质/背景/分辨率/缓存逻辑。
  - 顶面从单一硬边椭圆改为 4 层叠加：ceilingBase → bounce → halo×3 → lamp+core×3
  - 三条胶囊灯箱（w=0.72, h=0.10, r=h×0.5）中心 y 偏移 [-0.12, 0.0, +0.12]
  - 每条灯箱内嵌 core 热线（h=0.035, color=(0.98,0.96,0.92)）模拟灯管高光
  - 每条灯箱外扩 halo（w×1.10, h×1.80, intensity=0.14）模拟灯罩散射
  - 全面使用 `roundedRectSDF` + `smoothstep(feather=0.015)` 柔边，杜绝硬切
  - 天花反弹光（bounce rx=0.55, ry=0.40, intensity=0.08）大范围低频暖提升
  - 新增 `DebugIBLMode`（.normal/.showTopFaceOnly/.exaggerated）便于验证
- **后果**：球面高光从圆点变为明显的三条长条灯箱反射；木边清漆反射更自然（无硬边裁切）；IBL 顶面平均亮度提升约 10-15%；运行时开销不变（仍为初始化/切档时一次生成）。
