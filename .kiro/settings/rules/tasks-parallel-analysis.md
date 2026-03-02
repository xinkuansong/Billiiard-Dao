# 验证任务并行分析规则

## Purpose
为物理引擎验证任务提供一致的并行执行判定方法。

## When to Consider Tasks Parallel
Only mark a task as parallel-capable when **all** of the following are true:

1. **No data dependency** on pending tasks
2. **No conflicting files or shared mutable resources**
3. **No prerequisite review/approval** from another task
4. **Environment/setup work** is already satisfied

## 通道间并行规则

### 同通道并行
- **[A] + [A]**: 不同物理模块的自动化测试可并行
  - 例: 四次方程测试 (P) 与碰撞检测测试 (P)
- **[M] + [M]**: 不同场景的真机测试可并行
  - 用户可按顺序执行，但任务本身无依赖

### 跨通道并行
- **[A] + [M]**: 自动化测试与真机测试可并行
  - AI 执行 [A] 的同时，用户可执行 [M]
- **[C]** 不可并行: 需等待 [A] 和 [M] 完成
- **[F]** 不可并行: 需等待 [C] 完成

### 迭代内并行
- 同一修复迭代内，修复不同模块的 [F] 任务可并行
- 前提: 修改不同文件，无共享资源

## Marking Convention
- Append `(P)` immediately after the channel marker
  - Example: `- [ ] 2.1 [A](P) Build quartic solver tests`
- Apply to both major tasks and sub-tasks when appropriate
- If sequential mode requested, omit `(P)` markers entirely

## Grouping & Ordering Guidelines
- Group parallel tasks under the same parent
- List dependencies in detail bullets
- 明确标注阻塞依赖（如 "Requires ground truth data from 1.1"）

## Quality Checklist
Before marking a task with `(P)`, ensure:

- [ ] Running concurrently won't create merge conflicts
- [ ] Shared state expectations captured in detail bullets
- [ ] Implementation can be tested independently
- [ ] No cross-module side effects during execution

If any check fails, **do not** mark with `(P)` and explain the dependency.

## 特殊并行场景

### Python 数据生成 + Swift 测试框架搭建
- 数据生成 [A](P) 和测试框架搭建 [A](P) 可并行
- 但具体测试用例编写需等待数据生成完成

### 多模块同时验证
- 不同物理模块的完整验证流程可并行
- 但共享的 cross-validation-report 需串行更新
