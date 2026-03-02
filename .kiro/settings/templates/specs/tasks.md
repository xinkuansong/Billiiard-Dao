# 验证实施计划

## Task Format Template

### 标记说明
- `(P)` - 可并行执行的任务
- `[A]` - 自动化测试任务（AI/CI 执行）
- `[M]` - 真机测试任务（用户执行）
- `[F]` - 代码修复任务
- `[C]` - 交叉验证任务

### Major task only
- [ ] {{NUMBER}}. {{TASK_DESCRIPTION}} {{CHANNEL_MARK}}{{PARALLEL_MARK}}
  - {{DETAIL_ITEM_1}} *(Include details only when needed)*
  - _Requirements: {{REQUIREMENT_IDS}}_

### Major + Sub-task structure
- [ ] {{MAJOR_NUMBER}}. {{MAJOR_TASK_SUMMARY}}
- [ ] {{MAJOR_NUMBER}}.{{SUB_NUMBER}} {{SUB_TASK_DESCRIPTION}} {{CHANNEL_MARK}}{{PARALLEL_MARK}}
  - {{DETAIL_ITEM_1}}
  - {{DETAIL_ITEM_2}}
  - _Requirements: {{REQUIREMENT_IDS}}_

### 真机测试任务格式
- [ ] {{NUMBER}}. {{TASK_DESCRIPTION}} [M]
  - **前置条件**: {{PRECONDITIONS}}
  - **操作步骤**: 参见 `test-protocol.md` 第 {{SECTION}} 节
  - **结果记录**: 写入 `test-results/manual/{{RESULT_FILE}}`
  - **判定标准**: {{PASS_CRITERIA}}
  - _Requirements: {{REQUIREMENT_IDS}}_

### 交叉验证任务格式
- [ ] {{NUMBER}}. {{TASK_DESCRIPTION}} [C]
  - **输入**: 自动化结果 `test-results/automated/` + 真机结果 `test-results/manual/`
  - **输出**: `cross-validation-report.md`
  - **动作**: 识别 FAIL/DEVIATION 项，生成修复建议
  - _Requirements: {{REQUIREMENT_IDS}}_

### 修复迭代任务格式
- [ ] {{NUMBER}}. {{TASK_DESCRIPTION}} [F]
  - **来源**: `cross-validation-report.md` 第 {{ISSUE_ID}} 项
  - **修复范围**: {{AFFECTED_FILES}}
  - **验证方式**: 重跑对应自动化测试 / 请求用户重新真机测试
  - _Requirements: {{REQUIREMENT_IDS}}_

## 典型任务流程

```
1. Ground Truth 数据生成 [A]
2. XCTest 自动化测试编写与执行 [A]
3. 真机测试执行 [M] — 用户执行
4. 交叉验证分析 [C]
5. 代码修复 [F] — 基于验证报告
6. 回归测试 [A] + [M] — 验证修复效果
```

> **Parallel marker**: Append ` (P)` only to tasks that can be executed in parallel.
> **Channel marker**: `[A]`/`[M]`/`[C]`/`[F]` indicates the execution channel.
> **Optional test coverage**: When a sub-task is deferrable, mark as `- [ ]*`.
