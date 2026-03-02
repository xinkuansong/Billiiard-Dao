# Swift vs pooltool 差距分析流程

## Objective
分析 Swift 物理引擎实现与 pooltool Python 参考实现之间的差距，指导验证策略和修复优先级。

## Analysis Framework

### 1. 函数级对照

对每对 Swift/Python 函数:

- **函数映射**:
  | Swift 函数 | Python 函数 | 一致性评级 |
  |-----------|-------------|-----------|
  | `func()` | `def func()` | 一致/偏差/缺失 |

- **算法对照**:
  - 数学公式是否一致
  - 计算步骤顺序是否一致
  - 系数和常量是否一致
  - 边界条件处理是否一致

- **差异分类**:
  - **算法差异**: 公式或逻辑不同
  - **数值差异**: Float vs Double, 容差不同
  - **坐标系差异**: Y-up vs Z-up
  - **常量差异**: 物理常量值不同
  - **边界差异**: 边界/异常处理策略不同
  - **缺失功能**: Swift 未实现 Python 中的功能

### 2. 物理常量对照

| 常量 | Swift 值 | Python 值 | 一致? | 来源 |
|------|---------|----------|-------|------|
| 重力加速度 | | | | |
| 球半径 | | | | |
| 球质量 | | | | |
| 滑动摩擦系数 | | | | |
| 滚动摩擦系数 | | | | |
| 旋转摩擦系数 | | | | |
| 恢复系数 | | | | |

### 3. 坐标系适配分析

- pooltool: Z-up 坐标系
- SceneKit: Y-up 坐标系
- 检查所有向量运算是否正确适配:
  - 重力方向
  - 法线方向
  - 台面法向量
  - 库边法线

### 4. pooltool 测试覆盖分析

从 `pooltool-main/tests/` 提取:
- 每个测试文件的测试用例数量
- 使用的测试参数和期望值
- 容差标准
- 可直接复用的测试用例

### 5. Implementation Approach Options

#### Option A: 逐函数修复
**When to consider**: 差异较少，函数粒度修改可控
- 逐个修复偏差函数
- 每修一个跑对应测试

#### Option B: 模块级重写
**When to consider**: 差异较多，函数间有耦合
- 参照 pooltool 重写整个模块
- 回归测试验证

#### Option C: 渐进式对齐
**When to consider**: 差异覆盖面广但各个不严重
- 优先修复 P0 差异
- 容忍 P2 差异（记录偏差并接受）
- 逐步收敛

### 6. Implementation Complexity & Risk

- Effort:
  - S (1-3 days): 常量修改、简单公式对齐
  - M (3-7 days): 函数逻辑修改、坐标系适配
  - L (1-2 weeks): 模块重写、新增功能
  - XL (2+ weeks): 架构改动、全量对齐
- Risk:
  - High: 核心碰撞检测/求解器修改
  - Medium: 碰撞响应参数调整
  - Low: 物理常量对齐

### Output Checklist

- 函数级对照表（一致/偏差/缺失标记）
- 物理常量对照表
- 坐标系适配清单
- 差异优先级排序（P0/P1/P2）
- 修复策略建议
- 风险评估

## Principles

- **pooltool 为基准**: 差异以 pooltool 实现为准
- **代码级深入**: 不能只看接口，要读算法逻辑
- **敏感区域谨慎**: QuarticSolver、CollisionDetector 等修改需额外验证
- **量化差异**: 尽可能给出数值偏差大小
