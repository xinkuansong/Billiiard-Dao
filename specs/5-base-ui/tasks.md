# 任务列表：基础 UI 框架 (Base UI Framework)

**输入**: `specs/5-base-ui/` 下的设计文档  
**说明**: 本文档为回溯性任务列表，所有任务均已标记为已完成 [x]。90% 完成度表示核心框架就绪，部分链接与数据源待完善。

## 格式：`[ID] [P?] [Story] 描述`

- **[P]**: 可并行执行（不同文件，无依赖）
- **[Story]**: 所属用户故事（如 US1, US2, US3 等）
- 路径基于 `current_work/BilliardTrainer/`

---

## 阶段 1：应用入口与状态

**目的**: App 入口、SwiftData、AppState

- [x] T001 [P] 创建 BilliardTrainerApp：@main、WindowGroup、@UIApplicationDelegateAdaptor(AppDelegate.self)
- [x] T002 [P] 配置 SwiftData ModelContainer：Schema(UserProfile, CourseProgress, UserStatistics, TrainingSession)、ModelConfiguration
- [x] T003 [P] 实现 AppState：isFirstLaunch、currentUser、loadOrCreateUser、saveTrainingSession、updateUserStatistics
- [x] T004 实现 OrientationHelper：forceLandscape、restorePortrait、orientationMask
- [x] T005 实现 AppDelegate.supportedInterfaceOrientationsFor
- [x] T006 实现 ContentView：根据 appState.isFirstLaunch 与 showOnboarding 显示 OnboardingView 或 MainTabView

---

## 阶段 2：主导航

**目的**: 五 Tab 主界面

- [x] T007 [US2] 实现 MainTabView：TabView、Tab 枚举（home, course, training, statistics, settings）
- [x] T008 [US2] 集成 HomeView、CourseListView、TrainingListView、StatisticsView、SettingsView 到各 Tab
- [x] T009 [US2] 配置 Tab 图标与标签，tint .green

---

## 阶段 3：首页

**目的**: HomeView 及各区块

- [x] T010 [US3] 实现 HomeView：NavigationStack、ScrollView、VStack 布局
- [x] T011 [US3] 实现 UserInfoCard：等级、经验值进度条
- [x] T012 [US3] 实现 QuickAccessSection、QuickAccessButton（继续学习、快速练习）
- [x] T013 [US3] 实现 LearningProgressSection：课程完成进度
- [x] T014 [US3] 实现 TodayStatsSection、StatItem：练习时长、进球数、进球率

---

## 阶段 4：引导页

**目的**: 首次启动 OnboardingView

- [x] T015 [US1] 实现 OnboardingView：@Binding isPresented、currentPage
- [x] T016 [US1] 实现 OnboardingPage、OnboardingPageView：欢迎、系统化课程、真实物理引擎三页
- [x] T017 [US1] 实现 TabView 多页、页面指示器、下一步/开始使用/跳过按钮
- [x] T018 [US1] 引导完成或跳过时 isPresented = false

---

## 阶段 5：课程列表

**目的**: CourseListView 与 Course 模型

- [x] T019 [US4] 实现 Course 模型：id、title、description、duration、isCompleted；freeCourses、basicCourses、advancedCourses、expertCourses
- [x] T020 [US4] 实现 CourseListView、CourseSection：入门（免费）、基础（¥18）、进阶（¥25）、高级（¥20）
- [x] T021 [US4] 实现 CourseCard：L 编号、标题、描述、时长、完成/锁定状态

---

## 阶段 6：统计页

**目的**: StatisticsView 及各卡片

- [x] T022 [US5] 实现 StatisticsView：NavigationStack、ScrollView
- [x] T023 [US5] 实现 OverviewCard、OverviewItem：总练习、总进球、平均进球率
- [x] T024 [US5] 实现 AccuracyCard、AccuracyRow：直球、30°/45°/60° 角度球进球率
- [x] T025 [US5] 实现 PracticeTimeCard：本周练习柱状图
- [x] T026 [US5] 实现 SkillRadarCard：技能雷达占位（V1.2 即将推出）

---

## 阶段 7：设置页

**目的**: SettingsView 及各 Section

- [x] T027 [US6] 实现 SettingsView：List、Section
- [x] T028 [US6] 实现游戏设置 Section：音效、震动、瞄准辅助线、轨迹预测（@AppStorage）
- [x] T029 [US6] 实现购买管理 Section：已购内容、恢复购买
- [x] T030 [US6] 实现关于 Section：版本、隐私政策、使用帮助
- [x] T031 [US6] 实现反馈 Section：意见反馈、给个好评
- [x] T032 [US6] 实现 PurchasedContentView、PurchaseRow、HelpView、HelpItem

---

## 阶段 8：音效管理

**目的**: AudioManager 音效与震动

- [x] T033 [US7] 实现 AudioManager 单例、SoundType 枚举
- [x] T034 [US7] 实现 setupAudioSession、preloadSounds（占位，当前用系统音）
- [x] T035 [US7] 实现 playCueHit(power:)、playBallCollision(impulse:)、playCushionHit、playPocketDrop、playSuccess、playFail、playCombo
- [x] T036 [US7] 实现 playSystemSound、playHaptic（UIImpactFeedbackGenerator、UINotificationFeedbackGenerator）
- [x] T037 [US7] 实现 loadCustomSound、playCustomSound、syncWithUserSettings

---

## 阶段 9：中式八球规则

**目的**: GameRules 犯规判定

- [x] T038 [US8] 定义 BallGroup、Foul、GameEvent 枚举
- [x] T039 [US8] 实现 EightBallRules.isLegalShot(events:currentGroup:)
- [x] T040 [US8] 实现母球落袋、首碰错误、无库边检测逻辑
- [x] T041 [US8] 实现 extractBallNumber、firstBallHit 辅助方法

---

## 阶段 10：完善与优化（部分完成）

**目的**: 链接替换、数据源接入

- [ ] T042 替换隐私政策、反馈、App Store 评价等 URL 为实际地址
- [ ] T043 首页、统计页数据接入 SwiftData UserProfile、UserStatistics
- [ ] T044 课程完成状态与 CourseProgress 同步
- [ ] T045 技能雷达图 V1.2 实现
- [ ] T046 购买与恢复购买逻辑（StoreKit）

---

## 依赖与执行顺序

### 阶段依赖

- **阶段 1**: 无依赖
- **阶段 2**: 依赖 T006、各 Tab 视图存在
- **阶段 3**: 依赖 T007
- **阶段 4**: 依赖 T006
- **阶段 5**: 依赖 T007
- **阶段 6**: 依赖 T007
- **阶段 7**: 依赖 T007
- **阶段 8**: 无依赖，可与其他阶段并行
- **阶段 9**: 无依赖，可与其他阶段并行
- **阶段 10**: 依赖阶段 1–9

### 可并行任务

- T001、T002、T003 可并行
- T004、T005 可并行
- T010–T014 可并行（不同子视图）
- T033–T037 与 T038–T041 可并行
