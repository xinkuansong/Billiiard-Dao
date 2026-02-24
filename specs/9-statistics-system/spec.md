# 功能规格：统计系统 (Statistics System)

**功能分支**: `9-statistics-system`  
**创建日期**: 2025-02-20  
**状态**: 草案 (Draft)  
**完成度**: 50%  
**说明**: 球道 (Billiard Trainer) iOS App 统计系统功能规格。当前 UI 已完成，数据采集与持久化尚未打通；本文档覆盖待实现的数据管道、图表渲染与六维技能雷达。

## 概述

统计系统为用户提供训练数据的可视化与洞察：总览（练习时长、进球数、进球率）、按角度分类的进球率、杆法使用统计、练习时长趋势、六维技能雷达图、历史会话浏览。当前 StatisticsView 已展示占位 UI，需完成数据采集管道、与 UserStatistics 的绑定、Swift Charts 图表实现及技能雷达图渲染。

## 用户故事 (User Stories)

### 用户故事 1 - 训练数据自动采集 (优先级: P1)

用户完成一次训练（瞄准、杆法、K 球等）后，系统自动将本次训练的击球数、进球数、练习时长、得分写入 UserStatistics 与 TrainingSession；训练结束时无需用户手动操作即可保存。

**独立测试**: 完成训练后退出，统计页总览、进球率等应反映最新数据。

**验收场景**:
1. **Given** 用户完成一次瞄准训练并点击「退出」，**When** TrainingViewModel 触发保存，**Then** AppState.saveTrainingSession 被调用，UserStatistics 与 TrainingSession 已更新
2. **Given** 训练过程中有 10 击、5 进，**When** 保存会话，**Then** UserStatistics.totalShots += 10，totalPocketed += 5，totalPracticeTime 累加训练时长
3. **Given** 用户中途退出（未完成训练），**When** 用户选择不保存，**Then** 不调用 saveTrainingSession

---

### 用户故事 2 - 细粒度击球记录与角度分类 (优先级: P1)

训练/课程过程中，每次击球完成后系统记录：时间戳、目标球与母球位置、瞄准点、杆法、力度、是否进球、母球最终位置。系统根据击球几何（母球→目标球→袋口角度）将击球归类到 0°、15°、30°、45°、60°、75° 等角度区间，用于统计各角度的进球率。

**独立测试**: 完成若干次不同角度的击球后，统计页「进球率」卡片中各角度区间的数据正确。

**验收场景**:
1. **Given** 一次直球击球（角度约 0°），**When** 击球完成，**Then** 该击被归类到 0° 区间，UserStatistics 对应计数更新
2. **Given** 一次约 45° 角度球击球并进球，**When** 击球完成，**Then** 45° 区间的 attempted 与 made 各加 1
3. **Given** 训练场景中有可用物理输出（母球、目标球位置、瞄准方向），**When** 计算击球角度，**Then** 返回 0–90° 内合理值并映射到预设区间

---

### 用户故事 3 - 杆法使用与成功率分析 (优先级: P2)

用户可查看各杆法（中杆、高杆、低杆、左塞、右塞）的使用频次与进球率。系统在每次击球时根据打点（selectedCuePoint）识别杆法类型并累计；结合击球结果计算各杆法的成功率。

**独立测试**: 使用不同杆法完成多次击球后，杆法统计展示正确频次与成功率。

**验收场景**:
1. **Given** 用户使用高杆击球 5 次、3 进，**When** 查看杆法统计，**Then** 高杆 attempted=5、made=3、成功率 60%
2. **Given** 杆法统计为空的用户，**When** 查看统计页，**Then** 显示「暂无数据」或 0%，不崩溃
3. **Given** 击球使用左塞，**When** 击球完成，**Then** UserStatistics 的 leftEnglishCount 增加，对应杆法 attempted 增加

---

### 用户故事 4 - 练习时长追踪 (优先级: P1)

用户可查看总练习时长、本周练习柱状图（每日分钟数）、以及按日/周/月的趋势。练习时长在每次训练结束时累加到 UserStatistics.totalPracticeTime；支持按日期聚合以生成「本周练习」等图表数据。

**独立测试**: 完成多次不同时长的训练后，总时长与本周柱状图数据正确。

**验收场景**:
1. **Given** 用户今日完成两场训练共 30 分钟，**When** 查看统计页，**Then** 总练习时长增加 30 分钟，本周练习中「今天」对应柱状高度正确
2. **Given** 用户跨周练习，**When** 查看「本周练习」，**Then** 仅显示本周 7 天数据，历史周数据不混入
3. **Given** 无训练记录，**When** 查看练习时长，**Then** 显示 0 或「暂无数据」

---

### 用户故事 5 - 六维技能雷达图 (优先级: P2)

用户可查看六维技能雷达图，展示：瞄准准度、杆法控制、走位能力、库边技术、策略思维、解球能力。各维度由统计数据推导（如瞄准准度≈平均进球率，杆法控制≈杆法成功率等），数值归一化到 0–1 或 0–100 显示在雷达图上。

**独立测试**: 有足够数据后，雷达图正确渲染六边形，无重叠、裁剪或布局错乱。

**验收场景**:
1. **Given** 用户有进球率、杆法、库边击球等数据，**When** 查看技能雷达，**Then** 六边形各顶点对应六维数值，填充区域正确
2. **Given** 新用户无数据，**When** 查看技能雷达，**Then** 显示六边形轮廓与 0 值，或友好占位提示
3. **Given** 技能雷达，**When** 长按或点击某维度，**Then** 可显示该维度含义或来源说明（可选）

---

### 用户故事 6 - 历史会话浏览 (优先级: P2)

用户可浏览历史训练会话列表，按时间倒序展示；点击可查看单次会话详情（类型、日期、击球数、进球数、得分、时长、进球率）。

**独立测试**: 完成多次训练后，历史列表中可看到对应会话，详情正确。

**验收场景**:
1. **Given** 用户已完成 3 次训练，**When** 进入历史会话，**Then** 显示 3 条记录，按结束时间倒序
2. **Given** 用户点击某条会话，**When** 进入详情，**Then** 显示训练类型、日期、击球数、进球数、得分、时长、进球率
3. **Given** 无历史会话，**When** 进入历史列表，**Then** 显示空状态提示

---

### 用户故事 7 - 统计页数据绑定 (优先级: P1)

统计页 OverviewCard、AccuracyCard、PracticeTimeCard 从 UserStatistics 与 TrainingSession 读取真实数据，替代当前硬编码占位值。数据变化时视图自动刷新。

**独立测试**: 修改 UserStatistics 后，统计页各卡片数值随之更新。

**验收场景**:
1. **Given** UserStatistics 有 totalPracticeTime=3600、totalPocketed=100、totalShots=200，**When** 打开统计页，**Then** OverviewCard 显示「1 小时」「100」「50%」（或等价格式化）
2. **Given** UserStatistics 有 angle30Accuracy=0.72，**When** 渲染 AccuracyCard，**Then** 30° 角度球进度条为 72%，数值正确
3. **Given** 用户刚完成训练返回统计页，**When** 数据已保存，**Then** 无需手动刷新即可看到新数据

---

### 边界情况

- **无数据**: 新用户或清空数据后，各卡片与图表显示 0、空状态或「暂无数据」
- **角度区间边界**: 击球角度落于区间边界（如 14.9° vs 15°）时，按左闭右开或明确规定归入相邻区间
- **训练未保存**: 用户强制退出或崩溃时，未保存的会话不计入统计
- **时区**: 练习时长、日期聚合以用户本地时区为准

## 功能需求 (Functional Requirements)

### 功能需求

- **FR-001**: 训练结束时（完成或用户退出并确认保存）必须调用 AppState.saveTrainingSession，传入 trainingType、totalShots、pocketedCount、score、duration
- **FR-002**: UserStatistics 必须支持按角度区间（0°、15°、30°、45°、60°、75°）记录击球 attempt 与 made；若现有模型仅有 30°/45°/60°，需扩展或映射
- **FR-003**: 系统必须定义或扩展 ShotRecord 结构体（Codable），包含 timestamp、targetBall、cueBall、aimPoint、spin、power、result、cueBallFinal；用于会话内细粒度分析，可嵌入 TrainingSession 或独立存储
- **FR-004**: TrainingViewModel 或等价层必须在每次击球完成时收集：角度（由物理引擎或几何计算）、杆法、力度、是否进球，并写入 UserStatistics（recordShot、recordSpin）或聚合到会话级 ShotRecord 列表
- **FR-005**: AppState.updateUserStatistics 必须调用 UserStatistics.recordShot 与 recordSpin（或等价方法），以实现角度与杆法维度的统计，而非仅更新 totalShots、totalPocketed、totalPracticeTime
- **FR-006**: 练习时长必须支持按日聚合，用于「本周练习」柱状图；可基于 TrainingSession 的 startTime/endTime 按日期分组求和
- **FR-007**: 六维技能雷达图必须渲染六边形，六维为：瞄准准度、杆法控制、走位能力、库边技术、策略思维、解球能力；各维度由 UserStatistics 与 TrainingSession 数据计算
- **FR-008**: 统计页 OverviewCard、AccuracyCard、PracticeTimeCard 必须绑定 SwiftData UserStatistics 与聚合数据，使用 @Query 或 @EnvironmentObject 注入
- **FR-009**: 必须提供历史会话列表与详情页，基于 TrainingSession 按 userId 查询，按 endTime 倒序
- **FR-010**: 数据可视化必须使用 Swift Charts（iOS 16+）或等价框架；柱状图、折线图等需符合 Apple HIG

### 关键实体

- **UserStatistics**: totalShots、totalPocketed、totalPracticeTime、straightShotRate、angleShotRates（0°/15°/30°/45°/60°/75°）、spinUsage（各杆法计数与成功率）、consecutiveDays、lastPracticeDate
- **TrainingSession**: id、userId、trainingType、startTime、endTime、totalShots、pocketedCount、score、shots（可选，ShotRecord 数组）
- **ShotRecord**: timestamp、targetBall、cueBall、aimPoint、spin、power、result、cueBallFinal
- **六维技能**: 瞄准准度、杆法控制、走位能力、库边技术、策略思维、解球能力

## 成功标准 (Success Criteria)

### 可衡量结果

- **SC-001**: 完成一次训练并退出后，UserStatistics 与 TrainingSession 中数据正确更新，统计页总览可立即反映
- **SC-002**: 角度分类进球率（至少 0°、30°、45°、60° 或扩展至 6 区间）在多次击球后计算正确，AccuracyCard 展示真实数据
- **SC-003**: 杆法使用频次与成功率统计正确，可从打点与击球结果推导
- **SC-004**: 本周练习柱状图展示真实每日练习分钟数，总练习时长与 UserStatistics 一致
- **SC-005**: 六维技能雷达图正确渲染，六维度数值由统计数据推导，无布局错误
- **SC-006**: 历史会话列表可展示已保存会话，详情页数据完整
- **SC-007**: 统计页无硬编码占位数据，所有卡片绑定真实数据源
- **SC-008**: 与 TrainingViewModel、BilliardSceneViewModel、物理引擎输出集成无崩溃，数据管道端到端畅通

## 源文件列表

| 路径 | 说明 |
|------|------|
| Features/Statistics/Views/StatisticsView.swift | 统计页主视图、OverviewCard、AccuracyCard、PracticeTimeCard、SkillRadarCard |
| Models/UserProfile.swift | UserStatistics、TrainingSession、ShotType、SpinType |
| Features/Training/ViewModels/TrainingViewModel.swift | 训练状态、击球与进球计数、与场景回调绑定 |
| Features/Training/Views/TrainingSceneView.swift | 训练场景、结果 overlay、退出流程 |
| App/BilliardTrainerApp.swift | AppState、saveTrainingSession、updateUserStatistics |
| Core/Scene/BilliardSceneView.swift | BilliardSceneViewModel、aimDirection、currentPower、selectedCuePoint、onShotCompleted |
