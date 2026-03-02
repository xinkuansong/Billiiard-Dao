# Product Overview

BilliardTrainer 是一款 iOS 台球训练应用，使用 SceneKit 构建 3D 场景，内含自研的事件驱动物理引擎模拟台球运动。

## Core Capabilities

- **事件驱动物理模拟**: 基于解析运动方程 + 连续碰撞检测（CCD），精确预测球的运动轨迹
- **真实碰撞物理**: 包含球-球摩擦碰撞（Alciatore 模型）、球-库边碰撞（Mathavan 2010 模型）、袋口检测
- **3D 可视化训练**: 通过 SceneKit 渲染实时轨迹预测和回放动画
- **瞄准辅助系统**: 钻石系统（Diamond System）辅助瞄准与走位分析

## Target Use Cases

- 台球爱好者通过模拟器学习击球角度、力度和走位
- 验证不同击球参数（cue tip offset、速度、角度）对球路的影响
- 训练和学习各种台球技术（旋转球、翻袋等）

## 参考实现

- **pooltool-main** (Python): 开源台球物理模拟器，作为本项目物理引擎的参考基线
- 所有物理算法应与 pooltool 保持数值一致性
- pooltool 使用 Z-up 坐标系，BilliardTrainer 使用 Y-up（SceneKit 默认）

## Value Proposition

- 移动端原生体验，离线可用
- 物理引擎经过参考实现验证，确保模拟准确性
- 轨迹预测和回放功能帮助用户理解物理原理

---
_Focus on patterns and purpose, not exhaustive feature lists_
