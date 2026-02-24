# 实施计划：物理调优 (Physics Tuning)

**分支**: `10-physics-tuning` | **日期**: 2025-02-20 | **规格**: [spec.md](./spec.md)  
**状态**: 草案 (Draft)  
**说明**: 物理参数校准方法论、参考数据来源与测试策略

---

## 摘要

本计划在既有 EventDrivenEngine、AnalyticalMotion、CollisionResolver 架构之上，通过**参数可配置化**、**参考数据校准**、**主观手感测试**三条路径，完成旋转、碰撞、轨迹预测与障碍检测的精细化调优。

---

## 技术上下文

**语言/版本**: Swift 5.x  
**目标平台**: iOS 17+  
**物理模块**: `current_work/BilliardTrainer/Core/Physics/`  
**常量定义**: `Utilities/Constants/PhysicsConstants.swift`  
**约束**: 不改变核心物理算法，仅调整参数与扩展 UI 逻辑

---

## 1. 参数调优方法论

### 1.1 参数可配置化

- **原则**: 所有待校准参数从 PhysicsConstants 或专门配置结构体读取，避免硬编码
- **实现**: 在 PhysicsConstants 中新增或扩展 `SpinPhysics`、`TablePhysics`、`BallPhysics` 的可调项
- **可选**: 若需运行时调参，可引入 `PhysicsTuningConfig` 单例，供调试面板或未来「手感偏好」功能使用

### 1.2 单参数扫描法

- **步骤**:
  1. 选定基准场景（如：高杆正碰目标球、侧旋碰库、多库反弹）
  2. 固定其他参数，仅改变目标参数（如 spinTransferRate）
  3. 记录物理输出（分离角、反弹角、轨迹长度等）
  4. 与参考值对比，选取使误差最小的参数值
- **工具**: 可编写 XCTest 或 Swift Playground 脚本，批量运行并导出 CSV

### 1.3 正交实验法（多参数联合调优）

- **场景**: 当单参数扫描后仍有偏差，考虑参数耦合
- **示例**: spinDecayRate 与 spinTransferRate 可能共同影响「高杆跟进行程」
- **方法**: 选取 2–3 个关键参数，做 3×3 或 2×2 正交表，遍历组合，选取综合误差最小的组合

### 1.4 迭代校准流程

```
参考数据/文献 → 设定初值 → 单参数扫描 → 与实测/文献对比 → 调整
     ↑                                                          ↓
     └────────────────── 若偏差仍大，多参数联合调优 ←─────────────┘
```

---

## 2. 参考数据来源

### 2.1 旋转参数

| 参数 | 参考来源 | 说明 |
|------|----------|------|
| spinDecayRate | pooltool、Alciatore 附录 | 角速度衰减与 spinFriction 相关，可反推等效 decay |
| spinTransferRate | Alciatore 球-球碰撞、实验视频 | 碰撞时角速度传递比例，文献常给 0.2–0.4 范围 |
| englishCushionEffect | Mathavan 2010 扩展、颗星公式 | 侧旋对反弹角修正，需结合 cushionSpinCorrectionFactor |

### 2.2 碰撞参数

| 参数 | 参考来源 | 说明 |
|------|----------|------|
| cushionRestitution | Mathavan 2010、台球桌厂商规格 | 常见 0.75–0.90，新台布偏大 |
| ballBallRestitution | Alciatore、标准酚醛球 | 通常 0.92–0.98 |
| clothFriction | pooltool、台呢厂商 | 常见 0.15–0.25 |

### 2.3 分离角与杆法

| 现象 | 参考 | 说明 |
|------|------|------|
| 纯滚动分离角 | 90° | 理论值 |
| 高杆分离角 | -15° ~ -25° 修正 | SeparationAngle.topSpinCorrection |
| 低杆分离角 | +15° ~ +25° 修正 | SeparationAngle.backSpinCorrection |

### 2.4 可选的实球验证

- 若有条件：使用高速摄像或慢动作拍摄实球轨迹，提取关键帧位置，与模拟轨迹对比
- 简化版：邀请有经验的台球爱好者进行盲测，对比「模拟 vs 实球」的主观一致性

---

## 3. 物理手感测试策略

### 3.1 标准测试场景

| 场景 ID | 描述 | 观测指标 |
|---------|------|----------|
| S1 | 高杆正碰 1 号球，母球跟进 | 母球碰后位移、分离角 |
| S2 | 低杆正碰 1 号球，母球拉回 | 母球碰后位移、分离角 |
| S3 | 纯侧旋碰库（无高/低杆） | 反弹角偏移量 |
| S4 | 中杆两库颗星 | 第二库反弹角、落点 |
| S5 | 轻杆 vs 重杆走位 | 球速衰减曲线、停球位置 |
| S6 | 瞄准线被阻挡 | 阻挡提示是否正确显示 |

### 3.2 主观评分维度

| 维度 | 说明 | 评分 1–5 |
|------|------|----------|
| 球速自然度 | 轻/中/重杆速度差异是否合理 | |
| 旋转可见度 | 塞球效果是否明显但不过度 | |
| 库边真实感 | 反弹角度与能量损失 | |
| 碰撞真实感 | 球-球碰撞传递 | |
| 轨迹预测可信度 | 预测线与实际线的吻合度 | |
| 整体一致性 | 与实球手感对比 | |

### 3.3 自动化回归测试

- **目标**: 参数修改后不引入明显回归
- **实现**: XCTest 用例固定初状态与击球参数，断言关键输出（如碰后速度模、分离角）在允许范围内
- **位置**: `BilliardTrainerTests/Physics/` 或等效目录

---

## 4. 轨迹预测 UI 优化方案

### 4.1 当前实现回顾

- `BilliardSceneViewModel.updateTrajectoryPreview()`: 简化几何计算（单次碰撞 + 近似 90° 分离）
- `BilliardScene.showPredictedTrajectory()`: 虚线点序列展示母球与目标球路径
- `PhysicsEngine.predictTrajectory()`: 完整 AnalyticalMotion + CCD 预测，当前未在瞄准 UI 中完全使用

### 4.2 优化方向

1. **接入完整物理预测**: 用 `PhysicsEngine.predictTrajectory` 或 EventDrivenEngine 的模拟结果替代简化几何，支持多库
2. **视觉区分**: 母球路径（如白色/浅蓝）、目标球路径（如黄色）、多库分段（可按库数渐变透明度）
3. **性能**: 预测计算放后台线程，结果缓存；若计算耗时 > 50ms，可降采样或缩短预测步数
4. **预测 vs 实际**: 击球后回放时，用不同样式（如实线 vs 虚线）叠加显示预测与实际轨迹，便于对比

---

## 5. 障碍球检测实现方案

### 5.1 检测逻辑

1. **射线**: 从母球中心沿瞄准方向发射射线
2. **碰撞顺序**: 按距离排序，第一个与射线相交且距离 < 母球到目标球距离的球为障碍球
3. **相交判断**: 球心到射线距离 < 球半径则视为相交（或使用射线-球体相交公式）
4. **目标球排除**: 若射线首先击中目标球，则无障碍

### 5.2 数据结构

- 输入：母球位置、瞄准方向、目标球（可选）、所有其他球位置
- 输出：`ObstacleDetectionResult { hasObstacle: Bool, obstructingBall: Ball?, distance: Float }`

### 5.3 视觉反馈

- 阻挡时：瞄准线变色（如红/橙）、或显示「阻挡」图标、或轻微闪烁
- 不阻挡：保持现有瞄准线样式

### 5.4 集成位置

- `BilliardSceneViewModel` 或 `AimingSystem` 中新增 `detectObstacle()` 调用
- 在 `updateTrajectoryPreview()` 或 `showAimLine()` 逻辑中根据检测结果切换 UI 状态

---

## 6. 项目结构与依赖

```
specs/10-physics-tuning/
├── spec.md
├── plan.md
└── tasks.md

current_work/BilliardTrainer/
├── Core/Physics/
│   ├── PhysicsEngine.swift          # 轨迹预测增强
│   ├── CollisionResolver.swift      # 旋转传递可调
│   ├── CushionCollisionModel.swift  # 侧旋库边 effect
│   └── ...
├── Core/Scene/
│   ├── BilliardScene.swift         # 轨迹 UI、障碍提示
│   └── ...
├── Features/Training/
│   └── ViewModels/
│       └── BilliardSceneViewModel.swift  # updateTrajectoryPreview、障碍检测
└── Utilities/Constants/
    └── PhysicsConstants.swift      # 新增/调整参数
```

### 依赖关系

- 旋转/碰撞调参 → 不依赖 UI，可独立进行
- 轨迹预测 UI → 依赖 PhysicsEngine.predictTrajectory 或 EventDrivenEngine
- 障碍检测 → 独立于物理，可并行开发

---

## 7. 风险与缓解

| 风险 | 缓解 |
|------|------|
| 参考数据不足 | 以文献典型值为初值，依赖主观测试迭代 |
| 调参组合爆炸 | 优先单参数扫描，仅对关键参数做正交 |
| 轨迹预测性能 | 降采样、异步计算、缓存最近结果 |
| 障碍检测误判 | 使用保守阈值（如 1.01*radius），避免边缘穿透误报 |
