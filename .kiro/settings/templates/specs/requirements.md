# 验证需求文档

## Introduction
{{INTRODUCTION}}

## 验证范围

### 参考基线
- **Python 参考实现**: pooltool-main (`pooltool/`)
- **Swift 待验证实现**: BilliardTrainer (`BilliardTrainer/Core/Physics/`)

### 验证模块映射

| 验证模块 | Swift 文件 | Python 参考 | 测试通道 |
|----------|-----------|-------------|---------|
| {{MODULE}} | {{SWIFT_FILE}} | {{PYTHON_REF}} | 自动化 / 真机 |

## Requirements

### Requirement 1: {{PHYSICS_MODULE_1}}
<!-- Requirement headings MUST include a leading numeric ID only -->
**Objective:** As a 物理引擎验证者, I want {{CAPABILITY}}, so that {{BENEFIT}}

#### Acceptance Criteria
1. When [给定输入参数], the [Swift 实现] shall [产出与 Python 参考一致的输出（容差范围内）]
2. When [边界条件/极端输入], the [Swift 实现] shall [保持数值稳定，不产生 NaN/Inf]
3. The [Swift 实现] shall [在所有测试用例上与 Python 参考的输出差异不超过指定容差]

#### 测试通道
- [ ] 自动化测试 (XCTest): {{自动化可覆盖的验证点}}
- [ ] 真机测试: {{需要设备验证的项目}}

#### 验证数据规格
- **输入数据来源**: pooltool pytest 测试用例 / 自定义参数矩阵
- **容差标准**: 绝对容差 {{ABS_TOL}} / 相对容差 {{REL_TOL}}
- **Ground Truth 生成**: `python -c "from pooltool... "`

### Requirement 2: {{PHYSICS_MODULE_2}}
**Objective:** As a 物理引擎验证者, I want {{CAPABILITY}}, so that {{BENEFIT}}

#### Acceptance Criteria
1. When [event], the [system] shall [response/action]
2. When [event] and [condition], the [system] shall [response/action]

#### 测试通道
- [ ] 自动化测试 (XCTest)
- [ ] 真机测试

#### 验证数据规格
- **输入数据来源**:
- **容差标准**:
- **Ground Truth 生成**:

<!-- Additional requirements follow the same pattern -->

## 真机测试协议概要

### 需要真机测试的场景
<!-- 列出无法通过自动化覆盖、需要人工观察的验证项 -->
1. SceneKit 渲染正确性（球运动轨迹视觉一致）
2. 动画流畅度与帧率
3. 碰撞时的视觉/音效同步
4. 球杆击球交互响应

### 真机测试结果记录位置
- 路径: `.kiro/specs/{{FEATURE}}/test-results/manual/`
- 格式: 遵循 `test-results.md` 模板
