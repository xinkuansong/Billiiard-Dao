# Utilities

> 代码路径：`BilliardTrainer/Utilities/`
> 文档最后更新：2026-02-27

## 模块定位

Utilities 模块提供工具类与常量定义，包括物理常量（PhysicsConstants）、通用扩展（Extensions）、向量运算扩展（SCNVector3+Extensions）。它不处理业务逻辑，仅提供基础设施支持。

## 入口文件

| 文件 | 职责 | 行数 |
|------|------|------|
| `PhysicsConstants.swift` | 集中定义物理引擎常量：球体/球台/旋转/击球/瞄准/相机/颗星/分离角/球杆/颜色 | ~406 |
| `Extensions.swift` | SwiftUI/Foundation 扩展：Color 预设、View 样式、数值转换、Date/CGPoint/Array/String/Int/TimeInterval/UIColor 扩展、HapticFeedback 枚举 | ~256 |
| `SCNVector3+Extensions.swift` | SceneKit 向量运算扩展：长度、归一化、点积、叉积、运算符重载、绕 Y 轴旋转 | ~68 |

## 核心概念与术语

| 术语 | 含义 |
|------|------|
| BallPhysics | 球体物理参数：直径/半径/质量/弹性/摩擦/阻尼 |
| TablePhysics | 球台物理参数：尺寸/库边/袋口/重力 |
| SpinPhysics | 旋转物理参数：最大旋转速度/摩擦系数/旋转转线速度系数 |
| StrokePhysics | 击球力度参数：最大速度/幂函数指数/死区 |
| AimingSystem | 瞄准系统参数：瞄准线长度/轨迹点数/时间步长 |
| TrainingCameraConfig | 训练相机参数：FOV/zoom/距离/高度/俯角/灵敏度 |
| DiamondSystem | 颗星系统参数：一库/两库/三库系数 |
| SeparationAngle | 分离角参数：纯滚动分离角/高杆/低杆修正 |
| SCNVector3 | SceneKit 三维向量，扩展提供向量运算 |
| spinFriction | 旋转摩擦系数，计算公式：spinFrictionProportionality * radius |

## 端到端流程

```
物理引擎初始化 → 读取 PhysicsConstants → 配置球体/球台参数 →
物理计算使用常量 → 向量运算使用 SCNVector3 扩展 →
UI 展示使用 Extensions 样式与转换
```

## 对外能力（Public API）

- `PhysicsConstants`：所有物理常量结构体（BallPhysics、TablePhysics、SpinPhysics 等）
- `Extensions`：Color 预设（billiardGreen、cushionGreen、woodBrown）、View 样式（cardStyle、primaryButtonStyle）、数值转换（degrees、radians）、Date/CGPoint/Array/String/Int/TimeInterval/UIColor 扩展、HapticFeedback 枚举
- `SCNVector3` 扩展：`length()`、`normalized()`、`dot(_:)`、`cross(_:)`、运算符（+、-、*、/）、`rotatedY(_:)`

## 依赖与边界

- **依赖**：Foundation、SwiftUI、SceneKit、UIKit
- **被依赖**：Core/Physics（PhysicsConstants）、Core/Scene（PhysicsConstants、SCNVector3 扩展）、Core/Aiming（PhysicsConstants）、Features/Training（PhysicsConstants、Extensions）、Features/FreePlay（PhysicsConstants、Extensions）
- **禁止依赖**：不应依赖 Features 或 Core 模块的具体实现

## 与其他模块的耦合点

- **Core/Physics**：PhysicsEngine 使用 PhysicsConstants 的所有常量（BallPhysics、TablePhysics、SpinPhysics、StrokePhysics、CuePhysics）
- **Core/Scene**：BilliardScene 使用 PhysicsConstants 的 TablePhysics、BallPhysics，使用 SCNVector3 扩展进行向量运算
- **Core/Aiming**：AimingSystem 使用 PhysicsConstants 的 AimingSystem、DiamondSystem、SeparationAngle
- **Features/Training**：TrainingViewModel 使用 PhysicsConstants 的 TrainingCameraConfig，使用 Extensions 的 View 样式

## 关键数据结构

| 结构/枚举 | 字段/Case | 单位/生命周期 |
|-----------|-----------|---------------|
| BallPhysics | diameter: 0.05715m, mass: 0.170kg, restitution: 0.95 | 静态常量，SI 单位 |
| TablePhysics | outerLength: 2.54m, outerWidth: 1.27m, gravity: 9.81m/s² | 静态常量，SI 单位 |
| SpinPhysics | spinFrictionProportionality: 0.444, spinFriction: 0.01269 | 静态常量，计算公式：spinFriction = proportionality * radius |
| StrokePhysics | maxVelocity: 6.5m/s, powerGamma: 1.8, deadZone: 2.0 | 静态常量，SI 单位 |
| TrainingCameraConfig | aimFov: 40°, standFov: 36°, aimRadius: 1.05m, standRadius: 1.55m | 静态常量，SI 单位 |
| SCNVector3 | x, y, z: Float | SceneKit 向量类型 |

## 最近变更记录

| 日期 | 变更摘要 | 影响面 |
|------|----------|--------|
| 2026-02-27 | 创建模块文档 | 无 |
