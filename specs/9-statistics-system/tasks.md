# 任务列表：统计系统 (Statistics System)

**输入**: `specs/9-statistics-system/` 下设计文档  
**说明**: 本任务列表覆盖统计系统未完成任务；格式为 `- [ ] TXXX [P?] [US?] 描述 文件路径`  
**状态**: 草案 (Draft)

## 格式

- **[P]**: 可并行执行（不同文件，无依赖）
- **[USn]**: 关联用户故事 n（1–7）
- 路径基于 `current_work/BilliardTrainer/`

---

## 阶段 1：数据模型扩展

**目的**: 扩展 UserStatistics 角度区间，定义 ShotRecord，支持细粒度统计

- [ ] T001 [P] [US2] 扩展 UserStatistics：新增 angle0ShotsMade/Attempted、angle15ShotsMade/Attempted、angle75ShotsMade/Attempted，及对应 recordShot 分支 Models/UserProfile.swift
- [ ] T002 [P] [US2] 扩展 UserStatistics.ShotType 枚举：straight、angle15、angle30、angle45、angle60、angle75（若需区分 0° 与 15°） Models/UserProfile.swift
- [ ] T003 [US2] 定义 ShotRecord Codable 结构体：timestamp、targetBall、cueBall、aimPoint、spin、power、result、cueBallFinal Models/UserProfile.swift 或 Features/Training/Models/
- [ ] T004 [US2] 在 TrainingSession 中新增 shots: [ShotRecord] 或 shotsData: Data（JSON 编码），用于存储会话内击球明细 Models/UserProfile.swift

---

## 阶段 2：数据采集管道

**目的**: 训练过程中采集击球数据，计算角度与杆法，写入 sessionShots

- [ ] T005 [US1][US2] 在 BilliardSceneViewModel 或物理层暴露击球所需数据：母球位置、目标球位置、瞄准方向（供角度计算） Core/Scene/BilliardSceneView.swift 或 Core/Physics/
- [ ] T006 [US2] 实现角度计算工具：根据母球、目标球、瞄准方向计算击球角度，映射到 0°/15°/30°/45°/60°/75° 区间 Utilities/Statistics/ShotAngleCalculator.swift（新建）
- [ ] T007 [US3] 实现杆法识别工具：根据 selectedCuePoint (CGPoint) 映射到 center/top/draw/left/right Utilities/Statistics/SpinTypeMapper.swift（新建）
- [ ] T008 [US1][US2][US3] 在 TrainingViewModel 中新增 sessionShots: [ShotRecord]，在 onShotCompleted 回调中采集 aimDirection、selectedCuePoint、currentPower、结果，调用角度/杆法工具，追加 ShotRecord Features/Training/ViewModels/TrainingViewModel.swift
- [ ] T009 [US1] 扩展 AppState.saveTrainingSession：新增 shots: [ShotRecord] 参数，遍历调用 userStats.recordShot(type:made:) 与 recordSpin(type:)，更新角度与杆法统计 App/BilliardTrainerApp.swift
- [ ] T010 [US1] 修改 AppState.updateUserStatistics：除 totals 外，根据 shots 数组调用 UserStatistics.recordShot、recordSpin App/BilliardTrainerApp.swift
- [ ] T011 [US1] 在 TrainingSceneView 退出流程中调用 AppState.saveTrainingSession：传入 ModelContext、config.trainingType、viewModel 的 totalShots、pocketedCount、score、elapsedTime、sessionShots Features/Training/Views/TrainingSceneView.swift
- [ ] T012 [US1] 确保 TrainingSceneView 可访问 ModelContext（@Environment(\.modelContext) 或 AppState 注入）与 AppState Features/Training/Views/TrainingSceneView.swift、App/BilliardTrainerApp.swift

---

## 阶段 3：统计页数据绑定

**目的**: 统计页各卡片从 UserStatistics 与 TrainingSession 读取真实数据

- [ ] T013 [P] [US7] 在 StatisticsView 中注入 @Environment(\.modelContext)、@Query UserStatistics 或通过 AppState 获取当前用户统计 Features/Statistics/Views/StatisticsView.swift
- [ ] T014 [US7] OverviewCard 绑定 UserStatistics：总练习（formattedPracticeTime）、总进球（totalPocketed）、平均进球率（overallAccuracy * 100） Features/Statistics/Views/StatisticsView.swift
- [ ] T015 [US7] AccuracyCard 绑定 UserStatistics：直球、30°/45°/60°（及扩展后的 0°/15°/75°）进球率，使用真实 angle*Accuracy Features/Statistics/Views/StatisticsView.swift
- [ ] T016 [US7] 处理无数据状态：当 UserStatistics 为空或 totalShots==0 时，各卡片显示 0 或「暂无数据」 Features/Statistics/Views/StatisticsView.swift

---

## 阶段 4：练习时长与图表

**目的**: 本周练习柱状图使用真实数据，支持按日聚合

- [ ] T017 [US4] 实现按日期聚合 TrainingSession 的逻辑：按 startTime/endTime 所在日期分组，求和 duration；提供本周 7 天数据 Features/Statistics/ViewModels/StatisticsViewModel.swift 或扩展 StatisticsView
- [ ] T018 [US4] PracticeTimeCard 使用 Swift Charts 替换当前硬编码柱状图：BarMark 绑定真实每日分钟数 Features/Statistics/Views/StatisticsView.swift
- [ ] T019 [US4] 确保「本周练习」仅包含本周日期；处理跨周、空数据情况 Features/Statistics/Views/StatisticsView.swift

---

## 阶段 5：六维技能雷达图

**目的**: 实现真实六维雷达图，数据来源于 UserStatistics

- [ ] T020 [US5] 实现六维数值计算逻辑：瞄准准度、杆法控制、走位能力、库边技术、策略思维、解球能力（见 plan.md 映射表） Features/Statistics/ViewModels/StatisticsViewModel.swift 或 Utilities/Statistics/SkillRadarCalculator.swift
- [ ] T021 [US5] 实现 SkillRadarChart 视图：使用 Path 绘制六边形网格与填充区域，六顶点对应六维度 Features/Statistics/Views/StatisticsView.swift 或 Features/Statistics/Views/SkillRadarChart.swift
- [ ] T022 [US5] SkillRadarCard 替换占位内容，绑定 SkillRadarChart 与计算后的六维数据 Features/Statistics/Views/StatisticsView.swift
- [ ] T023 [US5] 处理新用户无数据：雷达图显示 0 值六边形或友好占位 Features/Statistics/Views/StatisticsView.swift

---

## 阶段 6：杆法使用分析

**目的**: 杆法频次与成功率统计展示

- [ ] T024 [US3] 在 UserStatistics 中扩展杆法成功率：各杆法需记录 attempted 与 made（当前仅有 count）；或新增 spinMade 字段 Models/UserProfile.swift
- [ ] T025 [US3] recordSpin 与 recordShot 联动：击球时同时记录杆法类型与是否进球，用于计算杆法成功率 Models/UserProfile.swift、App/BilliardTrainerApp.swift
- [ ] T026 [US3] 新增杆法统计卡片或集成到 AccuracyCard：展示各杆法使用频次与成功率 Features/Statistics/Views/StatisticsView.swift

---

## 阶段 7：历史会话浏览

**目的**: 历史会话列表与详情页

- [ ] T027 [US6] 创建 SessionHistoryView：@Query TrainingSession 按 userId 过滤、endTime 倒序，List 展示 Features/Statistics/Views/SessionHistoryView.swift（新建）
- [ ] T028 [US6] 创建 SessionDetailView：展示 trainingType、日期、totalShots、pocketedCount、score、duration、accuracy Features/Statistics/Views/SessionDetailView.swift（新建）
- [ ] T029 [US6] 在 StatisticsView 或统计页添加入口：导航到 SessionHistoryView Features/Statistics/Views/StatisticsView.swift
- [ ] T030 [US6] 处理空历史：无 TrainingSession 时显示空状态提示 Features/Statistics/Views/SessionHistoryView.swift

---

## 阶段 8：集成与收尾

**目的**: 端到端验证、边界情况、文档

- [ ] T031 [US1] 验证训练完成后退出，统计页立即反映新数据；验证中途退出不保存 Features/Training/Views/TrainingSceneView.swift
- [ ] T032 验证角度分类、杆法识别与 UserStatistics 一致；添加单元测试（可选） Utilities/Statistics/
- [ ] T033 验证图表在暗色模式、大字体下的表现 Features/Statistics/Views/StatisticsView.swift
- [ ] T034 更新 specs/9-statistics-system 状态为「开发中」或「已完成」，并同步代码库总结文档

---

## 依赖与执行顺序

### 阶段依赖

- **阶段 1** 无依赖，可立即开始
- **阶段 2** 依赖阶段 1（ShotRecord、UserStatistics 扩展）
- **阶段 3** 依赖阶段 1、2（需有数据写入）
- **阶段 4** 依赖阶段 2（需有 TrainingSession 持久化）
- **阶段 5** 依赖阶段 1、2（需有 UserStatistics 细粒度数据）
- **阶段 6** 依赖阶段 1、2（杆法 attempted/made）
- **阶段 7** 依赖阶段 2（TrainingSession 持久化）
- **阶段 8** 依赖阶段 3–7 完成

### 可并行任务

- T001、T002、T003、T004（阶段 1 内）
- T006、T007（阶段 2 内）
- T013、T014、T015（阶段 3 内）
- T027、T028（阶段 7 内）

---

## 完成度说明

**当前完成度约 50%**：

- **已完成**: StatisticsView UI 框架（OverviewCard、AccuracyCard、PracticeTimeCard、SkillRadarCard 占位）、UserStatistics 基础模型（totalShots、totalPocketed、angle30/45/60、spin counts）、TrainingSession 模型、TrainingViewModel 击球与进球计数、BilliardSceneView 回调
- **待完成**: 数据采集管道、角度/杆法计算、saveTrainingSession 调用、统计页数据绑定、Swift Charts 图表、六维雷达图、杆法成功率、历史会话、端到端打通
