# 测试策略

## 测试架构

### 双通道验证

| 通道 | 框架 | 执行者 | 覆盖范围 |
|------|------|--------|---------|
| 自动化 | XCTest (Swift) + pytest (Python) | AI / CI | 数值计算、碰撞检测、状态转换 |
| 真机 | iOS Device | 用户 | 渲染效果、交互响应、帧率 |

### 交叉验证

- Python (pooltool) 输出作为 ground truth
- Swift 实现输出与 ground truth 对比
- 容差内一致视为 PASS
- 超出容差需分析根因

## 自动化测试规范

### XCTest 组织
```
BilliardTrainerTests/
├── Physics/
│   ├── QuarticSolverTests.swift
│   ├── CollisionDetectorTests.swift
│   ├── CollisionResolverTests.swift
│   ├── AnalyticalMotionTests.swift
│   ├── CushionCollisionModelTests.swift
│   └── CueBallStrikeTests.swift
├── Integration/
│   └── EventDrivenEngineTests.swift
└── TestData/
    ├── quartic_test_data.json
    ├── collision_time_test_data.json
    └── ...
```

### 测试数据格式
- JSON 格式
- 每个文件包含模块名、测试用例数组
- 每个用例包含输入参数、期望输出、容差

### 容差标准
| 模块 | 绝对容差 | 相对容差 | 理由 |
|------|---------|---------|------|
| 四次方程求解 | 1e-6 | 1e-4 | Float 精度限制 |
| 碰撞时间 | 1e-6 | 1e-4 | 时间精度要求 |
| 碰撞响应速度 | 1e-4 | 1e-3 | 向量分量容差 |
| 位置演化 | 1e-4 | 1e-3 | 累积误差 |

### Python Ground Truth 生成
- 使用 conda `pooltool` 环境
- 脚本位于 `BilliardTrainerTests/TestData/generate/`
- 输出到 `BilliardTrainerTests/TestData/`
- 每次生成记录 pooltool 版本

## 真机测试规范

### 测试环境
- Debug build，开启 FPS 显示
- 固定设备型号和 iOS 版本
- 每次测试前重启 App

### 结果记录
- 遵循 test-results.md 模板
- 附截图/录屏（关键场景）
- 路径: `.kiro/specs/<feature>/test-results/manual/`

### 判定标准
- PASS: 完全符合预期
- FAIL: 明显错误（物理不合理、崩溃、穿越）
- DEVIATION: 略有偏差但物理上合理

## 回归测试

### 触发条件
- 任何 Physics 模块代码修改
- 敏感区域文件修改
- 物理常量调整

### 回归范围
- 修改模块的全部单元测试
- 事件驱动引擎集成测试
- 相关真机测试场景
