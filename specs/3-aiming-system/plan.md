# 实现计划：瞄准系统 (Aiming System)

**分支**：`3-aiming-system` | **日期**：2025-02-20 | **规格**：[spec.md](./spec.md)  
**状态**：已完成 (回溯记录)

## 摘要

瞄准系统提供几何瞄准计算与颗星公式，采用幽灵球法计算进袋瞄准点，采用颗星公式计算翻袋与 K 球击球点。支持塞修正、速度修正与分离角计算，用于走位与难度评估。

## 技术背景

**语言/版本**：Swift 5.x  
**主要依赖**：SceneKit（向量运算）, Foundation  
**目标平台**：iOS 15+  
**项目类型**：移动端应用 (BilliardTrainer)  
**数据**：纯计算，无持久化，输入为 SCNVector3 位置

## 技术决策

### 1. 幽灵球法

- **决策**：使用幽灵球法计算进袋瞄准
- **原因**：几何直观，与职业教学一致，易于可视化
- **实现**：假想球中心 = 目标球中心 - (目标球到袋口方向 × 2R)

### 2. 颗星公式

- **决策**：采用数学颗星公式（diamond system）计算翻袋与 K 球
- **原因**：标准化、可复现，适合程序化计算
- **实现**：
  - 一库：第一库颗星 = (出发点颗星 - 目标点颗星) / 2
  - 两库：第一库颗星 = (出发点颗星 + 目标点颗星) / 2
  - 三库：简化版，使用固定系数

### 3. 塞修正 (English Correction)

- **决策**：颗星计算中根据角度推荐塞（左塞/右塞/反塞）
- **原因**：塞会改变库边反射后的球路，影响颗星落点
- **实现**：calculateEnglishCorrection(startDiamond, targetDiamond) 返回 -1~1

### 4. 速度修正 (Speed Correction)

- **决策**：力度影响颗星长距离走位，需补偿
- **原因**：大力时球路更长，颗星数需减少；小力时需增加
- **实现**：calculateSpeedCorrection(power) 返回颗星调整量

### 5. Squirt 角修正

- **决策**：侧旋（左右塞）导致击球方向偏移，需在瞄准方向中修正
- **原因**：皮头偏离中心会产生 squirt，影响实际击球线
- **实现**：CueBallStrike.squirtAngle(a: spinX) 返回偏移角，对 aimDirection 绕 Y 轴旋转

## 项目结构

### 文档

```text
specs/3-aiming-system/
├── spec.md
├── plan.md
└── tasks.md
```

### 源码

```text
current_work/BilliardTrainer/
└── Core/
    └── Aiming/
        ├── AimingSystem.swift   # AimingCalculator, 幽灵球/分离角/走位
        └── DiamondSystem.swift  # DiamondSystemCalculator, 颗星公式
```

## 计算流程

### 瞄准计算 (calculateAim)

1. 计算目标球到袋口方向 → ballToPocket
2. 计算瞄准点 = 目标球 - ballToPocket × 2R
3. 计算母球到瞄准点方向 → aimDirection
4. 应用 squirt 角修正（若 spinX ≠ 0）
5. 计算厚度 thickness
6. 计算分离角 separationAngle
7. 预测母球停止位置
8. 判断是否可进袋、计算难度

### 颗星计算

- **DiamondPosition**：边（top/bottom/left/right）+ 颗星编号（0-8 或 0-4）
- **positionToDiamond**：世界坐标 → 颗星数
- **nearestEdge**：找到球最近的库边
- **pocketEdge**：袋口所在边
