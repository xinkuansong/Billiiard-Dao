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
| 异步物理模拟线程安全 | 中 | 验证 executeStroke 快速连续调用不会导致竞态（gameState guard 已阻止，但需验证边界） |
| IBL prewarm 与首帧竞争 | 低 | 验证 prewarm 未完成时首次 Tier 切换的表现（应 fallback 到同步生成） |
| hitTest 缓存失效覆盖度 | 低 | 验证相机模式切换后 invalidateHitTestCache 是否覆盖所有路径 |

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
| 2026-03-04 | 帧循环性能优化（基于 real-time-mainloop-spec.md）：(P0-1) engine.simulate() 异步化至后台线程 + FPS 采样隔离；(P0-2) IBL prewarm 启动时后台预热所有 Tier；(P0-3a) MaterialFactory 缓存 felt/wood 法线贴图；(P0-3b) reapplyMaterialsAndEnvironment 使用 SCNTransaction 批量提交；(P1-2) applyCameraRaycastRadiusConstraint 增加位置变化阈值跳过；(P2-2) FPS 采样替换为 FrameTimeRingBuffer | 编译通过；影响面：BilliardSceneView（executeStroke 异步化、renderUpdate needsTimestampReset）、EnvironmentLightingManager（prewarm + per-tier 字典缓存）、MaterialFactory（法线贴图缓存）、BilliardScene（SCNTransaction + hitTest 缓存 + invalidateHitTestCache）、RenderQualityManager（FrameTimeRingBuffer） | 待真机验证：(1) 开球帧无卡顿（异步模拟生效）；(2) Tier 切换无帧峰（IBL prewarm 命中缓存）；(3) 正常帧率稳定（hitTest 优化生效）；(4) 连续击球不竞态 |
| 2026-03-04 | 两阶段出杆：力度条松手后球杆匀速回拉→前冲出杆；回拉期间后台预计算物理模拟 | 编译通过、无 lint 错误；影响面：BilliardSceneView（executeStrokeFromSlider 重构为两阶段、新增 isPreparingStroke/pendingSimulationResult/performForwardStroke/applySimulationResult、renderUpdate 中 pullBack 改为 0）、CueStick（animatePullBack 增加 elevation/duration/completion 参数）、PhysicsConstants（新增 pullBackSpeed/pullBackMinDuration）、FreePlayView + TrainingSceneView（PowerGaugeView enabled 增加 !isPreparingStroke 条件） | 待真机验证：(1) 松手后球杆匀速回拉再出杆；(2) 不同力度下回拉时长符合预期（100%→0.6s, 50%→0.3s）；(3) 回拉期间滑条禁用、瞄准手势禁止；(4) 出杆后球运动正常、回放同步 |
| 2026-03-05 | MaterialFactory 材质识别与 USDZ 纹理保留修复：(1) 封装 `hasTextureContents(_:)` 方法，精确区分 CGImage/UIImage/URL（有纹理）与 UIColor/Float/nil（无纹理）；(2) `normalizeIdentifier(_:)` 归一化函数统一去除下划线/连字符/空格后再做关键词匹配，修复 `TaiNi`/`tai_ni` 匹配失败问题，`isClothMaterial`/`isRailMaterial`/`isPocketMaterial` 同步采用；(3) `enhanceClothMaterials`：roughness/metalness/normal 通道改为"USDZ 已有纹理则保留，无纹理才写标量/程序化"策略，保留 `TaiNi_roughness.png`/`TaiNi_normal.png` 等 USDZ 内置 PBR 贴图；(4) `enhanceRailMaterials` 同策略修复；(5) 抽取 4 个 normal intensity 常量 | 代码级检查通过，无 lint 错误；改动面仅限 `MaterialFactory.swift` 内部实现，public API 不变 | 待真机/模拟器验证：(1) 台泥(TaiNi)材质正确识别并保留 USDZ roughness/normal 贴图；(2) 木边(Wood/BlackWood)材质识别正确；(3) 非绿色台泥（如红台）时仍可通过名称识别；(4) 台球材质（Lime__q6038_N_001）不误触 cloth/rail/pocket 增强 |
|| 2026-03-06 | IBL intensity 按 Tier 差异化：`EnvironmentLightingManager.apply()` 新增 `iblIntensity(for:)` 私有方法，low=0.88（不变）/ medium=1.35 / high=1.6；HDRI 与程序化 cube map 路径统一使用该方法，不再硬编码 0.88 | 代码级检查通过，无 lint 错误 | 待真机验证：Medium/High 设备下球体与台面反射亮度提升，low 设备不变 |
| 2026-03-06 | 台球厅灯光优化（ADR-008）：(1) Key Light pitch -82°→-68°, yaw 0°→18°, intensity 750→700, shadowBias 0.02→0.008, shadowAlpha 0.22→0.30, 从 UIColor 改为 temperature=5800；(2) 新增 Fill Light (intensity 130, temp 6800, pitch -30°, yaw -40°, no shadow)；(3) Rim Light intensity 150→120；(4) IBL ceiling lamp core (0.72,0.70,0.68)→(0.92,0.90,0.86), lamp (0.60,0.58,0.55)→(0.78,0.76,0.72), rx 0.18→0.22, ry 0.12→0.15；(5) IBL wallTop (0.15,0.16,0.18)→(0.20,0.21,0.24), wallBot (0.07,0.07,0.08)→(0.10,0.10,0.12), floor (0.045,0.052,0.06)→(0.06,0.07,0.08)；(6) IBL intensity low 0.88→0.95, medium 1.35→1.50, high 不变；(7) SSAO radius 0.12→0.06, intensity 0.18→0.22；(8) High tier shadowSampleCount 16→32, shadowRadius 10→12；(9) Ball roughness 0.033→0.06 | 编译通过，无 lint 错误；影响面：BilliardScene.swift（setupLights 四灯结构）、EnvironmentLightingManager.swift（IBL lamp/wall/floor/intensity）、RenderQualityManager.swift（SSAO/shadow high tier flags）、MaterialFactory.swift（ball roughness） | 待真机验证：(1) 球高光从顶部点变为侧面扩散区；(2) 球阴影触地不漂浮（Peter Panning 消除）；(3) 袋口/木边暗部不再死黑；(4) 台布接触阴影更精准（SSAO radius 减小）；(5) 帧率无回归（Fill/Rim 无投影） |
| 2026-03-06 | IBL 三联灯箱升级（ADR-009）：`renderIBLCeiling` 从单一硬边椭圆改为 4 层叠加三联胶囊灯箱；(1) ceilingBase=(0.10,0.11,0.13) 冷灰蓝天花板底色；(2) ceiling bounce (rx=0.55, ry=0.40, intensity=0.08) 大范围低频暖光；(3) 每条灯箱外扩 halo (w×1.10, h×1.80, intensity=0.14, feather=0.04)；(4) 三条胶囊灯箱 (w=0.72, h=0.10, r=0.05) 中心 y 偏移 [-0.12, 0.0, +0.12]，lampColor=(0.86,0.84,0.80)；(5) 内嵌 core 热线 (h=0.035, coreColor=(0.98,0.96,0.92))；(6) 全面使用 roundedRectSDF + smoothstep(feather=0.015) 柔边；(7) 新增 DebugIBLMode (.normal/.showTopFaceOnly/.exaggerated)；(8) wall/floor 值不变 | 编译通过（xcodebuild BUILD SUCCEEDED），无 lint 错误；影响面仅 `EnvironmentLightingManager.swift`（renderIBLCeiling 重写 + 新增 smoothstep/roundedRectSDF/DebugIBLMode + generateIBLCubeMap debug 分支）；IBL intensity、背景 cube map、灯光、材质、缓存逻辑均未改动 | 待真机验证：(1) 白球/彩球高光从圆点变为明显的 3 条长条灯箱反射；(2) 木边清漆反射无硬边裁切；(3) 台布亮度有"球厅顶灯照明"感但阴影仍清晰；(4) 将 debugIBLMode 切为 .exaggerated 验证灯箱强度×1.5 效果；(5) 将 debugIBLMode 切为 .showTopFaceOnly 验证仅顶面贡献的反射条纹形状；(6) 帧率无回归（IBL 仍为初始化一次生成） |
| 2026-03-06 | IBL + Key Light 亮度调档：IBL medium 1.45→1.60, high 1.60→1.80；Key Light intensity 700→820 lm | 编译通过；影响面：`EnvironmentLightingManager.swift`（iblIntensity medium/high）、`BilliardScene.swift`（keyLight.intensity） | 待真机验证：(1) Medium/High 设备下球体与台面环境反射更亮；(2) Key Light 调强后阴影对比度与高光亮度协调，无过曝 |
| 2026-03-06 | 强化球与台泥接触阴影：先将 `generateContactShadowTexture()` 的 `baseAlpha` 0.74→0.86、`exponent` 3.0→4.0，并将 `attachShadow()` 的阴影半径系数 2.2→1.8、阴影平面高度 `TablePhysics.height + 0.002`→`+ 0.001`；在首轮视觉变化不足后，进一步调到 `baseAlpha` 1.0、`exponent` 5.2、半径系数 1.45、高度 `+ 0.0006`；在用户反馈“球自己下半部暗，但台泥上没影子”后，确认根因包含：(1) 多处逻辑仍把阴影位置重置回 `+ 0.002`；(2) 阴影盘作为透明平面可能被台泥视觉网格盖住。随后统一 `contactShadowYOffset = 0.003`、改为 `blendMode = .multiply`、`renderingOrder = 20`，所有阴影位置更新路径统一使用同一常量。用户进一步反馈“阴影太夸张”后，先回调到更真实的参数：`baseAlpha` 1.0→0.72、`exponent` 5.2→3.6、半径系数 1.9→2.05、`material.transparency` 1.0→0.68；随后根据“半径应缩小到不到球半径一半且必须渐变”的要求，再调整为 `baseAlpha` 0.62、`exponent` 2.2、半径系数 0.42、`material.transparency` 0.52；最后根据“稍微大一点点”的反馈，将半径系数从 `0.42` 微调到 `0.48`，其余参数保持不变 | 代码级检查通过、无 lint 错误；影响面：`BilliardScene.swift`（每球阴影盘尺寸） | 待真机/模拟器验证：(1) 台泥接触阴影比 0.42 版略大，但仍显著小于早期黑盘；(2) 渐变边缘保持自然；(3) 快速移动/入袋前后阴影跟随正常；(4) 无 Z-fighting、无遮挡穿帮 |
