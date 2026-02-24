# 任务列表：物理调优 (Physics Tuning)

**输入**: `specs/10-physics-tuning/` 下的设计文档  
**状态**: 草案 (Draft)  
**说明**: 所有任务初始状态为未完成 [ ]

## 格式：`- [ ] TXXX [P?] [US?] 描述（文件路径）`

- **[P]**: 可并行执行（不同文件，无依赖）
- **[USn]**: 所属用户故事（US1–US5）
- 路径基于 `current_work/BilliardTrainer/`

---

## 阶段 1：参数可配置化

**目的**: 将待调参数集中到 PhysicsConstants，便于校准

- [ ] T001 [P] [US1] 在 SpinPhysics 中新增 spinDecayRate、spinTransferRate、englishCushionEffect 常量（Utilities/Constants/PhysicsConstants.swift）
- [ ] T002 [P] [US2] 确认/扩展 TablePhysics：cushionRestitution、clothFriction 可调；支持 per-cushion 配置占位（Utilities/Constants/PhysicsConstants.swift）
- [ ] T003 [P] [US2] 确认 BallPhysics.restitution 为球-球弹性，并添加注释说明校准范围（Utilities/Constants/PhysicsConstants.swift）
- [ ] T004 将 PhysicsEngine、PhysicsConstants 中硬编码的旋转衰减逻辑改为读取 SpinPhysics.spinDecayRate（Core/Physics/PhysicsEngine.swift）
- [ ] T005 将 CollisionResolver 球-球碰撞中的旋转传递改为使用 SpinPhysics.spinTransferRate（Core/Physics/CollisionResolver.swift）
- [ ] T006 将 CushionCollisionModel 或 CollisionResolver 中的侧旋库边修正改为使用 SpinPhysics.englishCushionEffect（Core/Physics/CushionCollisionModel.swift 或 CollisionResolver.swift）

---

## 阶段 2：旋转参数校准

**目的**: 高杆/低杆/侧旋效果与真实台球一致

- [ ] T007 [US1] 建立高杆正碰基准场景测试，记录分离角，校准 spinTransferRate 与高杆幅值（BilliardTrainerTests/Physics/ 或手动测试脚本）
- [ ] T008 [US1] 建立低杆正碰基准场景测试，记录分离角，校准低杆幅值与衰减（BilliardTrainerTests/Physics/）
- [ ] T009 [US1] 建立纯侧旋碰库基准场景，校准 englishCushionEffect（BilliardTrainerTests/Physics/）
- [ ] T010 [US1] 建立碰撞旋转传递场景，验证 spinTransferRate 对目标球运动的影响
- [ ] T011 [US1] 将校准后的参数写入 PhysicsConstants，并更新 plan.md 中的参考值表

---

## 阶段 3：碰撞参数校准

**目的**: 球-球、球-库边、台呢摩擦与真实一致

- [ ] T012 [US2] 建立库边反弹基准场景，校准 cushionRestitution（0.75–0.90 范围扫描）
- [ ] T013 [US2] 建立球-球正碰基准场景，验证 ballBallRestitution（0.92–0.98）
- [ ] T014 [US2] 建立滚动衰减场景，校准 clothFriction / rollingFriction，使速度衰减自然
- [ ] T015 [US2] （可选）实现 per-cushion 弹性配置接口，支持角袋/中袋附近库边差异化
- [ ] T016 [US2] 将校准后的碰撞参数写入 PhysicsConstants

---

## 阶段 4：轨迹预测 UI 优化

**目的**: 预测轨迹清晰、准确，支持多库

- [ ] T017 [P] [US3] 将 BilliardSceneViewModel.updateTrajectoryPreview 接入 PhysicsEngine.predictTrajectory 或 EventDrivenEngine 模拟结果（Features/Training/ViewModels/BilliardSceneViewModel.swift）
- [ ] T018 [US3] 扩展 predictTrajectory 支持球-球碰撞后的母球与目标球双轨迹预测（Core/Physics/PhysicsEngine.swift）
- [ ] T019 [US3] 优化 BilliardScene.showPredictedTrajectory：母球路径与目标球路径颜色/样式区分更明显（Core/Scene/BilliardScene.swift）
- [ ] T020 [US3] 优化轨迹点密度、透明度、线宽，确保不同视角下可读性好（Core/Scene/BilliardScene.swift）
- [ ] T021 [US3] 击球回放时叠加显示预测轨迹 vs 实际轨迹（不同样式），便于对比（Core/Scene/BilliardScene.swift 或相关 View）
- [ ] T022 [US3] 轨迹预测计算放后台队列，避免阻塞主线程；若耗时 > 50ms 则降采样或缩短步数

---

## 阶段 5：障碍球检测

**目的**: 瞄准时检测并提示阻挡

- [ ] T023 [P] [US4] 实现 ObstacleDetector：射线-球体相交，返回最近的障碍球（Core/Physics/ObstacleDetector.swift 或 AimingSystem 扩展）
- [ ] T024 [US4] 在 BilliardSceneViewModel 或 AimingSystem 中集成 detectObstacle，在 updateTrajectoryPreview 或瞄准更新时调用（Features/Training/ViewModels/BilliardSceneViewModel.swift）
- [ ] T025 [US4] 阻挡时修改瞄准线样式（变色/闪烁）或显示「阻挡」图标（Core/Scene/BilliardScene.swift）
- [ ] T026 [US4] 无障碍时恢复默认瞄准线样式
- [ ] T027 [US4] 编写单元测试：标准摆放下的障碍检测准确率验证（BilliardTrainerTests/Physics/ObstacleDetectorTests.swift）
- [ ] T028 [US4] （可选）实现绕行路径计算与显示，用于「解球」提示

---

## 阶段 6：整体手感调优与集成测试

**目的**: 主观感受自然，回归测试通过

- [ ] T029 [US5] 执行标准测试场景 S1–S6，记录观测值与主观感受（文档或测试报告）
- [ ] T030 [US5] 根据测试结果微调旋转、碰撞参数，迭代至手感达标
- [ ] T031 [US5] 邀请至少 5 名台球爱好者进行主观评分（球速、旋转、库边、碰撞、轨迹、一致性）
- [ ] T032 编写物理回归测试：固定初状态与击球参数，断言关键输出在允许范围内（BilliardTrainerTests/Physics/PhysicsRegressionTests.swift）
- [ ] T033 在 CI 或本地脚本中集成回归测试，确保后续改动不破坏物理一致性
- [ ] T034 更新 PhysicsConstants 注释与 plan.md 参考数据表，记录最终校准值

---

## 依赖与执行顺序

### 阶段依赖

- **阶段 1**: 无依赖，可立即开始
- **阶段 2**: 依赖 T001、T004、T005、T006
- **阶段 3**: 依赖 T002、T003
- **阶段 4**: 可与阶段 2、3 部分并行，但 T017、T018 建议在阶段 1 之后
- **阶段 5**: 可并行，无物理依赖
- **阶段 6**: 依赖阶段 1–5 完成后执行

### 可并行任务

- T001、T002、T003 可并行
- T017、T023、T024 可与阶段 2、3 部分任务并行
- T019、T020、T021 可并行（不同 UI 元素）

---

## 任务统计

| 阶段 | 任务数 |
|------|--------|
| 阶段 1 | 6 |
| 阶段 2 | 5 |
| 阶段 3 | 5 |
| 阶段 4 | 6 |
| 阶段 5 | 6 |
| 阶段 6 | 6 |
| **合计** | **34** |
