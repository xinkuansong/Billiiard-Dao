# Swift vs pooltool 差距分析报告

---
**Feature**: physics-engine-validation-fix  
**日期**: 2025-03-02  
**状态**: 初稿  
---

## 1. 函数级对照

| Swift 函数 | Python 函数 | 一致性评级 | 差异备注 |
|-----------|-------------|-----------|----------|
| `QuarticSolver.solveQuartic(a:b:c:d:e:)` | `ptmath.roots.quartic.solve(a,b,c,d,e)` | 待验证 | 算法不同：Swift 用 Ferrari，pooltool 用 OQS；需数值比对 |
| `CollisionDetector.ballBallCollisionTime(...)` | `solve.ball_ball_collision_time()` | 待验证 | 系数由调用方传入 vs pooltool 内部 ball_ball_collision_coeffs；加速度/坐标系需对照 |
| `CollisionDetector.ballLinearCushionTime(...)` | `solve.ball_linear_cushion_collision_time()` | 待验证 | 接口形态类似；库边方向/法线约定可能不同 |
| `CollisionDetector.ballCircularCushionTime(...)` | `solve.ball_circular_cushion_collision_time()` | 待验证 | 袋口圆弧参数需对照 |
| `CollisionResolver.resolveBallBallPure(...)` | `physics/resolve/ball_ball/frictional_inelastic` | 待验证 | 均基于 Alciatore，实现细节需逐行对照 |
| `CushionCollisionModel.solve(...)` | `physics/resolve/ball_cushion/mathavan_2010/model.solve` | 待验证 | Mathavan 2010 模型；公式与迭代需对照 |
| `AnalyticalMotion.evolveSliding/Rolling/Spinning` | `physics.evolve.evolve_ball_motion` | 待验证 | 状态方程与 pooltool _evolve_slide/roll/spin 对照 |
| `AnalyticalMotion.slideToRollTime/...` | `physics/evolve` 内 transition 逻辑 | 待验证 | 转换时间公式需对照 |
| `CueBallStrike.strike(...)` | `stick_ball/instantaneous_point.cue_strike()` | 待验证 | 击球模型与 squirt 公式需对照 |
| `EventDrivenEngine.simulate(...)` | `simulate.simulate()` | 待验证 | 事件优先级、skip 逻辑、fallback 策略需对照 |

### 算法对照要点

- **Quartic**: Swift 使用 Ferrari + Newton-Raphson 精化；pooltool 使用 OQS (OpenQuarticsolver) 数值算法。两者应对同一多项式给出相同实根，但数值稳定性与边界处理需测试验证。
- **球-球碰撞系数**: pooltool 通过 `ball_ball_collision_coeffs` 从 rvw 直接计算 quartic 系数；Swift 由 EventDrivenEngine 传入 a1、a2，CollisionDetector 展开 `||dp+dv*t+0.5*da*t^2||^2 = (2R)^2`。需验证系数推导与 pooltool 等价。
- **球-库边**: pooltool 使用 `lx, ly, l0, direction` 等线段参数；Swift 使用 `lineNormal, lineOffset`。需确认几何约定的对应关系。

---

## 2. 物理常量对照

| 常量 | Swift 值 | Python 值 | 一致? | 来源 |
|------|---------|----------|-------|------|
| 重力加速度 g | 9.81 | 9.81 | ✅ | TablePhysics.gravity / BallParams.g |
| 球半径 R | 0.028575 | 0.028575 | ✅ | BallPhysics.radius / BallParams.R |
| 球质量 m | 0.170 | 0.170097 | ⚠️ 微小差异 | BallPhysics.mass / BallParams.m |
| 滑动摩擦 u_s | 0.2 | 0.2 | ✅ | SpinPhysics.slidingFriction / u_s |
| 滚动摩擦 u_r | 0.01 | 0.01 | ✅ | SpinPhysics.rollingFriction / u_r |
| 旋转摩擦 u_sp | 0.01269 (≈) | u_sp_proportionality*R | ✅ | SpinPhysics.spinFriction / u_sp |
| 球-球恢复系数 e_b | 0.95 | 0.95 | ✅ | BallPhysics.restitution / e_b |
| 球-球摩擦 u_b | 0.05 | 0.05 | ✅ | BallPhysics.ballBallFriction / u_b |
| 库边恢复 e_c | 0.85 | 0.85 | ✅ | TablePhysics.cushionRestitution / e_c |
| 库边摩擦 f_c | 0.2 | 0.2 | ✅ | TablePhysics.cushionFriction / f_c |

### 差异说明

- **质量**: Swift `0.170` vs pooltool `0.170097`，相对误差约 0.06%，可能由四舍五入导致。建议与 pooltool 对齐为 `0.170097`。
- **旋转摩擦 proportionality**: Swift 与 pooltool 均为 `10*2/5/9`，一致。

---

## 3. 坐标系适配分析

| 项 | pooltool | BilliardTrainer (SceneKit) | 适配状态 |
|----|----------|---------------------------|----------|
| 上方向 | Z-up | Y-up | 需显式变换 |
| 台面平面 | xy | xz | 需映射 |
| 球位置 | (x, y, z) z=台面高 | (x, y, z) y=台面高 | x→x, y→z, z→y |
| 重力方向 | (0,0,-g) | (0,-g,0) | 已适配 |
| 库边法线 | 台面平面内 | 台面平面内 | 需验证朝向约定 |

### 检查清单

- [ ] 所有碰撞检测输入（位置、速度、加速度）已正确映射到 pooltool 等效坐标系
- [ ] 库边线段/圆弧参数与 pooltool `LinearCushionSegment`、`CircularCushionSegment` 约定一致
- [ ] 袋口几何（center, radius）与 pooltool 一致
- [ ] 球杆击球时的 tip offset (phi, theta, Q) 与 pooltool 定义一致

---

## 4. pooltool 测试覆盖分析

| 测试文件 | 用途 | 可复用性 | 备注 |
|---------|------|---------|------|
| `ptmath/roots/test_quartic.py` | quartic 求解 | 高 | 有 hard_coeffs、1010_reference，容差 rtol=1e-15/1e-3 |
| `ptmath/roots/data/*.npy` | 系数与根数据 | 高 | 可直接作为 Swift 输入与期望输出 |
| `evolution/event_based/test_simulate.py` | 端到端模拟 | 高 | 场景可复刻为 Swift 端到端用例 |
| `physics/resolve/ball_ball/test_ball_ball.py` | 球-球碰撞 | 中 | 需提取输入/期望到 JSON |
| `physics/resolve/ball_cushion/test_ball_cushion.py` | 库边碰撞 | 中 | 同上 |
| `physics/resolve/ball_stick/test_squirt.py` | squirt 角度 | 中 | 击球模型验证 |
| `physics/resolve/ball_ball/test_frictional_mathavan.py` | 摩擦碰撞 | 中 | Alciatore/Mathavan 模型 |

### 建议复用策略

1. 从 `ptmath/roots/data/*.npy` 导出 JSON，供 Swift QuarticSolver 比对
2. 编写 Python 脚本调用 pooltool 函数，输出测试用例 JSON 到 `BilliardTrainerTests/TestData/`
3. 复刻 `test_simulate` 中典型场景（单球、双球、开球等）为 Swift 端到端测试

---

## 5. 差异分类与优先级

| 优先级 | 差异类型 | 影响范围 | 示例 |
|--------|---------|---------|------|
| P0 | 算法偏差 | 碰撞时间/响应错误，轨迹失真 | 四次方程系数推导、碰撞响应公式 |
| P0 | 坐标系错误 | 全场景错误 | 法线/速度方向映射 |
| P1 | 常量差异 | 数值偏差，长期可累积 | 质量 0.170 vs 0.170097 |
| P1 | 边界处理 | 极端/重叠场景 | 重叠球分离、零时刻保护、fallback |
| P2 | 数值精度 | Float vs Double | 累积误差、容差放宽 |
| P2 | 缺失功能 | 特定场景 | 球袋判定逻辑、事件类型 |

---

## 6. 修复策略建议

### 推荐：渐进式对齐 (Option C)

- 差异覆盖面较广，但多数为可量化、可逐项修复的问题
- 优先修复 P0：Quartic 系数与根筛选、碰撞响应公式、坐标系
- 再修复 P1：质量常量、边界与 fallback 逻辑
- P2 记录偏差，在验证通过后接受或后续迭代

### 工作量估算

| 模块 | Effort | Risk | 说明 |
|------|--------|------|------|
| 物理常量 | S (1d) | Low | 对齐质量等常量 |
| QuarticSolver | S (1-2d) | Medium | 数值比对，必要时引入 pooltool 测试数据 |
| 球-球碰撞时间 | M (2-3d) | High | 系数推导、skip 逻辑、fallback |
| 球-库边碰撞时间 | M (2-3d) | High | 几何约定、直线/圆弧 |
| 碰撞响应 | M (3-4d) | High | Alciatore、Mathavan 逐行对照 |
| 运动演化 | M (2-3d) | Medium | 状态方程与转换时间 |
| 球杆击球 | M (2d) | Medium | cue_strike、squirt |
| 事件驱动引擎 | L (3-5d) | High | 优先级、袋口、缓存失效 |

---

## 7. 输出清单（Output Checklist）

- [x] 函数级对照表（一致/偏差/缺失标记）
- [x] 物理常量对照表
- [x] 坐标系适配清单
- [x] 差异优先级排序（P0/P1/P2）
- [x] 修复策略建议
- [x] 风险评估

---

## 8. 下一步行动

1. 执行 `/kiro/spec-design physics-engine-validation-fix` 设计测试架构
2. 编写 Python 测试数据生成脚本，输出 JSON 至 BilliardTrainerTests/TestData/
3. 优先实现 QuarticSolver 与 ball_ball_collision_time 的自动化比对测试
4. 将质量常量从 0.170 调整为 0.170097
