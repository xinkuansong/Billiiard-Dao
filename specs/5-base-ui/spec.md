# 功能规格：基础 UI 框架 (Base UI Framework)

**功能分支**: `5-base-ui`  
**创建日期**: 2025-02-20  
**状态**: 已完成 (回溯记录)  
**完成度**: 90%  
**说明**: 本文档为回溯性规格，记录已实现的球道 (Billiard Trainer) iOS App 基础 UI 框架。涵盖应用入口、五 Tab 架构、首页、引导、课程、统计、设置及音效与规则模块。

## 概述

基础 UI 框架提供应用的骨架与核心页面：SwiftData ModelContainer、AppState 全局状态、首次启动引导、五 Tab 主界面（首页、课程、训练、统计、设置），以及 AudioManager 音效管理与中式八球 GameRules 规则判定。

## 用户故事 (User Stories)

### 用户故事 1 - 应用启动与引导 (优先级: P1)

用户首次打开应用时，显示 OnboardingView 引导页（欢迎、系统化课程、真实物理引擎三页），可「下一步」或「跳过」进入主界面。非首次启动则直接进入主界面。

**独立测试**: 清除 UserDefaults 后首次启动显示引导，完成引导或跳过后可进入 Tab 主界面。

**验收场景**:
1. **Given** 首次启动（isFirstLaunch 为 true），**When** ContentView 加载，**Then** 显示 OnboardingView
2. **Given** 引导页，**When** 用户点击「下一步」，**Then** 切换至下一页；最后一页点击「开始使用」则关闭引导
3. **Given** 引导页，**When** 用户点击「跳过」，**Then** 直接关闭引导进入主界面
4. **Given** 非首次启动，**When** 应用启动，**Then** 直接显示 MainTabView，不显示引导

---

### 用户故事 2 - 五 Tab 主导航 (优先级: P1)

用户通过底部 Tab 在首页、课程、训练、统计、设置五个模块间切换。Tab 使用绿色主题色，图标与标签清晰可辨。

**独立测试**: 点击各 Tab，对应页面正确展示，选中状态正确。

**验收场景**:
1. **Given** 主界面，**When** 用户查看底部 Tab，**Then** 显示五个 Tab：首页、课程、训练、统计、设置
2. **Given** 用户点击某一 Tab，**When** 切换，**Then** 对应视图（HomeView/CourseListView/TrainingListView/StatisticsView/SettingsView）显示
3. **Given** TabView，**When** 渲染，**Then** tint 为绿色，符合台球主题

---

### 用户故事 3 - 首页信息与快捷入口 (优先级: P1)

用户进入首页可看到：用户信息卡片（等级、经验值进度）、快捷入口（继续学习、快速练习）、学习进度（课程完成情况）、今日统计（练习时长、进球数、进球率）。

**独立测试**: 首页各区块正确展示，数据可为占位或来自 SwiftData。

**验收场景**:
1. **Given** 首页，**When** 加载，**Then** 显示 UserInfoCard、QuickAccessSection、LearningProgressSection、TodayStatsSection
2. **Given** 快捷入口，**When** 用户点击，**Then** 可跳转至对应课程或训练（具体导航待完善）

---

### 用户故事 4 - 课程列表 (优先级: P1)

用户进入课程 Tab，可浏览 L1–L18 课程，按入门（免费）、基础、进阶、高级分组。每组显示课程编号、标题、描述、时长、完成/锁定状态。

**独立测试**: 课程列表正确分组展示，免费课程可访问，付费课程显示锁定。

**验收场景**:
1. **Given** 课程页，**When** 加载，**Then** 显示 CourseSection：入门课程（免费）、基础课程（¥18）、进阶课程（¥25）、高级课程（¥20）
2. **Given** 课程卡片，**When** 渲染，**Then** 显示 L 编号、标题、描述、时长、完成勾或锁定图标
3. **Given** 免费课程，**When** 点击，**Then** 可进入（具体跳转待实现）

---

### 用户故事 5 - 统计页面 (优先级: P2)

用户进入统计 Tab，可查看总览（总练习时长、总进球、平均进球率）、进球率统计（直球、30°/45°/60° 角度球）、本周练习柱状图、技能雷达图占位（V1.2 即将推出）。

**独立测试**: 统计页各卡片正确展示，数据可为占位或来自 UserStatistics。

**验收场景**:
1. **Given** 统计页，**When** 加载，**Then** 显示 OverviewCard、AccuracyCard、PracticeTimeCard、SkillRadarCard
2. **Given** 进球率卡片，**When** 渲染，**Then** 直球、30°/45°/60° 角度球各有进度条与百分比
3. **Given** 技能雷达，**When** 渲染，**Then** 显示「即将推出」占位

---

### 用户故事 6 - 设置与偏好 (优先级: P1)

用户进入设置 Tab，可配置游戏设置（音效、震动、瞄准辅助线、轨迹预测）、查看已购内容、恢复购买、查看版本、隐私政策、使用帮助、意见反馈、给个好评。

**独立测试**: 设置项使用 @AppStorage 持久化，Toggle 开关可正常切换。

**验收场景**:
1. **Given** 设置页，**When** 加载，**Then** 显示游戏设置 Section：音效、震动、瞄准辅助线、轨迹预测
2. **Given** 用户切换音效 Toggle，**When** 变更，**Then** @AppStorage("soundEnabled") 持久化
3. **Given** 购买管理，**When** 用户点击，**Then** 可进入已购内容页或恢复购买
4. **Given** 关于与反馈，**When** 用户点击，**Then** 可打开隐私政策链接、使用帮助、邮件反馈、App Store 评价链接

---

### 用户故事 7 - 音效与震动 (优先级: P2)

应用在击球、碰撞、进袋等场景下播放相应音效，并支持震动反馈。音效与震动可通过设置开关控制。

**独立测试**: 训练场景中击球、进袋等动作触发 AudioManager 播放，设置关闭后不再播放。

**验收场景**:
1. **Given** AudioManager.shared.isSoundEnabled 为 true，**When** 调用 playCueHit/playBallCollision/playPocketDrop 等，**Then** 播放对应系统音效
2. **Given** AudioManager.shared.isHapticEnabled 为 true，**When** 击球或进袋，**Then** 触发对应震动
3. **Given** 用户关闭音效/震动，**When** syncWithUserSettings 或直接设置，**Then** 不再播放音效/震动

---

### 用户故事 8 - 中式八球规则 (优先级: P2)

应用内置中式八球规则判定逻辑，用于训练或对战中的犯规检测：母球落袋、首碰错误、无库边等。

**独立测试**: EightBallRules.isLegalShot 对给定 events 与 currentGroup 返回正确 (legal, fouls)。

**验收场景**:
1. **Given** 事件列表含 cueBallPocketed，**When** isLegalShot 判定，**Then** 返回 legal: false，fouls 含 .cueBallPocketed
2. **Given** 首碰错误（solids 方先碰条纹球），**When** 判定，**Then** 返回 wrongFirstHit 犯规
3. **Given** 无球碰、无库边、无进袋，**When** 判定，**Then** 返回 noCushionAfterContact 或 noBallHit 等

---

### 边界情况

- 首次启动：UserDefaults.hasLaunchedBefore 控制，引导完成后标记
- SwiftData 初始化失败：fatalError，生产环境可改为降级逻辑
- 链接失效：隐私政策、反馈等 URL 为占位，需替换为实际地址
- 技能雷达：占位 UI，实际数据与图表待 V1.2

## 功能需求 (Functional Requirements)

### 功能需求

- **FR-001**: 应用入口 BilliardTrainerApp 必须配置 SwiftData ModelContainer（UserProfile、CourseProgress、UserStatistics、TrainingSession）
- **FR-002**: AppState 必须管理 isFirstLaunch、currentUser，并提供 loadOrCreateUser、saveTrainingSession
- **FR-003**: ContentView 必须根据 appState.isFirstLaunch 决定显示 OnboardingView 或 MainTabView
- **FR-004**: MainTabView 必须提供五 Tab：首页、课程、训练、统计、设置
- **FR-005**: HomeView 必须展示用户信息、快捷入口、学习进度、今日统计
- **FR-006**: OnboardingView 必须提供多页引导（欢迎、系统化课程、真实物理引擎），支持下一步与跳过
- **FR-007**: CourseListView 必须按入门/基础/进阶/高级分组展示 L1–L18 课程
- **FR-008**: StatisticsView 必须展示总览、进球率、本周练习、技能雷达占位
- **FR-009**: SettingsView 必须提供游戏设置（音效、震动、瞄准线、轨迹）、购买管理、关于、反馈
- **FR-010**: AudioManager 必须支持击球、碰撞、库边、进袋、成功、失败、连击等音效，以及对应震动
- **FR-011**: GameRules（EightBallRules）必须实现 isLegalShot，检测母球落袋、首碰错误、无库边等犯规

### 关键实体

- **AppState**: isFirstLaunch、currentUser、loadOrCreateUser、saveTrainingSession
- **UserProfile**: 用户档案（SwiftData 模型）
- **Course**: id、title、description、duration、isCompleted；freeCourses、basicCourses、advancedCourses、expertCourses
- **AudioManager.SoundType**: cueHit、ballCollision、cushionHit、pocketDrop、success、fail、combo 等
- **EightBallRules**: isLegalShot(events:currentGroup:) → (legal, fouls)
- **Foul**: cueBallPocketed、wrongFirstHit、noCushionAfterContact、noBallHit

## 成功标准 (Success Criteria)

### 可衡量结果

- **SC-001**: 首次启动可完整走完引导流程，跳过或完成后进入主界面
- **SC-002**: 五 Tab 可正确切换，各页面无闪退、布局正常
- **SC-003**: 设置项（音效、震动等）修改后可持久化，重启应用后保持
- **SC-004**: 训练场景中音效与震动可正确触发（当 AudioManager 被调用时）
- **SC-005**: 中式八球规则判定对典型犯规场景返回正确结果
- **SC-006**: SwiftData 容器可正常创建，UserProfile 可加载或创建

## 源文件列表

| 路径 | 说明 |
|------|------|
| App/BilliardTrainerApp.swift | App 入口、ModelContainer、AppState、OrientationHelper、AppDelegate |
| App/ContentView.swift | 根视图、MainTabView 五 Tab |
| Features/Home/Views/HomeView.swift | 首页（用户信息、快捷入口、学习进度、今日统计） |
| Features/Home/Views/OnboardingView.swift | 首次启动引导 |
| Features/Course/Views/CourseListView.swift | 课程列表（L1–L18 分组） |
| Features/Statistics/Views/StatisticsView.swift | 统计页（总览、进球率、本周练习、雷达占位） |
| Features/Settings/Views/SettingsView.swift | 设置（游戏设置、购买、关于、反馈、帮助） |
| Core/Audio/AudioManager.swift | 音效与震动管理 |
| Core/Rules/GameRules.swift | 中式八球规则与犯规判定 |
