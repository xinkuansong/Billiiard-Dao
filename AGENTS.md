# Physics Engine Spec-Driven Validation

基于 Kiro-style Spec Driven Development 的台球物理引擎跨实现验证框架。

## 项目目标

将 BilliardTrainer (Swift) 物理引擎与 pooltool-main (Python) 参考实现进行系统性对照验证，通过自动化测试 + 真机测试双通道覆盖所有物理模块，确保两者行为一致。

## Project Context

### Paths
- Steering: `.kiro/steering/`
- Specs: `.kiro/specs/`
- 测试结果: `.kiro/specs/<feature>/test-results/`
- 交叉验证报告: `.kiro/specs/<feature>/cross-validation-report.md`

### Steering vs Specification

**Steering** (`.kiro/steering/`) - 项目级的持久上下文与规则
**Specs** (`.kiro/specs/`) - 单个验证特性的完整规格流程

### Active Specifications
- Check `.kiro/specs/` for active specifications
- Use `/kiro/spec-status [feature-name]` to check progress

## Development Guidelines
- Think in English, generate responses in Simplified Chinese. All Markdown content written to project files MUST be written in the target language configured for this specification (see spec.json.language).

## 验证工作流

### 两种测试通道

| 通道 | 方式 | 适用范围 | 执行者 |
|------|------|---------|--------|
| **自动化测试** | XCTest (Swift) + pytest (Python) | 纯计算函数、数值输出对比 | AI/CI |
| **真机测试** | iOS 设备运行 + 人工观察记录 | 视觉效果、动画流畅度、SceneKit 渲染 | 用户 |

### 交叉验证原则

1. **Python 为真值基线**: pooltool-main 的输出作为 ground truth
2. **数值容差**: 浮点比较使用可配置的绝对/相对容差
3. **测试数据共享**: Python 端生成测试用例数据，Swift 端消费并比对
4. **结果归档**: 每次验证结果写入指定位置，形成可追溯记录

## Workflow (Minimal)

- Phase 0 (可选): `/kiro/steering`, `/kiro/steering-custom`
- Phase 1 (规格定义):
  - `/kiro/spec-init "description"` — 初始化验证规格
  - `/kiro/spec-requirements {feature}` — 生成验证需求
  - `/kiro/validate-gap {feature}` (推荐: 分析 Swift vs pooltool 差距)
  - `/kiro/spec-design {feature} [-y]` — 设计测试架构
  - `/kiro/validate-design {feature}` (可选: 设计评审)
  - `/kiro/spec-tasks {feature} [-y]` — 生成验证任务
- Phase 2 (执行验证):
  - `/kiro/spec-impl {feature} [tasks]` — 执行自动化测试任务
  - **真机测试**: 用户按 test-protocol.md 执行，结果写入 `test-results/`
  - `/kiro/cross-validate {feature}` — 分析测试结果，生成交叉验证报告
- Phase 3 (修复迭代):
  - 根据报告修复代码 → 重新测试 → 直到收敛
- Progress check: `/kiro/spec-status {feature}` (use anytime)

## Development Rules
- 3-phase approval workflow: Requirements → Design → Tasks → Implementation
- Human review required each phase; use `-y` only for intentional fast-track
- Keep steering current and verify alignment with `/kiro/spec-status`
- 涉及物理引擎改动时，必须先对照 pooltool-main 对应实现
- 真机测试结果由用户写入，AI 不可伪造或猜测真机测试数据

## 测试结果记录规范

### 自动化测试结果
- XCTest: 通过 xcodebuild test 自动收集
- pytest: 通过 pytest --json-report 自动收集
- 结果写入 `.kiro/specs/<feature>/test-results/automated/`

### 真机测试结果
- 用户按 `test-protocol.md` 中的步骤执行
- 结果写入 `.kiro/specs/<feature>/test-results/manual/`
- 格式遵循 `test-results.md` 模板

## Steering Configuration
- Load entire `.kiro/steering/` as project memory
- Default files: `product.md`, `tech.md`, `structure.md`
- Custom files: `testing.md` (测试策略)

## 运行环境 (Environment)

### Python / pooltool

- **虚拟环境路径**: `<project_root>/.venv`
- **Python 版本**: 3.12.12（pooltool 不支持 3.14，需用 3.12）
- **pooltool 版本**: 0.5.0

**激活与验证**:
```bash
cd <project_root>
source .venv/bin/activate
python -c "import pooltool; print(pooltool.__version__)"
```

**执行 pytest / pooltool 相关脚本前**，必须先 `source .venv/bin/activate`。
