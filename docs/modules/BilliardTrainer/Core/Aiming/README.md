# Aiming（瞄准系统）

> 代码路径：`BilliardTrainer/Core/Aiming/`
> 文档最后更新：2026-02-27

## 模块定位

瞄准计算系统，提供瞄准点计算、分离角预测、走位分析、颗星公式等功能。不处理相机控制（由 Camera 模块负责），不处理物理模拟（由 Physics 模块负责）。

## 入口文件

| 文件 | 职责 | 行数 |
|------|------|------|
| `AimingSystem.swift` | 瞄准系统：计算瞄准点、分离角、走位预测、路径遮挡检测、可行袋口分析 | 392 |
| `DiamondSystem.swift` | 颗星公式系统：一库/两库/三库翻袋和K球计算，颗星位置映射 | 373 |

## 核心概念与术语

| 术语 | 含义 |
|------|------|
| AimResult | 瞄准结果：包含瞄准点、瞄准方向、厚度、分离角、母球预计停止位置、是否可进袋、难度评分 |
| Ghost Ball（幽灵球） | 目标球到袋口方向的反向 2R 位置，用于计算瞄准点 |
| Thickness（厚度） | 0-1 值，1 为正撞（全厚），0 为完全擦边，表示切入角度 |
| Separation Angle（分离角） | 母球碰撞后的分离角度（度），受厚度和杆法影响 |
| Squirt Angle（偏移角） | 侧旋（左右塞）导致的方向偏移角度，需要修正瞄准方向 |
| Diamond System（颗星公式） | 利用台面颗星标记计算翻袋和K球路径的系统 |
| Bank Shot（翻袋） | 通过库边反弹进袋的击球方式 |
| Kick Shot（K球） | 通过库边反弹击中目标球的击球方式 |
| Mirror Method（镜像法） | 通过镜像袋口位置计算翻袋点的方法 |

## 端到端流程

```
输入（母球位置、目标球位置、袋口位置、杆法参数） → AimingCalculator.calculateAim() → 计算幽灵球中心 → 计算瞄准点 → 应用 squirt 修正 → 计算厚度 → 计算分离角 → 预测母球停止位置 → 检查路径遮挡 → 返回 AimResult
```

### 颗星公式流程

```
输入（母球位置、目标位置、库边） → DiamondSystemCalculator.calculateOneRailBank/calculateTwoRailKick/calculateThreeRailPath() → 计算出发点颗星 → 计算目标点颗星 → 应用颗星公式 → 计算第一库接触点 → 返回 DiamondResult
```

## 对外能力（Public API）

- `AimingCalculator.calculateAim()`：计算从母球到目标球进袋的完整瞄准信息
- `AimingCalculator.ghostBallCenter()`：计算幽灵球中心位置
- `AimingCalculator.isPathOccluded()`：判断路径是否被其他球遮挡
- `AimingCalculator.viablePockets()`：分析可行袋口列表（按难度排序）
- `AimingCalculator.calculateThickness()`：计算厚度（切入角度）
- `AimingCalculator.calculateSeparationAngle()`：计算分离角（考虑杆法修正）
- `AimingCalculator.predictCueBallPosition()`：预测母球碰撞后的停止位置
- `DiamondSystemCalculator.calculateOneRailBank()`：一库翻袋计算
- `DiamondSystemCalculator.calculateTwoRailKick()`：两库K球计算
- `DiamondSystemCalculator.calculateThreeRailPath()`：三库路径计算
- `BankShotCalculator.calculateBankShot()`：使用镜像法计算翻袋瞄准点

## 依赖与边界

- **依赖**：
  - `BallPhysics`（球的物理常量：半径）
  - `CueBallStrike`（杆法计算：squirt 角）
  - `SeparationAngle`（分离角常量：纯滚动分离角、高杆/低杆修正）
  - `Pocket`（袋口数据结构）
  - `TablePhysics`（台面物理常量：尺寸）
  - `DiamondSystem`（颗星系统常量：三库因子等）
- **被依赖**：
  - `BilliardSceneView`（场景视图，用于显示瞄准线/轨迹）
  - `TrainingViewModel`（训练视图模型，用于瞄准辅助）
- **禁止依赖**：
  - 不依赖 `Physics` 模块的实时物理状态（仅使用静态计算）
  - 不依赖 `Camera` 模块（瞄准计算与相机控制分离）

## 与其他模块的耦合点

- **Scene 层（BilliardSceneView）**：使用 `AimResult` 显示瞄准线和轨迹预览，耦合点在于数据结构格式
- **Physics 模块**：读取 `BallPhysics.radius` 等常量，耦合点在于物理常量的一致性
- **Training 模块**：`TrainingViewModel` 调用瞄准计算提供瞄准辅助，耦合点在于 API 接口稳定性

## 关键数据结构

| 结构/枚举 | 字段/Case | 单位/生命周期 |
|-----------|-----------|---------------|
| `AimResult` | aimPoint（米）, aimDirection（归一化向量）, thickness（0-1）, separationAngle（度）, cueBallEndPosition（米，可选）, canPocket（Bool）, difficulty（1-5） | 计算结果 |
| `PositionZone` | center（米）, radius（米）, rating（1-5） | 走位区域评分 |
| `DiamondPosition` | edge（TableEdge）, number（颗星编号，0-based）, worldPosition（米） | 颗星位置 |
| `DiamondResult` | startDiamond, firstRailDiamond, targetDiamond（可选）, recommendedEnglish（-1到1）, recommendedPower（0-1）, formula（String） | 颗星计算结果 |
| `TableEdge` | top, bottom, left, right | 台面边 |

## 最近变更记录

| 日期 | 变更摘要 | 影响面 |
|------|----------|--------|
| 2026-02-27 | 初始文档创建 | 无（新建文档） |
