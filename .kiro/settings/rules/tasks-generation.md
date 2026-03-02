# 验证任务生成规则

## Core Principles

### 1. 通道标记必须

每个任务必须标记执行通道:
- `[A]` — 自动化任务（AI/CI 执行）
- `[M]` — 真机测试（用户手动执行）
- `[C]` — 交叉验证（AI 分析测试结果）
- `[F]` — 代码修复（AI 根据验证报告修改代码）

### 2. Natural Language Descriptions
Focus on capabilities and outcomes, not code structure.

**Describe**:
- 要验证什么物理行为
- 与 pooltool 参考的对比标准
- 容差要求和判定标准
- 测试数据来源

**Avoid**:
- 过度的文件路径和目录结构（设计文档中已定义）
- 具体函数签名（设计文档中已定义）

### 3. Task Integration & Progression

**验证任务流程**:
1. Ground Truth 数据准备（Python 脚本）[A]
2. 自动化测试编写与执行 [A]
3. 真机测试执行 [M]
4. 交叉验证分析 [C]
5. 代码修复 [F]（如有偏差）
6. 回归测试 [A]+[M]

**Every task must**:
- Build on previous outputs
- Connect to the overall validation system
- Progress incrementally
- Respect architecture boundaries defined in design.md

**End with integration/convergence tasks**.

### 4. Flexible Task Sizing

**Guidelines**:
- **Major tasks**: Group by validation phase
- **Sub-tasks**: 1-3 hours each
- Balance between too granular and too broad

### 5. Requirements Mapping

**End each task detail section with**:
- `_Requirements: X.X, Y.Y_` — numeric IDs only

### 6. Code-Only Focus (with 真机例外)

**Include**:
- Coding tasks (test scripts, XCTest files)
- Testing tasks (automated execution)
- 真机测试任务（用户执行指引）
- 交叉验证分析任务
- 代码修复任务

**Exclude**:
- Deployment tasks
- Documentation-only tasks
- Marketing/business activities

### 7. 真机测试任务特殊规则

**[M] 任务必须包含**:
- **前置条件**: 设备/App 状态要求
- **操作步骤**: 引用 test-protocol.md 章节
- **判定标准**: PASS / FAIL / DEVIATION 的明确定义
- **结果记录位置**: `test-results/manual/TC-M-XXX.md`

**[M] 任务不可包含**:
- 需要代码修改的步骤（那是 [F] 任务）
- 需要 AI 自动执行的步骤（那是 [A] 任务）

### 8. 修复任务特殊规则

**[F] 任务必须包含**:
- **来源**: cross-validation-report.md 中的 Issue ID
- **参考实现**: pooltool 对应文件和行号
- **验证方式**: 修复后如何验证（重跑哪些测试）

### Optional Test Coverage Tasks

- Mark purely deferrable test work as `- [ ]*`
- Never mark [F] fix tasks or [C] cross-validation as optional

## Task Hierarchy Rules

### Maximum 2 Levels
- **Level 1**: Major tasks (1, 2, 3, 4...)
- **Level 2**: Sub-tasks (1.1, 1.2, 2.1, 2.2...)
- **No deeper nesting**

### Sequential Numbering
- Major tasks MUST increment: 1, 2, 3, 4, 5...
- Sub-tasks reset per major task
- Never repeat major task numbers

### Parallel Analysis (default)
- `(P)` for parallel-capable tasks
- [A] tasks for different modules can often be parallel
- [M] tasks can be parallel with [A] tasks
- [C] tasks depend on [A]+[M] completion
- [F] tasks depend on [C] completion

### Checkbox Format
```markdown
- [ ] 1. Ground Truth 数据生成
- [ ] 1.1 编写四次方程求解测试数据生成脚本 [A](P)
  - 覆盖无实根、重根、极小系数等场景
  - _Requirements: 1.1, 1.2_
- [ ] 1.2 编写碰撞时间计算测试数据生成脚本 [A](P)
  - 覆盖各角度和速度组合
  - _Requirements: 2.1, 2.2_

- [ ] 2. 自动化测试编写与执行
- [ ] 2.1 四次方程求解器 XCTest [A]
  - 加载 JSON 测试数据
  - 容差比较 abs_tol=1e-6
  - _Requirements: 1.1_

- [ ] 3. 真机测试
- [ ] 3.1 单球直线运动验证 [M]
  - **前置条件**: 台面仅一颗球
  - **操作步骤**: 参见 test-protocol.md TC-M-001
  - **结果记录**: test-results/manual/TC-M-001.md
  - **判定标准**: 直线运动、减速自然
  - _Requirements: 4.1_

- [ ] 4. 交叉验证
- [ ] 4.1 生成交叉验证报告 [C]
  - 汇总自动化和真机结果
  - _Requirements: all_

- [ ] 5. 修复迭代
- [ ] 5.1 修复四次方程系数偏差 [F]
  - **来源**: ISSUE-001
  - **参考**: pooltool solve.py L42
  - **验证**: 重跑 2.1
  - _Requirements: 1.1_
```

## Requirements Coverage

**Mandatory Check**:
- ALL requirements from requirements.md MUST be covered
- 每个需求至少对应一个 [A] 或 [M] 任务
- If gaps found: Return to requirements or design phase
