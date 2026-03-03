# 实时主循环设计规范文档

> BilliardTrainer · 渲染帧循环深度分析与优化规范
> 生成日期：2026-03-03
> 基于源码版本：当前 main 分支

---

## 目录

1. [帧循环总体架构](#1-帧循环总体架构)
2. [当前帧循环完整执行顺序](#2-当前帧循环完整执行顺序)
3. [各阶段职责与性能风险](#3-各阶段职责与性能风险)
4. [主线程预算分析](#4-主线程预算分析)
5. [重资产重建操作清单](#5-重资产重建操作清单)
6. [开球（executeStroke）执行路径分析](#6-开球executestroke执行路径分析)
7. [级联行为风险分析](#7-级联行为风险分析)
8. [当前循环 vs 推荐循环对比流程图](#8-当前循环-vs-推荐循环对比流程图)
9. [帧循环行为规范](#9-帧循环行为规范)
10. [改造优先级列表](#10-改造优先级列表)

---

## 1. 帧循环总体架构

### 1.1 驱动机制

```
驱动源: CADisplayLink（主线程 RunLoop .common mode）
回调:   Coordinator.renderUpdate()
位置:   BilliardSceneView.swift:168
```

**设计决策说明**：项目**刻意不使用** `SCNSceneRendererDelegate`（`renderer(_:updateAtTime:)`），而是采用独立的 `CADisplayLink`。这将游戏逻辑帧与 SceneKit 渲染帧**解耦**——逻辑可以在 SceneKit 内部渲染管线之前运行，避免在渲染提交窗口内执行游戏逻辑。

### 1.2 帧循环生命周期

```
makeUIView（SwiftUI 挂载）
    └─► coordinator.startRenderLoop(for: scnView)
            ├─► applyRenderQualityIfNeeded(force: true)   // 强制应用初始 Tier
            └─► CADisplayLink → RunLoop.main (.common)    // 挂入主线程

每帧 CADisplayLink 回调
    └─► Coordinator.renderUpdate()                        // 帧逻辑总调度器

dismantleUIView（SwiftUI 卸载）
    └─► coordinator.stopRenderLoop()
            └─► displayLink.invalidate()                  // 断开循环引用
```

### 1.3 物理引擎架构

物理引擎采用**离线事件驱动**模式，与帧循环**完全解耦**：

- **离线阶段**（击球时）：`EventDrivenEngine.simulate()` 在主线程同步运行，一次性完整模拟整个球局演化
- **回放阶段**（每帧）：`TrajectoryPlayback.stateAt()` 通过事件快照 + 解析演进，对任意时刻精确插值

---

## 2. 当前帧循环完整执行顺序

以下为 `renderUpdate()` 函数的**真实调用顺序**（`BilliardSceneView.swift:168-264`）：

```
┌─────────────────────────────────────────────────────────────────────┐
│  CADisplayLink.timestamp 触发                                        │
│                                                                     │
│  Step 0:  viewModel.syncRenderQualityState()                        │
│           └─ 同步质量状态标志位（ViewModel → RenderQualityManager）  │
│                                                                     │
│  Step 1:  viewModel.updateTrajectoryPlaybackFrame(timestamp: now)   │
│           ├─ TrajectoryPlayback.stateAt(ballName, time)             │
│           │    └─ AnalyticalMotion.evolveSliding/Rolling/Spinning   │
│           ├─ 更新各球节点 position / rotation                        │
│           ├─ 进袋球淡出 opacity                                      │
│           └─ 检测回放完成 → onBallsAtRest()                         │
│                                                                     │
│  Step 2:  viewModel.scene.updateShadowPositions()                   │
│           └─ 遍历 shadowNodes 更新接触阴影跟随球位置                  │
│                                                                     │
│  Step 3:  deltaTime 计算 + clamp [1/240, 1/20]                      │
│           └─ RenderQualityManager.recordFrameTime(dt)               │
│                └─ 60帧滑动窗口采样 → 触发 Tier 降级/升级判断         │
│                                                                     │
│  Step 4:  RenderQualityManager.evaluateRecoveryFrame(dt)            │
│           └─ 单帧 ≥ 100ms → 立即触发 applyRenderQualityIfNeeded     │
│                                                                     │
│  Step 5:  applyRenderQualityIfNeeded()                              │
│           ├─ [Tier 未变化] 提前返回（无开销）                         │
│           └─ [Tier 变化]                                            │
│                ├─ SCNView.antialiasingMode = ...                    │
│                ├─ SCNView.preferredFramesPerSecond = ...            │
│                └─ BilliardScene.reapplyRenderSettings(deferMaterials:) │
│                        ├─ reapplyLightSettings()                    │
│                        ├─ reaplyCameraSettings()                    │
│                        └─ [auto] DispatchQueue.main.async:          │
│                               reapplyMaterialsAndEnvironment()      │
│                               ├─ EnvironmentLightingManager.apply() │
│                               ├─ MaterialFactory.enhanceCloth()     │
│                               ├─ MaterialFactory.enhanceRail()      │
│                               └─ MaterialFactory.enhancePocket()    │
│                                                                     │
│  Step 6:  分支：相机模式判断                                          │
│           ├─ [TopDown2D]     updateTopDownZoom()                    │
│           ├─ [GlobalObserve] cameraRig.update(deltaTime)            │
│           └─ [Aim/Observe]                                          │
│                ├─ setAimDirectionForCamera(aimDirection)             │
│                ├─ updateCameraRig(deltaTime, cueBallPosition)        │
│                │    ├─ ObservationController.updateObservation()     │
│                │    ├─ clampPivotToTable()                          │
│                │    ├─ CameraRig.update(deltaTime)                  │
│                │    │    ├─ [SmoothTransition] smootherstep插值      │
│                │    │    ├─ [SmoothPose阻尼] 弹簧追踪               │
│                │    │    └─ [标准Orbit] 阻尼lerp                    │
│                │    │         └─ applyCameraTransform()             │
│                │    │              (写入 cameraNode.position/       │
│                │    │               eulerAngles/fieldOfView)        │
│                │    └─ applyCameraRaycastRadiusConstraint()          │
│                │         └─ SCNView.hitTest() 防穿墙射线检测         │
│                └─ lockCueBallScreenAnchor(in:view:)                 │
│                     └─ SCNView.projectPoint() 投影误差修正           │
│                                                                     │
│  Step 7:  viewModel.pitchAngle = cameraNode.eulerAngles.x           │
│           （写入 @Published → SwiftUI 可响应）                        │
│                                                                     │
│  ── guard cueBallNode != nil else return ─────────────────────────  │
│                                                                     │
│  Step 8:  [aiming && !topDown] CueStick.update(...)                 │
│           ├─ calculateRequiredElevation()（遍历目标球位置）           │
│           └─ 更新球杆节点 position / eulerAngles                     │
│                                                                     │
│  Step 9:  [aiming && !topDown] 瞄准线更新（节流 45Hz）               │
│           ├─ calculateAimLineLength()（射线碰桌壁检测）               │
│           └─ showAimLine()                                          │
│                                                                     │
│  Step 10: [aiming && !topDown] 轨迹预测更新（节流 30Hz）             │
│           └─ updateTrajectoryPreview(minInterval: 1/30)             │
│                                                                     │
│  ▲  帧逻辑结束，SCNView 开始 Metal 渲染提交（SceneKit 内部）          │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 3. 各阶段职责与性能风险

### Step 0 · syncRenderQualityState

| 项目 | 内容 |
|------|------|
| **职责** | 将 RenderQualityManager 的 Tier 状态同步到 ViewModel，供 SwiftUI 视图层读取 |
| **耗时估算** | < 0.01ms（纯属性读取） |
| **性能风险** | 若触发 `@Published` 写入，会导致 SwiftUI 重新 diff，**需确认是否每帧写入** |
| **风险等级** | 🟡 低风险（待确认是否有无效写入） |

### Step 1 · 轨迹回放（updateTrajectoryPlaybackFrame）

| 项目 | 内容 |
|------|------|
| **职责** | 将预计算物理轨迹按当前时间戳插值到每个球节点的 `position` / `rotation` |
| **耗时估算** | ~0.1–0.5ms（取决于球数，通常 16 球） |
| **计算内容** | 每球：二分查找最近事件帧 → AnalyticalMotion 解析演进（纯数学，无分支） |
| **性能风险** | 插值本身是 O(n·log m)，n=球数、m=事件数。散球（break shot）事件数可达 200+，首帧插值稍重 |
| **附加开销** | 进袋球检测 `opacity ≤ 0` → `removeFromParentNode()`（触发 SceneKit 场景图修改） |
| **风险等级** | 🟢 正常风险 |

### Step 2 · 接触阴影更新（updateShadowPositions）

| 项目 | 内容 |
|------|------|
| **职责** | 遍历所有球的阴影节点，将其 Y 坐标钳制到桌面，跟随球位移 |
| **耗时估算** | < 0.1ms |
| **性能风险** | 若阴影节点数量远大于球数（调试模式），遍历成本线性增加 |
| **风险等级** | 🟢 低风险 |

### Step 3 · deltaTime 计算与帧率采样（recordFrameTime）

| 项目 | 内容 |
|------|------|
| **职责** | 计算帧间隔、钳制到合理范围（4.2ms–50ms），将帧耗时写入 60 帧滑动窗口 |
| **采样逻辑** | 积满 60 帧后计算平均 FPS，与降级/升级阈值对比；满足 2 个连续窗口才触发 Tier 变化 |
| **耗时估算** | < 0.05ms（数组追加 + reduce） |
| **⚠️ 隐患** | `recentFrameTimes.removeFirst()` 在 Swift 数组中是 O(n) 操作（每帧一次），建议改为环形缓冲区 |
| **风险等级** | 🟡 中风险（数组操作） |

### Step 4 · 瞬时恢复检测（evaluateRecoveryFrame）

| 项目 | 内容 |
|------|------|
| **职责** | 检测单帧耗时 ≥ 100ms（卡顿峰值），立即触发质量恢复评估 |
| **耗时估算** | < 0.01ms |
| **性能风险** | 若触发 `applyRenderQualityIfNeeded(force:true)`，当帧产生额外开销（见 Step 5） |
| **风险等级** | 🟢 低风险（本身轻量） |

### Step 5 · 自适应画质应用（applyRenderQualityIfNeeded）

| 项目 | 内容 |
|------|------|
| **职责** | Tier 变化时，更新 SCNView 参数并触发材质/光照重建 |
| **正常路径** | Tier 未变化 → 提前 return，开销为零 |
| **降级路径** | 写入 `antialiasingMode`、`preferredFramesPerSecond` + 调用 `reapplyRenderSettings` |
| **deferMaterials 机制** | 自动降级时设置 `deferMaterials: true`，材质重建推迟到 `DispatchQueue.main.async` |
| **⚠️ 问题** | `DispatchQueue.main.async` 并不是后台线程，只是推迟到**下一个 RunLoop 迭代**，仍在主线程执行材质重建（见 §5、§7） |
| **风险等级** | 🔴 高风险（Tier 变化时） |

### Step 6 · 相机更新（updateCameraRig / CameraRig.update）

| 项目 | 内容 |
|------|------|
| **职责** | 根据相机状态机状态（aiming/observing/returnToAim）进行相机 orbit 插值 |
| **分支 A** | SmoothTransition：smootherstep + 线性插值所有 pose 分量（yaw/pitch/radius/pivot/fov） |
| **分支 B** | SmoothPose 阻尼：弹簧追踪（damping lerp），每帧写入 5 个 cameraNode 属性 |
| **分支 C** | 标准 Orbit：独立 yaw/zoom/pivot 阻尼追踪 |
| **⚠️ hitTest 开销** | `applyCameraRaycastRadiusConstraint()` 每帧调用 `SCNView.hitTest()`，这是一次 CPU 射线检测 |
| **⚠️ projectPoint 开销** | `lockCueBallScreenAnchor()` 调用 `SCNView.projectPoint()`，读取 MVP 矩阵进行投影 |
| **风险等级** | 🟡 中风险（hitTest 每帧调用） |

### Step 7 · pitchAngle 写入

| 项目 | 内容 |
|------|------|
| **职责** | 将相机俯仰角同步到 ViewModel 的 `@Published var pitchAngle`，供 SwiftUI UI 读取 |
| **⚠️ 问题** | `@Published` 写入会在主线程触发 `objectWillChange.send()`，**每帧必然触发 SwiftUI diff**，若 SwiftUI 视图依赖此值且 body 计算量大，会造成每帧额外 UI 树 diff 开销 |
| **风险等级** | 🟡 中风险 |

### Step 8 · 球杆姿态更新（CueStick.update）

| 项目 | 内容 |
|------|------|
| **职责** | 根据白球位置、瞄准方向、力度拉杆、仰角更新球杆节点的 position/eulerAngles |
| **附加计算** | `calculateRequiredElevation()` 遍历目标球位置计算最低安全仰角（防止球杆穿球） |
| **状态门控** | 仅在 `gameState == .aiming && !topDown` 时执行 |
| **风险等级** | 🟢 低风险 |

### Step 9 · 瞄准线更新（45Hz 节流）

| 项目 | 内容 |
|------|------|
| **职责** | 更新瞄准线几何体的长度与方向 |
| **节流** | `now - lastAimLineUpdateTimestamp >= 1/45`，跳帧率约 25% @60fps |
| **⚠️ 问题** | `calculateAimLineLength()` 内部可能进行场景射线检测（需确认实现） |
| **风险等级** | 🟢 低风险（有节流保护） |

### Step 10 · 轨迹预测更新（30Hz 节流）

| 项目 | 内容 |
|------|------|
| **职责** | 实时计算并渲染白球碰撞预测轨迹（鬼球 + 反弹路径） |
| **节流** | `minInterval: 1/30`，@60fps 跳帧率 50% |
| **⚠️ 重要风险** | `updateTrajectoryPreview()` 内部很可能每次调用一个**轻量物理模拟**来预测轨迹。如果此模拟不受 maxEvents 严格限制，或在复杂布局下运行时间长，**30Hz 频率下仍可能积累主线程压力** |
| **风险等级** | 🟡 中风险（取决于预测模拟深度） |

---

## 4. 主线程预算分析

### 4.1 帧预算基准

| 目标帧率 | 总帧预算 | 逻辑预算（建议 ≤ 30%） | 渲染预算（Metal GPU） |
|---------|---------|----------------------|----------------------|
| 60 FPS  | 16.67ms | ≤ 5ms                | ~11ms                |
| 120 FPS | 8.33ms  | ≤ 2.5ms              | ~5ms                 |

### 4.2 各阶段主线程占用

| 阶段 | 运行线程 | 估算耗时（正常帧） | 估算耗时（异常帧） |
|------|---------|----------------|----------------|
| syncRenderQualityState | 主线程 | <0.01ms | <0.01ms |
| updateTrajectoryPlaybackFrame | 主线程 | 0.1–0.5ms | 0.5–1ms（高事件密度） |
| updateShadowPositions | 主线程 | <0.1ms | <0.1ms |
| recordFrameTime | 主线程 | <0.05ms | <0.05ms |
| applyRenderQualityIfNeeded（正常） | 主线程 | <0.01ms | — |
| applyRenderQualityIfNeeded（Tier变化） | 主线程 | 0.5–2ms | 2–5ms |
| reapplyMaterialsAndEnvironment（async） | 主线程（下帧） | — | **5–30ms**（批量遍历） |
| updateCameraRig + hitTest | 主线程 | 0.2–1ms | 1–3ms（复杂场景hitTest） |
| lockCueBallScreenAnchor | 主线程 | <0.1ms | <0.1ms |
| CueStick.update | 主线程 | <0.1ms | <0.1ms |
| 瞄准线更新（45Hz触发时） | 主线程 | <0.2ms | <0.2ms |
| 轨迹预测（30Hz触发时） | 主线程 | 0.5–2ms | 2–10ms（高密度布局） |
| **合计（正常帧）** | | **~1–4ms** | — |
| **合计（Tier变化帧）** | | — | **10–50ms（严重超预算）** |

### 4.3 哪些操作在主线程运行

**全部逻辑均运行在主线程**，包括：

- ✅ 所有帧循环逻辑（CADisplayLink 绑定在 `RunLoop.main`）
- ✅ 轨迹回放（AnalyticalMotion 解析演进）
- ✅ 相机插值计算
- ✅ SceneKit hitTest（防穿墙射线）
- ✅ 材质遍历重建（`DispatchQueue.main.async` 仍是主线程）
- ✅ IBL Cube Map 生成（像素渲染）
- ✅ `EventDrivenEngine.simulate()`（击球时）
- ✅ SwiftUI 状态更新（`@Published` 触发）

**目前没有任何游戏逻辑被移至后台线程执行。**

---

## 5. 重资产重建操作清单

以下操作均属于"重资产重建"，**代价极高**，一旦在帧循环中触发，必然造成帧刺峰：

### 5.1 IBL Cube Map 生成

```swift
// EnvironmentLightingManager.swift
static func generateIBLCubeMap(size: Int, brightness: Float) -> [UIImage]
```

- **内容**：程序化像素渲染 6 张 `UIImage`（含天花板椭圆热点渐变）
- **尺寸**：low=128×128，medium=256×256，high=512×512
- **估算耗时**：128: ~2ms，256: ~8ms，512: ~30ms
- **触发时机**：`reapplyMaterialsAndEnvironment()` → `setupEnvironment()`
- **缓存情况**：有 `cachedIBL(for:tier:size:)` 缓存，**相同 Tier + 尺寸命中缓存则跳过**
- **风险**：Tier 变化时若缓存未命中，在主线程同步生成，**直接造成 30-50ms 帧峰**

### 5.2 批量材质遍历（全场景节点）

```swift
// MaterialFactory.swift
private static func enumerateMaterials(in node: SCNNode, handler: (SCNMaterial, String?) -> Void)
```

- **内容**：递归遍历 `tableNode` 所有子节点的所有 `SCNMaterial`，逐一重设参数
- **调用链**：`enhanceClothMaterials` + `enhanceRailMaterials` + `enhancePocketMaterials`
- **估算耗时**：~3–10ms（取决于场景复杂度）
- **触发时机**：每次 Tier 变化的 `reapplyMaterialsAndEnvironment()`

### 5.3 球体材质重建（enhanceBallMaterials）

```swift
// BilliardScene.swift
func enhanceBallMaterials()
```

- **内容**：遍历所有 16 球节点，更新 clearcoat / roughness / metalness 等 PBR 参数
- **估算耗时**：~0.5–2ms

### 5.4 光照参数重建（reapplyLightSettings）

- **内容**：重设阴影贴图尺寸（shadowMapSize: 2048/4096）、采样数、半径
- **注意**：`shadowMapSize` 变化会触发 SceneKit 内部贴图重分配，**可能在 GPU 端引发内存搬运**

### 5.5 轨迹预测模拟（updateTrajectoryPreview）

- **内容**：每次调用运行一次简化的物理模拟来预测白球路径
- **频率**：30Hz（@60fps 每帧触发 50%）
- **风险**：若预测深度（事件数/时间）没有严格上限，在散球布局下可能积累

---

## 6. 开球（executeStroke）执行路径分析

### 6.1 完整调用链

```
用户触发击球（手势/UI）
    │
    ▼
executeStroke(power: Float)                    [主线程，同步]
    │
    ├─ 1. StrokePhysics.velocity(forPower:)    [<0.01ms]
    ├─ 2. computeCueStrike(velocity:power:)    [<0.1ms，计算旋转参数]
    ├─ 3. cueStick?.animateStroke()            [异步 SCNAction，非阻塞]
    ├─ 4. EventDrivenEngine 初始化             [<0.1ms]
    ├─ 5. 设置所有球初始状态（16球遍历）        [<0.1ms]
    │
    ├─ 6. ⚠️ engine.simulate(maxEvents: 500, maxTime: 15.0)   [主线程，同步阻塞！]
    │         ├─ separateOverlappingBalls()
    │         ├─ while loop（最多 500 次事件）：
    │         │    ├─ findNextEvent()          [优先队列或遍历所有球对]
    │         │    ├─ evolveAllBalls(dt)       [AnalyticalMotion × 16球]
    │         │    ├─ separateOverlappingBalls()
    │         │    ├─ resolveEvent()           [碰撞/库边/运动状态转换]
    │         │    ├─ invalidateCache()
    │         │    └─ recordSnapshot()         [写入 TrajectoryRecorder]
    │         └─ 保守估算：简单开局 ~1–5ms，满台散球 ~10–50ms
    │
    ├─ 7. extractGameEvents(from: engine)      [规则判定]
    ├─ 8. engine.getTrajectoryRecorder()       [数据引用转移]
    ├─ 9. 相机状态机事件：.shotFired
    └─ 10. startTrajectoryPlayback(recorder)   [创建 TrajectoryPlayback，后续帧驱动]
```

### 6.2 爆发式计算风险评估

| 场景 | 事件数估算 | 主线程阻塞时长 | 是否超预算 |
|------|-----------|-------------|-----------|
| 简单推杆（1球碰撞） | ~10–30 事件 | ~1–5ms | 🟢 正常 |
| 标准比赛击球 | ~50–150 事件 | ~5–15ms | 🟡 边界 |
| **满台开球（Break Shot）** | **~300–500 事件** | **~20–80ms** | **🔴 严重超预算** |
| 极端情况（连串碰撞） | 接近 500 上限 | **可能 >100ms** | **🔴 致命** |

**结论**：`engine.simulate()` 在开球瞬间**同步阻塞主线程**，是当前架构最严重的单点性能风险。开球帧可能出现 20–80ms 的 jank 峰。

---

## 7. 级联行为风险分析

### 7.1 已知级联路径：质量降级引发材质重建再触发掉帧

```
正常帧 [~3ms]
    │
    ▼（某帧压力增大，如轨迹预测超时）
帧耗时 >16.67ms → FPS 掉至 <50
    │
    ▼（连续 2×60帧窗口 = 120帧 ≈ 2秒）
RenderQualityManager 触发降级：High → Medium
    │
    ▼ 同帧执行：
applyRenderQualityIfNeeded()
    ├─ SCNView.antialiasingMode = .multisampling2X  [即时生效，影响当前帧]
    └─ reapplyRenderSettings(deferMaterials: true)
            ├─ reapplyLightSettings()              [同帧，可能 1–2ms]
            └─ DispatchQueue.main.async:           ← ⚠️ 推迟到下一帧，但仍在主线程
                    reapplyMaterialsAndEnvironment()
                    ├─ EnvironmentLightingManager.apply()  [若缓存命中 <1ms; 未命中 ~30ms]
                    ├─ enhanceBallMaterials()               [~1–2ms]
                    ├─ enhanceClothMaterials()              [~2–5ms]
                    ├─ enhanceRailMaterials()               [~1–3ms]
                    └─ enhancePocketMaterials()             [~0.5–1ms]
                    合计: ~5–40ms（IBL缓存命中与否差距巨大）
    │
    ▼（下一帧：材质重建导致该帧 >16.67ms）
再次触发 evaluateRecoveryFrame()
    │
    ▼（但有 6秒冷却期保护）
✅ 冷却期内不会再次降级（防抖）
```

**结论**：当前设计有 **6秒冷却期**（`tierChangeCooldown = 6.0`）和 **2窗口确认机制**（`requiredWindowsForTierChange = 2`），**已防止快速振荡**。但材质重建的那一帧仍会造成一次明显 jank，且如果 IBL 缓存未命中，该 jank 可能达到 30–40ms。

### 7.2 潜在级联路径：开球 + 质量状态混乱

```
开球帧（executeStroke）
    ├─ engine.simulate() 阻塞 ~30ms
    └─ 该帧 deltaTime = 30ms（被 clamp 到 max 1/20 = 50ms）
            │
            ▼
recordFrameTime(50ms)  ← clamp 后写入 50ms
    └─ 1.0 / 50ms = 20 FPS → 触发 "低FPS窗口" 计数
            │
            ▼（若前序已有1次低FPS窗口）
触发 Tier 降级！在开球后第一帧就触发材质重建！
    └─ 开球动画期间叠加材质重建 → 双重帧峰
```

**结论**：`deltaTime` 的 clamp 机制会将开球帧的异常帧时长写入 FPS 采样窗口，可能**错误地加速 Tier 降级触发**。开球本身就是一个"合理的计算峰值"，不应被 FPS 采样误判为系统负载过高。

### 7.3 潜在级联路径：@Published 每帧触发 SwiftUI diff

```
每帧 renderUpdate()
    └─ viewModel.pitchAngle = ...   ← @Published 写入
            │
            ▼
objectWillChange.send() → SwiftUI 主线程排队 body 重算
    └─ 若依赖 pitchAngle 的视图 body 计算复杂 → 每帧额外 0.5–2ms
```

---

## 8. 当前循环 vs 推荐循环对比流程图

### 8.1 当前循环（存在问题）

```
CADisplayLink [主线程]
│
├─ [同步] syncRenderQualityState       ← @Published 写入风险
├─ [同步] updateTrajectoryPlaybackFrame ← 球位置插值（可接受）
├─ [同步] updateShadowPositions        ← 可接受
├─ [同步] recordFrameTime              ← O(n) removeFirst 风险
├─ [同步] evaluateRecoveryFrame
├─ [同步] applyRenderQualityIfNeeded   ← Tier变化时：同步 reapplyLightSettings
│         └─ [main.async 伪延迟]       ← ⚠️ 仍在主线程！材质重建 5–40ms
├─ [同步] hitTest × 1（相机防穿墙）   ← 每帧 CPU 射线检测
├─ [同步] projectPoint × 1（白球锚定）
├─ [同步] CueStick.update + elevation  ← 可接受
├─ [45Hz] 瞄准线射线检测              ← 可接受
└─ [30Hz] 轨迹预测（无上限保护?）     ← 潜在风险

击球瞬间 [主线程，帧外触发]：
└─ engine.simulate(maxEvents:500)      ← ⚠️ 主线程同步阻塞！20–80ms
```

### 8.2 推荐循环（优化后）

```
CADisplayLink [主线程]
│
├─ Phase A: 状态读取（只读，≤0.1ms）
│    ├─ 读取 RenderQualityManager.currentTier（无写操作）
│    └─ 读取 trajectoryPlayback（引用检查）
│
├─ Phase B: 球位置更新（≤1ms）
│    ├─ updateTrajectoryPlaybackFrame（保持现有，插值轻量）
│    └─ updateShadowPositions
│
├─ Phase C: 帧率采样（≤0.05ms）
│    └─ recordFrameTime（改用环形缓冲区，O(1) 写入）
│         └─ [Tier变化] 设置标志位 needsTierChange = true
│                        ← 本帧不执行任何重建！
│
├─ Phase D: 相机更新（≤1ms）
│    ├─ updateCameraRig（保持现有）
│    ├─ [条件化] applyCameraRaycastRadiusConstraint()
│    │    └─ 仅在相机半径发生变化时执行 hitTest（非每帧）
│    └─ lockCueBallScreenAnchor（保持现有）
│
├─ Phase E: UI 逻辑（≤0.5ms）
│    ├─ 仅在值变化时写入 pitchAngle（diff check 避免 @Published 无效触发）
│    ├─ [aiming] CueStick.update
│    ├─ [45Hz] 瞄准线更新
│    └─ [30Hz] 轨迹预测（严格 maxEvents ≤ 20 限制）
│
└─ Phase F: 帧尾延迟处理（在 Metal 提交之后的空闲时段）
     └─ [needsTierChange] 异步派发到专用队列：
          ├─ [后台] IBL Cube Map 生成（若缓存未命中）
          ├─ [后台] 材质参数计算
          └─ [主线程 apply] 仅最终的 SCNMaterial 属性写入（<1ms）

击球瞬间 [异步，后台线程]：
├─ DispatchQueue.global(qos: .userInitiated).async:
│    └─ engine.simulate(maxEvents:500)   ← 后台运行！
│         └─ 完成后 → DispatchQueue.main.async:
│                       startTrajectoryPlayback(recorder)
└─ 击球动画立即开始（不阻塞主线程）
```

### 8.3 关键改进对比

| 维度 | 当前设计 | 推荐设计 |
|------|---------|---------|
| 物理模拟线程 | 主线程同步 | 后台线程异步 |
| 材质重建时机 | 同帧/下帧主线程 | 后台计算 + 主线程apply |
| IBL 重建 | 主线程同步生成 | 后台预生成 + 预热缓存 |
| hitTest 频率 | 每帧必执行 | 仅相机半径变化时 |
| @Published 写入 | 每帧无条件写入 | diff后按需写入 |
| FPS 采样数组 | Swift Array O(n) removeFirst | 环形缓冲区 O(1) |
| Tier变化帧 | 同帧重建部分资产 | 完全延迟，帧内仅设标志 |

---

## 9. 帧循环行为规范

### 9.1 帧循环内允许做的事

| 操作 | 原因 |
|------|------|
| 读取预计算数据（位置、速度、事件快照） | 纯读取，无副作用 |
| 插值计算（lerp、smoothstep、euler 角度） | O(1) 数学运算 |
| 更新 SCNNode.position / rotation（已知轻量） | SceneKit 允许主线程节点更新 |
| 采样帧率（append 到环形缓冲区） | O(1) |
| 检测 Tier 变化（设置标志位） | 无副作用 |
| 相机阻尼插值（CameraRig.update） | 轻量数学 |
| 球杆节点位置更新（CueStick.update） | 节点属性写入，轻量 |
| 节流后的瞄准线更新（45Hz，简单几何） | 有节流保护 |
| 节流后的轨迹预测（30Hz，限制事件数） | 有节流保护 |

### 9.2 帧循环内绝对禁止做的事

| 禁止操作 | 违规后果 | 对应代码 |
|---------|---------|---------|
| 调用 `engine.simulate()` | 主线程阻塞 20–80ms | `executeStroke()` 当前同步调用 |
| 无条件每帧 hitTest | CPU 射线检测重复浪费 | `applyCameraRaycastRadiusConstraint()` |
| `enumerateMaterials()` 全场景遍历 | 3–10ms 树遍历 | Tier 变化时同步触发 |
| `generateIBLCubeMap()` 同步生成 | 2–30ms 像素渲染 | `reapplyMaterialsAndEnvironment()` 内 |
| 无 diff 检查的 `@Published` 写入 | SwiftUI 每帧 diff | `pitchAngle` 写入 |
| `DispatchQueue.main.async` 替代后台线程 | 仍在主线程，延迟无效 | `reapplyRenderSettings(deferMaterials:)` |
| 修改 `shadowMapSize` | 触发 GPU 贴图重分配 | Tier 降级时 |
| 分配大型 UIImage 或纹理 | 内存峰值 | IBL 未命中缓存时 |
| 遍历全部 `childNodes`（无限制） | 节点数 O(n) 遍历 | 材质重建 |

### 9.3 应延迟或后台执行的任务列表

| 任务 | 推荐执行方式 | 优先级 |
|------|------------|------|
| `engine.simulate()` 物理模拟 | `DispatchQueue.global(.userInitiated).async` | 🔴 最高 |
| IBL Cube Map 生成（缓存未命中） | 后台预热 + 缓存，帧内直接复用 | 🔴 最高 |
| 全场景材质遍历重建 | 后台计算参数 → 主线程 apply | 🔴 最高 |
| 轨迹预测（updateTrajectoryPreview） | 降低 maxEvents 上限 + 考虑后台 | 🟠 高 |
| `enhanceBallMaterials()` | 后台计算 → 主线程写入 | 🟠 高 |
| 相机防穿墙 hitTest | 改为条件触发（半径变化时） | 🟡 中 |
| @Published pitchAngle 写入 | 加 diff 检查（值变化才写） | 🟡 中 |
| FPS 采样数组 removeFirst | 改为环形缓冲区 | 🟡 中 |

---

## 10. 改造优先级列表

### P0 · 紧急（直接影响用户感知的明显卡顿）

| 优先级 | 问题 | 改造方案 | 预期收益 |
|--------|------|---------|---------|
| P0-1 | `engine.simulate()` 主线程同步阻塞 | 移至 `DispatchQueue.global(.userInitiated)` 异步执行，击球动画与模拟并行 | 消除开球帧 20–80ms jank |
| P0-2 | IBL 生成未命中缓存时主线程同步渲染 | App 启动时预热所有 Tier 的 IBL 缓存；Tier 变化时先复用旧 IBL，后台更新 | 消除 Tier 切换 30ms 帧峰 |
| P0-3 | `reapplyMaterialsAndEnvironment()` 的 `main.async` 是假延迟 | 将材质参数计算移至后台，主线程仅做最终属性写入（< 1ms） | 消除材质重建帧峰 |

### P1 · 重要（影响帧率稳定性的系统性问题）

| 优先级 | 问题 | 改造方案 | 预期收益 |
|--------|------|---------|---------|
| P1-1 | 开球帧异常 deltaTime 污染 FPS 采样 | 在 `executeStroke()` 前后 reset `lastTimestamp`，或对物理模拟帧标记跳过采样 | 防止开球误触 Tier 降级 |
| P1-2 | hitTest 每帧必执行 | 缓存上次 radius，仅在 `abs(currentRadius - lastRadius) > threshold` 时执行 | 节省 0.2–1ms/帧 |
| P1-3 | `updateTrajectoryPreview` 无严格计算上限 | 确认并强制 `maxEvents ≤ 20` 或 `maxTime ≤ 0.1s`，必要时降级为简化预测 | 防止预测计算溢出 |

### P2 · 优化（提升帧率余量，改善架构质量）

| 优先级 | 问题 | 改造方案 | 预期收益 |
|--------|------|---------|---------|
| P2-1 | `@Published pitchAngle` 每帧无条件触发 SwiftUI diff | 加 `abs(newValue - pitchAngle) > 0.001` 门控 | 减少 SwiftUI 重绘 |
| P2-2 | FPS 采样数组 `removeFirst()` O(n) | 改用 `CircularBuffer<CFTimeInterval>` 或 `RingBuffer` 实现 | 每帧节省 O(n) 内存移动 |
| P2-3 | 材质重建遍历所有节点 | 建立材质节点缓存字典，避免每次递归 `childNodes` | 减少遍历时间 50–80% |
| P2-4 | Tier 切换冷却期内的 `syncRenderQualityState()` | 若 Tier 未变化，直接 return（当前可能有无效写入） | 减少 @Published 触发 |

### P3 · 架构改进（中长期，提升可维护性）

| 优先级 | 问题 | 改造方案 |
|--------|------|---------|
| P3-1 | 全部逻辑在主线程，无并发保障 | 建立帧同步点（game state snapshot），后台线程只读游戏状态 |
| P3-2 | CADisplayLink 调度精度不如 `SCNSceneRendererDelegate` | 评估改用 `renderer(_:updateAtTime:)` 以与 Metal 渲染周期精确同步 |
| P3-3 | 材质重建与场景图修改无事务边界 | 引入 `SCNTransaction` 批量提交材质变更，利用隐式动画缓冲 |
| P3-4 | EnvironmentLightingManager 全为静态方法 | 改为单例 + 后台队列成员，支持异步预热和取消 |

---

## 附录：关键源码位置速查

| 系统 | 文件 | 关键行号 |
|------|------|---------|
| 帧循环入口 | `BilliardSceneView.swift` | L168–264 |
| CADisplayLink 启停 | `BilliardSceneView.swift` | L137–151 |
| Tier 降级逻辑 | `RenderQualityManager.swift` | L189–229 |
| Tier 标志配置 | `RenderQualityManager.swift` | L90–159 |
| 材质批量遍历 | `MaterialFactory.swift` | L400–409 |
| IBL 生成 | `EnvironmentLightingManager.swift` | L188–199 |
| 材质重建触发 | `BilliardScene.swift` | L2056–2075 |
| 相机 orbit 插值 | `CameraRig.swift` | L279–366 |
| 相机防穿墙 hitTest | `BilliardScene.swift` | `applyCameraRaycastRadiusConstraint()` |
| 物理离线模拟 | `EventDrivenEngine.swift` | L246–303 |
| 轨迹回放插值 | `TrajectoryPlayback.swift` | L76–195 |
| 击球入口 | `BilliardSceneView.swift` | L1145–1280 |
