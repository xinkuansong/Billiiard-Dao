# Project Structure

## Organization Philosophy

Feature-first + Core 分层：功能模块独立开发，共享物理/场景/规则核心层。

## Directory Patterns

### Core Physics
**Location**: `BilliardTrainer/Core/Physics/`
**Purpose**: 物理引擎核心算法（碰撞检测、运动方程、四次方程求解）
**Example**: `QuarticSolver.swift`, `CollisionDetector.swift`

### Core Scene
**Location**: `BilliardTrainer/Core/Scene/`
**Purpose**: SceneKit 场景管理、球桌模型、相机控制
**Example**: `TableModelLoader.swift`, `SceneSetup.swift`

### Core Rules
**Location**: `BilliardTrainer/Core/Rules/`
**Purpose**: 台球规则（8球、9球等）
**Example**: `EightBallManager.swift`

### Features
**Location**: `BilliardTrainer/Features/<FeatureName>/`
**Purpose**: 按功能划分的独立模块，包含 View + ViewModel
**Example**: `Features/FreePlay/`, `Features/Training/`

### Reference Implementation
**Location**: `pooltool-main/`
**Purpose**: Python 物理引擎参考基线，不直接修改
**Example**: `pooltool/evolution/event_based/solve.py`

### Test Data
**Location**: `BilliardTrainerTests/`
**Purpose**: XCTest 自动化测试和交叉验证数据
**Example**: `QuarticSolverTests.swift`

### Specs (SDD)
**Location**: `.kiro/specs/<feature-name>/`
**Purpose**: 规格驱动开发的 spec 文件
**Example**: `.kiro/specs/quartic-solver-validation/`

## Naming Conventions

- **Swift Files**: PascalCase (e.g., `CollisionDetector.swift`)
- **Python Files**: snake_case (e.g., `collision_detector.py`)
- **Spec Features**: kebab-case (e.g., `ball-ball-collision`)
- **Test Files**: `<Module>Tests.swift` or `test_<module>.py`

## Import Organization

```swift
import Foundation
import SwiftUI
import SwiftData
import SceneKit
import UIKit
import Combine
```

## Code Organization Principles

- Core/Physics 层不依赖 UI 框架（不 import SwiftUI/UIKit）
- Features 层通过 ViewModel 调用 Core 层 API
- 物理引擎改动必须先对照 pooltool-main 参考实现
- 敏感区域（QuarticSolver、CollisionDetector 等）修改需回归验证

---
_Document patterns, not file trees. New files following patterns shouldn't require updates_
