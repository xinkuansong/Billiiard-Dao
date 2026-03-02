# 验证架构设计原则

## Core Design Principles

### 1. 双通道覆盖
- 每个物理模块至少有一个自动化测试或真机测试覆盖
- 纯计算函数优先自动化 [A]
- 涉及渲染/交互的行为使用真机 [M]
- 两个通道的测试应能独立执行

### 2. Ground Truth 管道
- pooltool Python 为唯一 ground truth 来源
- 测试数据通过 JSON 格式在 Python 和 Swift 间传递
- 数据生成脚本可重复运行，结果确定性
- 版本化测试数据，支持回归对比

### 3. 容差设计
- 每个验证模块需定义明确的容差标准
- 容差选择应有依据（参考 pooltool 测试中的容差）
- 区分绝对容差 (abs_tol) 和相对容差 (rel_tol)
- 特殊模块可使用定制容差并记录理由
- 考虑 Float (32-bit) vs Double (64-bit) 的精度差异

### 4. 迭代收敛
- 设计必须支持多轮 验证→修复→回测 迭代
- 每轮产出可追溯的验证报告
- 收敛判定有明确条件（非主观判断）
- 回归测试确保修复不引入新问题

### 5. 真机测试可操作性
- 测试步骤尽量具体（减少模糊指令）
- 判定标准尽量客观（可量化优于主观）
- 结果记录格式统一（模板化）
- 降低用户负担（必要测试才用真机）

### 6. Component Design Rules
- **Single Responsibility**: 每个测试组件验证一个物理模块
- **Clear Boundaries**: 自动化测试与真机测试不混合
- **Data Independence**: 测试数据与测试逻辑分离
- **Repeatability**: 所有测试可重复执行

### 7. Error Handling
- **Fail Fast**: 数据格式不匹配立即报错
- **Graceful Degradation**: 单个测试失败不阻塞其他测试
- **Record Everything**: 即使 DEVIATION 也要记录偏差量
- **Traceability**: 每个失败可追溯到具体需求和代码位置

### 8. 参考实现对照
- 所有物理算法修改必须先对照 pooltool 对应实现
- 偏离参考实现需要明确理由和验证
- 物理常量必须与参考实现一致（或有文档说明差异原因）

## Documentation Standards

### Language and Tone
- **Precise**: 使用具体数值和容差标准
- **Concise**: 避免冗余描述
- **Actionable**: 每个发现需有对应行动

### Structure Requirements
- **Hierarchical**: 按物理模块组织
- **Traceable**: 需求→测试→结果→修复 链路清晰
- **Versioned**: 支持多轮迭代的历史追溯

## Diagram Guidelines

### When to include
- **Architecture**: 测试数据流管道
- **Sequence**: 验证→修复→回测 迭代流程
- **State**: 验证状态机（UNTESTED→TESTING→PASS/FAIL→FIXING→RETESTING）

### Mermaid requirements
- Plain Mermaid only
- Node IDs: alphanumeric plus underscores only
- Edges: show data or control flow direction
