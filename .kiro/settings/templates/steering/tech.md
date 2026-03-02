# Technology Stack

## Architecture

- **双引擎架构**: EventDrivenEngine (离线精确模拟) + PhysicsEngine (SceneKit 实时渲染)
- **MVVM 模式**: SwiftUI + ViewModel + Core（物理/场景/规则）
- **Feature-first 组织**: 按功能模块划分（FreePlay, Training, Course 等）

## Core Technologies

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **3D Rendering**: SceneKit
- **Data**: SwiftData
- **Platform**: iOS 17+

## 物理引擎核心组件

| 组件 | 文件 | 职责 |
|------|------|------|
| 事件驱动引擎 | `EventDrivenEngine.swift` | 主模拟循环，事件排序与调度 |
| 解析运动 | `AnalyticalMotion.swift` | 状态方程解析求解（sliding/rolling/spinning） |
| 碰撞检测 | `CollisionDetector.swift` | CCD 时间求解（球-球/球-库边/球-袋口） |
| 碰撞响应 | `CollisionResolver.swift` | Alciatore 摩擦碰撞模型 |
| 库边碰撞 | `CushionCollisionModel.swift` | Mathavan 2010 脉冲积分模型 |
| 四次方程 | `QuarticSolver.swift` | Ferrari 方法 + Newton-Raphson 精化 |
| 球杆击球 | `CueBallStrike.swift` | 击球冲量与偏移量（squirt）计算 |

## 参考实现 (Python)

| 组件 | 文件 | 用途 |
|------|------|------|
| 碰撞时间求解 | `evolution/event_based/solve.py` | ground truth 对照 |
| 模拟主循环 | `evolution/event_based/simulate.py` | 事件流程参考 |
| 四次方程求解 | `ptmath/roots/quartic.py` | 数值算法参考 |
| 碰撞响应 | `physics/resolve/` | 碰撞模型参考 |
| 测试套件 | `tests/` | 测试用例与验证数据来源 |

## Development Standards

### Type Safety
Swift 强类型，SIMD3<Float> 用于向量运算

### Code Quality
遵循 `.cursor/rules/` 中的项目规则

### Testing
- XCTest 用于 Swift 自动化测试
- pytest 用于 Python 参考验证
- 真机测试用于 SceneKit 渲染和动画验证

## Development Environment

### Required Tools
- Xcode 15+
- Python 3.10+ (conda: pooltool 环境)
- iOS 17+ 设备 (真机测试)

### Common Commands
```bash
# Swift Test: xcodebuild test -scheme BilliardTrainer -destination 'platform=iOS Simulator,name=iPhone 15'
# Python Test: cd pooltool-main && python -m pytest tests/ -v
# Python 交叉验证数据生成: python scripts/generate_test_data.py
```

## Key Technical Decisions

- 事件驱动而非时间步进模拟，确保碰撞精度
- 坐标系适配: pooltool Z-up → SceneKit Y-up
- 浮点精度: Float (32-bit) 而非 Double，需关注数值误差累积

---
_Document standards and patterns, not every dependency_
