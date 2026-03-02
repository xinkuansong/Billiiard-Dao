# 研究与设计决策

---
**Purpose**: 记录物理引擎交叉验证过程中的研究发现、算法对照分析和设计决策。

**Usage**:
- 记录 pooltool 参考实现与 Swift 实现的差异分析
- 记录数值精度与容差选择的依据
- 为设计文档提供参考和证据支持
---

## Summary
- **Feature**: `<feature-name>`
- **验证范围**: 模块名 / 全量
- **Key Findings**:
  - Finding 1
  - Finding 2
  - Finding 3

## 参考实现对照分析

### [Swift 函数 vs Python 函数]
- **Swift 实现**: `文件:行号` — 简述算法
- **Python 参考**: `文件:行号` — 简述算法
- **差异**:
  - 算法差异: (如系数计算方式不同)
  - 数值精度差异: (Float vs Double)
  - 坐标系差异: (Y-up vs Z-up)
  - 边界处理差异: (如零值保护策略)
- **影响评估**: 对验证结果的影响程度 (High/Medium/Low)
- **建议**: 保持一致 / 可接受偏差 / 需要修复

_Repeat for each function pair._

## 数值精度分析

### 容差选择依据
- **绝对容差**: 选择理由和参考依据
- **相对容差**: 选择理由和参考依据
- **特殊模块容差**: 针对特定模块的定制容差及原因

### 精度风险
- Float (32-bit) vs Double (64-bit) 的累积误差分析
- 四次方程求解的数值稳定性评估
- 链式碰撞中的误差传播分析

## Design Decisions

### Decision: `<Title>`
- **Context**: 驱动决策的问题或需求
- **Alternatives Considered**:
  1. 方案 A — 简述
  2. 方案 B — 简述
- **Selected Approach**: 选定方案及实现方式
- **Rationale**: 选择原因
- **Trade-offs**: 优劣权衡
- **Follow-up**: 实施或测试中需验证的事项

_Repeat for each decision._

## Risks & Mitigations
- Risk 1 — 缓解措施
- Risk 2 — 缓解措施

## References
- [pooltool GitHub](https://github.com/ekiefl/pooltool) — 参考实现
- [Alciatore 碰撞模型论文] — 球-球摩擦碰撞
- [Mathavan 2010] — 库边碰撞脉冲积分模型
