# Physics 模块 - 设计与约束

> 对应 README：[README.md](./README.md)
> 文档最后更新：2026-03-03

## 设计目标与非目标

- **目标**：
  - 实现事件驱动的连续碰撞检测（CCD），通过解析方程求解精确碰撞时间，避免离散时间步长导致的穿透和能量损失
  - 提供高精度台球物理模拟，支持滑动、滚动、旋转等多种运动状态，准确模拟球-球碰撞、球-库边碰撞和进袋
  - 保持数值稳定性，通过零时刻事件保护、重叠分离、fallback 检测等机制避免模拟卡死或能量爆炸
  - 与 pooltool Python 参考实现保持算法一致性，关键物理公式和阈值需对照验证
- **非目标**：
  - 不处理游戏规则判定（如犯规检测、得分计算）
  - 不直接管理 UI 交互（如瞄准线绘制、相机控制）
  - 不负责数据持久化（训练记录、用户设置）
  - 不提供实时可视化调试工具（轨迹可视化由 Scene 模块负责）

## 不变量与约束（改动护栏）

### 单位与坐标系

- **SI 单位制**：所有物理量使用国际单位制
  - 长度：米（m）
  - 质量：千克（kg）
  - 时间：秒（s）
  - 角速度：弧度每秒（rad/s）
  - 速度：米每秒（m/s）
- **SceneKit 坐标系**：Y-up 右手坐标系
  - X 轴：台面长边方向（从开球区指向底袋）
  - Y 轴：垂直向上
  - Z 轴：台面短边方向（右手定则）
- **台面中心为原点**：所有位置计算以台面中心为 (0, 0, 0)

### 数值稳定性保护

以下保护机制不可删除，改动需说明理由并验证：

1. **零时刻事件保护**（`EventDrivenEngine.swift`）
   - 阈值：连续零时刻事件 > 80 次
   - 保护措施：时间微调 0.0005s，重置计数器
   - 删除后果：主线程可能因无限循环卡死

2. **重叠分离**（`EventDrivenEngine.separateOverlappingBalls()`）
   - 阈值：球心距离 < 2 * radius - 0.0001m
   - 保护措施：强制分离重叠球，避免碰撞检测失效
   - 删除后果：重叠球导致碰撞检测返回负时间或 NaN

3. **Fallback 碰撞检测**（`CollisionDetector.swift`）
   - 触发条件：四次方程求解失败或返回无效根
   - 保护措施：使用简化的球-球碰撞时间估算
   - 删除后果：某些边界情况（如低速、近碰撞）可能漏检

4. **根筛选与抛光**（`QuarticSolver.swift`）
   - 阈值：退化判定 1e-12，收敛判定 1e-14，残差 1e-6
   - 保护措施：Newton-Raphson 迭代抛光，筛选物理合理根
   - 删除后果：数值误差导致碰撞时间不准确或能量异常

5. **库边碰撞积分上限**（`CushionCollisionModel.swift`）
   - 阈值：最大积分步数 5000，步长 0.0001s
   - 保护措施：防止积分不收敛导致无限循环
   - 删除后果：某些碰撞角度可能导致计算超时

### 时序与状态约束

- **事件优先级顺序**：必须严格遵循，同时刻事件按优先级处理
  - 优先级 -1：重叠分离（最高优先级）
  - 优先级 0：碰撞事件（球-球、球-库边）
  - 优先级 1：滑动→滚动转换
  - 优先级 2：滚动→旋转转换、进袋事件
  - 优先级 3：旋转→静止转换（最低优先级）
- **状态转换顺序**：球状态必须按以下顺序转换，不可跳跃
  - `sliding` → `rolling` → `spinning` → `stationary`
  - `pocketed` 为终止状态，不可转换回其他状态
- **事件时间单调性**：事件队列中事件时间必须单调递增，处理完的事件不可再次入队
- **resolvedEvents / resolvedEventTimes 并行数组**：`resolvedEvents: [PhysicsEventType]` 与 `resolvedEventTimes: [Float]` 下标严格对应，`resolvedEventTimes[i]` 为第 `i` 个事件发生时的绝对模拟时间（`currentTime`，已在 `resolveEvent` 中 `currentTime += dt` 之后记录）。消费方（`extractGameEvents`）必须通过 `zip(resolvedEvents, resolvedEventTimes)` 联动读取，不可单独使用 `engine.currentTime`（后者为最终模拟结束时刻，非事件发生时刻）。

### 常量与阈值清单

| 常量/阈值 | 值 | 来源/理由 | 改动影响 |
|-----------|-----|----------|----------|
| **更新频率** | 60Hz (1/60s) | PhysicsEngine 定时器更新频率 | 影响实时物理更新平滑度 |
| **滑动判定阈值** | relSpeed > 0.03 | 相对速度阈值，区分滑动与滚动 | 影响状态转换时机 |
| **静止判定阈值** | speed < 0.005 m/s && angularSpeed < 0.1 rad/s | 速度和角速度双阈值 | 影响球停止判定，阈值过小可能导致永远不停 |
| **零时刻事件保护阈值** | streak > 80 | 连续零时刻事件计数 | 影响模拟稳定性，阈值过小可能误触发微调 |
| **零时刻微调时间** | 0.0005s | 避免卡死的最小时间步 | 影响模拟精度，过大可能导致时间跳跃 |
| **事件优先级** | -1, 0, 1, 2, 3 | 事件处理顺序 | 影响事件处理逻辑，不可随意调整 |
| **QuarticSolver 退化判定** | 1e-12 | 四次方程退化系数阈值 | 影响方程类型判断，过小可能误判 |
| **QuarticSolver 收敛判定** | 1e-14 | Newton-Raphson 迭代收敛阈值 | 影响根精度，过小可能导致不收敛 |
| **QuarticSolver 残差阈值** | 1e-6 | 根验证残差阈值 | 影响根有效性判断，过大可能接受错误根 |
| **QuarticSolver 迭代次数** | 8 | Newton-Raphson 最大迭代次数 | 影响计算性能，过小可能精度不足 |
| **CollisionDetector 时间 epsilon** | 1e-6s | 碰撞时间比较阈值 | 影响事件去重，过小可能导致重复事件 |
| **CollisionDetector 库边接触误差** | 0.05m | 圆形库边接触判定容差 | 影响库边碰撞检测，过大可能误检 |
| **CushionCollisionModel 最大步数** | 5000 | 积分最大步数 | 影响计算性能，过小可能积分不完整 |
| **CushionCollisionModel 积分步长** | 0.0001s | 积分时间步长 | 影响积分精度，过大可能导致能量异常 |

## 状态机 / 事件模型

### 球运动状态机

```
[stationary] --[击球]--> [sliding]
                              |
                              | [滑动→滚动转换]
                              v
                          [rolling]
                              |
                    +---------+---------+
                    |                   |
        [滚动→旋转转换]        [进袋检测]
                    |                   |
                    v                   v
              [spinning]          [pocketed] (终止)
                    |
                    | [旋转衰减]
                    v
              [stationary]
```

### 事件类型与优先级

```
事件类型                优先级    触发条件
─────────────────────────────────────────────
重叠分离                -1        球心距离 < 2*radius
球-球碰撞               0         两球轨迹相交
球-库边碰撞             0         球与库边轨迹相交
滑动→滚动转换           1         relSpeed <= 0.03
滚动→旋转转换           2         speed < 0.005 && angularSpeed >= 0.1
进袋事件                2         球心到袋口距离 < pocketRadius
旋转→静止转换           3         angularSpeed < 0.1
```

## 错误处理与降级策略

- **四次方程求解失败**：
  - 降级策略：使用 fallback 球-球碰撞时间估算
  - 日志记录：`[CollisionDetector] quartic solver failed, using fallback`
  - 影响：可能略微降低碰撞时间精度，但保证模拟继续
- **库边碰撞积分不收敛**：
  - 降级策略：达到最大步数（5000）时使用当前积分结果
  - 日志记录：`[CushionCollisionModel] integration reached max steps`
  - 影响：某些极端角度可能能量略有偏差
- **重叠球分离失败**：
  - 降级策略：强制设置最小分离距离，记录警告
  - 日志记录：`[EventDrivenEngine] failed to separate overlapping balls`
  - 影响：可能导致后续碰撞检测异常
- **事件队列溢出**：
  - 降级策略：达到 `maxEvents`（默认 1000）时停止模拟
  - 日志记录：`[EventDrivenEngine] reached max events limit`
  - 影响：复杂场景可能提前终止，需增大 `maxEvents` 或优化事件生成

## 性能考量

- **事件缓存**（`EventCache`）：
  - 缓存已计算的转换事件和碰撞事件，避免重复计算
  - 事件解析后自动失效相关缓存
  - 复杂度：O(1) 查询，O(n) 失效（n 为受影响球数）
- **最大事件数限制**：
  - 默认 `maxEvents = 1000`，防止无限循环
  - 复杂场景（如多球连续碰撞）可能需要增大
  - 建议：根据场景复杂度动态调整
- **轨迹快照频率**：
  - 每个事件时刻记录一次快照，非固定时间间隔
  - 存储开销：每个快照 ~100-200 字节（取决于球数）
  - 优化：可考虑稀疏采样（仅记录关键事件）
- **四次方程求解**：
  - Ferrari 方法：O(1) 复杂度
  - Newton-Raphson 抛光：最多 8 次迭代，O(1)
  - 热点路径：每对球每帧可能调用一次，需优化缓存

## 参考实现对照（pooltool）

| Swift 文件/函数 | pooltool 对应 | 偏离说明 |
|----------------|--------------|----------|
| `QuarticSolver.swift` | `pooltool/physics/evolution/event_based/solve.py` | 算法一致，Ferrari 方法 + Newton-Raphson 抛光 |
| `CollisionDetector.swift` | `pooltool/physics/evolution/event_based/solve.py` | 球-球碰撞时间求解公式一致，库边碰撞使用圆形近似 |
| `AnalyticalMotion.swift` | `pooltool/physics/evolution/event_based/evolution.py` | 滑动/滚动/旋转解析方程一致，状态转换时间计算一致 |
| `EventDrivenEngine.swift` | `pooltool/physics/evolution/event_based/evolution.py` | 事件驱动流程一致，优先级顺序一致 |
| `CushionCollisionModel.swift` | `pooltool/physics/evolution/event_based/cushion.py` | Mathavan 2010 模型一致，积分方法一致 |
| `CollisionResolver.swift` | `pooltool/physics/evolution/event_based/resolve.py` | Alciatore 球-球碰撞模型一致，库边碰撞解析一致 |
| `CueBallStrike.swift` | `pooltool/physics/stick_ball/instantaneous_point.py` | instantaneous_point 模型一致，squirt 计算一致 |
| `BallMotionState.swift` | `pooltool/physics/evolution/event_based/state.py` | 状态定义一致，转换条件一致 |

## 设计决策记录（ADR）

### ADR-001：事件驱动 vs 定时器驱动

- **背景**：需要选择物理模拟的更新方式
- **候选方案**：
  1. 定时器驱动（60Hz 固定更新）：实现简单，但可能漏检快速碰撞
  2. 事件驱动（CCD）：精度高，但实现复杂，需要求解方程
- **结论**：采用事件驱动作为主要引擎（`EventDrivenEngine`），保留定时器引擎（`PhysicsEngine`）用于实时预览和轨迹预测
- **后果**：需要维护两套引擎，但提供了精度和性能的平衡

### ADR-002：解析运动 vs 数值积分

- **背景**：球状态演化计算方式选择
- **候选方案**：
  1. 数值积分（RK4、Euler）：通用性强，但累积误差
  2. 解析运动方程：精度高，但需要推导闭式解
- **结论**：采用解析运动方程（`AnalyticalMotion`），利用台球物理的特殊性（恒定摩擦、简单几何）
- **后果**：代码复杂度增加，但显著提高精度和性能

### ADR-003：事件优先级设计

- **背景**：同时刻事件的处理顺序需要明确
- **候选方案**：
  1. 按事件类型固定优先级：简单，但可能不符合物理直觉
  2. 动态优先级：灵活，但实现复杂
- **结论**：采用固定优先级（-1 到 3），确保重叠分离优先于碰撞，碰撞优先于状态转换
- **后果**：某些边界情况可能需要特殊处理，但整体逻辑清晰

### ADR-004：零时刻事件保护机制

- **背景**：连续零时刻事件可能导致模拟卡死
- **候选方案**：
  1. 忽略零时刻事件：简单，但可能丢失重要事件
  2. 时间微调：保证进度，但可能引入误差
  3. 强制分离：物理合理，但可能改变模拟结果
- **结论**：采用时间微调（0.0005s）+ 强制分离的组合策略，阈值设为 80 次
- **后果**：极端情况下可能略微偏离真实物理，但保证模拟稳定性

### ADR-005：角袋几何从单圆心模型升级为 CAD 精确双圆心 + jaw 直线模型

- **背景**：原实现对每个角袋使用单一圆弧圆心（playfield 角点偏移 R），两条 jaw 弧共享圆心，无 jaw 直线段。CAD 精确数据显示实际为两个独立圆弧（长边侧和短边侧各一个圆心，相距 >100mm）加两条 jaw 直线段
- **变更内容**：
  1. 每个角袋从 1 个圆弧圆心改为 2 个独立圆弧圆心（来自 CAD）
  2. 新增 8 条 jaw 直线段（2 条/角袋 × 4 角袋），作为 `LinearCushionSegment` 复用现有碰撞检测
  3. 主库边端点从硬编码偏移量改为引用圆弧 rail-side 连接点
  4. 仅定义 RU（右上角）基准数据，通过 mirrorX / mirrorZ 对称生成其余 3 个角袋
- **设计原则**：
  - 数据驱动：使用 center + startAngle + endAngle，不假设弧角恒为 45°
  - jaw 线法线显式存储（指向台内），不运行时推导
  - pocket center 独立于 jaw 几何，不依赖 "jaw 终点中点 = pocket center"
- **对 EventDrivenEngine 的影响**：
  - `linearCushions.count` 从 6 增至 14（6 主库边 + 8 jaw 线），圆弧索引自动偏移
  - 已验证 engine 遍历完整数组、cushionIndex 动态映射、priority 排序正确
  - jaw 碰撞优先级 = 0（与主库边相同），高于 pocket 事件优先级 = 2
- **几何一致性断言**：初始化时验证弧端点距离 ≈ R、相邻段端点重合、jaw 法线单位化且指向台内
- **后果**：角袋区域碰撞检测精度提升，反弹法线准确性提升。风险点为 pocket 事件可能在极端角度下抢先于 jaw 碰撞（已有 priority 缓解）
