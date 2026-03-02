# 验证需求文档

## Introduction

验证并修复现有的物理引擎。将 BilliardTrainer (Swift) 物理引擎与 pooltool-main (Python) 参考实现进行系统性对照，通过自动化测试与真机测试双通道覆盖所有物理模块，发现偏差并修复，确保两者行为一致。

## 验证范围

### 参考基线
- **Python 参考实现**: pooltool-main (`pooltool/`)
- **Swift 待验证实现**: BilliardTrainer (`BilliardTrainer/Core/Physics/`)

### 验证模块映射

| 验证模块 | Swift 文件 | Swift 函数 | Python 参考 | 测试通道 |
|----------|-----------|------------|-------------|---------|
| 四次方程求解 | QuarticSolver.swift | `solveQuartic(a:b:c:d:e:)` | `ptmath/roots/quartic.py` | 自动化 |
| 球-球碰撞时间 | CollisionDetector.swift | `ballBallCollisionTime(...)` | `solve.ball_ball_collision_coeffs` → quartic | 自动化 |
| 球-直线库边碰撞时间 | CollisionDetector.swift | `ballLinearCushionTime(...)` | `solve.ball_linear_cushion_collision_time()` | 自动化 |
| 球-圆弧库边碰撞时间 | CollisionDetector.swift | `ballCircularCushionTime(...)` | `solve.ball_circular_cushion_collision_time()` | 自动化 |
| 球-球碰撞响应 | CollisionResolver.swift | `resolveBallBallPure(...)` | `physics/resolve/ball_ball/` | 自动化 |
| 库边碰撞响应 | CushionCollisionModel.swift | `solve(...)` | `physics/resolve/ball_cushion/mathavan_2010/` | 自动化 |
| 解析运动演化 | AnalyticalMotion.swift | `evolveSliding/evolveRolling/evolveSpinning` | `physics/evolve/` | 自动化 |
| 状态转换时间 | AnalyticalMotion.swift | `slideToRollTime/rollToSpinTime/spinToStationaryTime` | `physics/evolve/` | 自动化 |
| 球杆击球 | CueBallStrike.swift | `strike(...)` | `physics/resolve/stick_ball/instantaneous_point/` | 自动化 |
| 事件驱动引擎 | EventDrivenEngine.swift | `simulate(...)` | `evolution/event_based/simulate.simulate()` | 自动化 + 真机 |
| 轨迹渲染与交互 | - | - | - | 真机 |

## Requirements

### Requirement 1: 四次方程求解器

**Objective:** As a 物理引擎验证者, I want QuarticSolver 的输出与 pooltool quartic 求解器在给定系数下一致, so that 碰撞时间计算依赖的正确性得到保障。

#### Acceptance Criteria
1. When 给定 quartic 系数 (a,b,c,d,e)，the Swift `QuarticSolver.solveQuartic()` shall 产出与 Python `quartic.solve()` 一致的实根集合（顺序与数值均在容差内）
2. When 无实根、重根、极小系数等边界情况，the Swift 实现 shall 保持数值稳定，不产生 NaN/Inf，且返回与 Python 一致的判断
3. The Swift 实现 shall 在所有测试用例上与 Python 参考的输出差异不超过 abs=1e-5, rel=1e-3

#### 测试通道
- [x] 自动化测试 (XCTest): 多组系数覆盖（含无实根、重根、极小系数）
- [ ] 真机测试: N/A

#### 验证数据规格
- **输入数据来源**: pooltool pytest 测试用例 / 自定义系数矩阵
- **容差标准**: 绝对容差 1e-5 / 相对容差 1e-3
- **Ground Truth 生成**: `python -c "from pooltool.ptmath.roots import quartic; quartic.solve(a,b,c,d,e)"`

---

### Requirement 2: 球-球碰撞时间

**Objective:** As a 物理引擎验证者, I want CollisionDetector.ballBallCollisionTime 与 pooltool ball_ball 碰撞时间求解一致, so that 事件驱动模拟能正确预测球球碰撞时序。

#### Acceptance Criteria
1. When 给定两球位置、速度、状态、半径，the Swift `ballBallCollisionTime` shall 产出与 Python `solve.ball_ball_collision_time` 一致的最小正碰撞时间（或 nil 当无碰撞）
2. When 两球相背运动、已重叠、极端速度等边界条件，the Swift 实现 shall 保持数值稳定，不产生 NaN/Inf，且与 Python 的「跳过/无碰撞」判断一致
3. The Swift 实现 shall 在所有测试用例上与 Python 参考的碰撞时间差异不超过 abs=1e-5, rel=1e-3

#### 测试通道
- [x] 自动化测试 (XCTest): 各角度/速度组合、滚动/滑动/旋转状态组合
- [ ] 真机测试: 通过事件驱动端到端验证

#### 验证数据规格
- **输入数据来源**: pooltool 测试用例 / 自定义 rvw 矩阵
- **容差标准**: 绝对容差 1e-5 / 相对容差 1e-3
- **Ground Truth 生成**: 调用 `pooltool.evolution.event_based.solve` 对应函数

---

### Requirement 3: 球-直线库边碰撞时间

**Objective:** As a 物理引擎验证者, I want CollisionDetector.ballLinearCushionTime 与 pooltool ball_linear_cushion_collision_time 一致, so that 球-库边碰撞事件时序正确。

#### Acceptance Criteria
1. When 给定球位置、速度、库边线段、半径，the Swift 实现 shall 产出与 Python 一致的最小正碰撞时间（或 nil）
2. When 球背向库边运动、球已在库边内等边界条件，the Swift 实现 shall 保持数值稳定
3. The Swift 实现 shall 输出差异不超过 abs=1e-5, rel=1e-3

#### 测试通道
- [x] 自动化测试 (XCTest): 各入射角、速度、库边朝向
- [ ] 真机测试: 通过库边反弹视觉验证

#### 验证数据规格
- **输入数据来源**: pooltool 测试 / 自定义参数
- **容差标准**: 绝对容差 1e-5 / 相对容差 1e-3
- **Ground Truth 生成**: `solve.ball_linear_cushion_collision_time()`

---

### Requirement 4: 球-圆弧库边碰撞时间

**Objective:** As a 物理引擎验证者, I want CollisionDetector.ballCircularCushionTime 与 pooltool ball_circular_cushion_collision_time 一致, so that 袋口附近圆弧库边的碰撞时序正确。

#### Acceptance Criteria
1. When 给定球位置、速度、圆弧库边参数、半径，the Swift 实现 shall 产出与 Python 一致的最小正碰撞时间（或 nil）
2. When 边界/极端输入，the Swift 实现 shall 保持数值稳定
3. The Swift 实现 shall 输出差异不超过 abs=1e-5, rel=1e-3

#### 测试通道
- [x] 自动化测试 (XCTest): 袋口附近入射场景
- [ ] 真机测试: 袋口附近反弹视觉验证

#### 验证数据规格
- **输入数据来源**: pooltool 测试 / 自定义参数
- **容差标准**: 绝对容差 1e-5 / 相对容差 1e-3
- **Ground Truth 生成**: `solve.ball_circular_cushion_collision_time()`

---

### Requirement 5: 球-球碰撞响应

**Objective:** As a 物理引擎验证者, I want CollisionResolver.resolveBallBallPure 与 pooltool Alciatore 摩擦碰撞模型输出一致, so that 碰后速度与角速度正确。

#### Acceptance Criteria
1. When 给定两球碰前 rvw、接触法向、物理常量，the Swift 实现 shall 产出与 Python 碰撞响应一致的碰后 rvw
2. When 正碰、掠碰、静止球被撞等场景，the Swift 实现 shall 保持数值稳定
3. The Swift 实现 shall 碰后线速度、角速度与 Python 差异不超过 abs=1e-4, rel=1e-2

#### 测试通道
- [x] 自动化测试 (XCTest): 正碰、掠碰、多角度
- [ ] 真机测试: 碰撞视觉效果验证

#### 验证数据规格
- **输入数据来源**: pooltool 碰撞响应测试 / 预计算碰前状态
- **容差标准**: 绝对容差 1e-4 / 相对容差 1e-2
- **Ground Truth 生成**: `physics/resolve/ball_ball` 对应模型

---

### Requirement 6: 库边碰撞响应

**Objective:** As a 物理引擎验证者, I want CushionCollisionModel.solve 与 pooltool Mathavan 2010 模型输出一致, so that 库边反弹后的速度与旋转正确。

#### Acceptance Criteria
1. When 给定球碰前 rvw、库边法向、物理常量，the Swift 实现 shall 产出与 Python Mathavan2010 模型一致的碰后 rvw
2. When 大角度入射、小角度掠射等场景，the Swift 实现 shall 保持数值稳定
3. The Swift 实现 shall 碰后状态与 Python 差异不超过 abs=1e-4, rel=1e-2

#### 测试通道
- [x] 自动化测试 (XCTest): 各入射角、速度
- [ ] 真机测试: 库边反弹角度与力度验证

#### 验证数据规格
- **输入数据来源**: pooltool ball_cushion 测试 / 自定义参数
- **容差标准**: 绝对容差 1e-4 / 相对容差 1e-2
- **Ground Truth 生成**: `physics/resolve/ball_cushion/mathavan_2010/model.solve()`

---

### Requirement 7: 解析运动演化

**Objective:** As a 物理引擎验证者, I want AnalyticalMotion.evolveSliding/Rolling/Spinning 与 pooltool evolve 公式输出一致, so that 球在无碰撞区间的运动轨迹正确。

#### Acceptance Criteria
1. When 给定初始 rvw、时间 dt、物理常量，the Swift evolve 函数 shall 产出与 Python evolve_ball_motion 一致的位置、速度、角速度
2. When sliding→rolling、rolling→spinning、spinning→stationary 各状态，the Swift 实现 shall 与 Python 状态方程一致
3. The Swift 实现 shall 输出差异不超过 abs=1e-4, rel=1e-2（考虑 Float vs Double）

#### 测试通道
- [x] 自动化测试 (XCTest): 各状态下的演化、多时间步
- [ ] 真机测试: 轨迹视觉一致性

#### 验证数据规格
- **输入数据来源**: pooltool physics/evolve 测试 / 自定义参数
- **容差标准**: 绝对容差 1e-4 / 相对容差 1e-2
- **Ground Truth 生成**: `physics.evolve.evolve_ball_motion()`

---

### Requirement 8: 状态转换时间

**Objective:** As a 物理引擎验证者, I want AnalyticalMotion.slideToRollTime/rollToSpinTime/spinToStationaryTime 与 pooltool 参考公式一致, so that 状态转换事件时间正确。

#### Acceptance Criteria
1. When 给定球当前 rvw、物理常量，the Swift 转换时间函数 shall 产出与 Python 一致的时间值（或 nil）
2. When 已处于目标状态、速度为零等边界，the Swift 实现 shall 与 Python 行为一致
3. The Swift 实现 shall 输出差异不超过 abs=1e-5, rel=1e-3

#### 测试通道
- [x] 自动化测试 (XCTest): 各状态组合
- [ ] 真机测试: N/A

#### 验证数据规格
- **输入数据来源**: pooltool physics/evolve 或 transition 逻辑
- **容差标准**: 绝对容差 1e-5 / 相对容差 1e-3
- **Ground Truth 生成**: 对照 pooltool 公式手写或调用相关 API

---

### Requirement 9: 球杆击球

**Objective:** As a 物理引擎验证者, I want CueBallStrike.strike 与 pooltool instantaneous_point 模型输出一致, so that 击球后母球初始状态正确。

#### Acceptance Criteria
1. When 给定击球方向、力度、tip offset (phi, theta, Q)、球参数，the Swift 实现 shall 产出与 Python cue_strike 一致的击后 rvw
2. When 无偏移（正中击球）、最大偏移等场景，the Swift 实现 shall 保持数值稳定
3. The Swift 实现 shall squirt 角度与击后方向与 Python 差异不超过 abs=1e-4, rel=1e-2

#### 测试通道
- [x] 自动化测试 (XCTest): 各 tip offset、力度组合
- [ ] 真机测试: 旋转球弧线方向与幅度

#### 验证数据规格
- **输入数据来源**: pooltool stick_ball 测试 / 自定义参数
- **容差标准**: 绝对容差 1e-4 / 相对容差 1e-2
- **Ground Truth 生成**: `physics/resolve/stick_ball/instantaneous_point.cue_strike()`

---

### Requirement 10: 事件驱动引擎端到端

**Objective:** As a 物理引擎验证者, I want EventDrivenEngine.simulate 在相同初始条件下与 pooltool simulate 产出一致的事件序列与轨迹, so that 整体物理模拟正确。

#### Acceptance Criteria
1. When 给定相同初始球状态、击球参数、台桌参数，the Swift 模拟 shall 产出与 Python 一致的碰撞事件顺序与时间、球轨迹关键点
2. When 多球开球、复杂碰撞链等场景，the Swift 实现 shall 无球体穿越、重叠未分离、事件遗漏
3. The Swift 实现 shall 轨迹关键点（位置、速度）与 Python 差异在可接受范围（考虑累积误差）

#### 测试通道
- [x] 自动化测试 (XCTest): 端到端场景，与 pooltool test_simulate 对标
- [x] 真机测试: 开球、碰撞、进袋等综合视觉验证

#### 验证数据规格
- **输入数据来源**: pooltool 端到端测试场景
- **容差标准**: 位置 abs=1e-3, 速度 rel=1e-2（端到端允许更大容差）
- **Ground Truth 生成**: `evolution.event_based.simulate.simulate()`

---

### Requirement 11: 真机视觉与交互验证

**Objective:** As a 物理引擎验证者, I want 真机运行时的轨迹渲染、碰撞效果、库边反弹、袋口行为、旋转弧线、帧率与物理模拟一致, so that 用户获得正确的训练体验。

#### Acceptance Criteria
1. When 击球后观察球运动，the 轨迹 shall 与 EventDrivenEngine 预测轨迹视觉一致，无明显偏差
2. When 多球开球场景，the 帧率 shall ≥30fps，无卡顿、球穿越、爆炸
3. When 加塞击球，the 弧线方向与幅度 shall 符合物理直觉

#### 测试通道
- [ ] 自动化测试: N/A
- [x] 真机测试: 按 test-protocol.md 执行 TC-M-001～TC-M-005 等用例

#### 验证数据规格
- **输入数据来源**: 用户按协议操作
- **判定标准**: PASS/FAIL/DEVIATION，由用户记录
- **结果记录**: `.kiro/specs/physics-engine-validation-fix/test-results/manual/`

---

## 真机测试协议概要

### 需要真机测试的场景
1. SceneKit 渲染正确性（球运动轨迹与 EventDrivenEngine 预测一致）
2. 动画流畅度与帧率（≥30fps）
3. 碰撞时的视觉效果（无穿越、重叠、爆炸）
4. 球杆击球交互响应（tip offset 产生正确弧线）
5. 库边反弹角度与力度
6. 袋口进袋/不进袋判定

### 真机测试结果记录位置
- 路径: `.kiro/specs/physics-engine-validation-fix/test-results/manual/`
- 格式: 遵循 `test-results.md` 模板
