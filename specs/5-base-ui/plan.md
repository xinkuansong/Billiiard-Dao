# 实施计划：基础 UI 框架 (Base UI Framework)

**分支**: `5-base-ui` | **日期**: 2025-02-20 | **规格**: [spec.md](./spec.md)  
**说明**: 本文档为回溯性计划，记录已实现基础 UI 框架的技术决策与架构

## 摘要

基础 UI 框架采用 SwiftUI + SwiftData 架构，App 入口配置 ModelContainer 与 AppState，ContentView 根据首次启动状态分流至 OnboardingView 或 MainTabView。五 Tab（首页、课程、训练、统计、设置）构成主界面骨架。AudioManager 为单例音效管理器，支持系统音效与震动；GameRules 提供中式八球犯规判定逻辑。

## 技术上下文

**语言/版本**: Swift 5.x  
**主要依赖**: SwiftUI、SwiftData、AVFoundation、AudioToolbox、UIKit  
**目标平台**: iOS 17+  
**项目类型**: 原生 iOS 应用  
**架构**: MVVM + 全局 AppState  
**持久化**: SwiftData（UserProfile、CourseProgress、UserStatistics、TrainingSession）+ UserDefaults（首次启动、设置项）  
**约束**: 无强制横屏（训练场景单独处理），各 Tab 独立 NavigationStack  
**规模**: App/、Features/Home/、Features/Course/、Features/Statistics/、Features/Settings/、Core/Audio/、Core/Rules/

## 核心架构决策

### 1. SwiftData ModelContainer

- **决策**: 在 BilliardTrainerApp 中创建共享 ModelContainer，注入到 WindowGroup
- **理由**:
  - SwiftData 为 iOS 17+ 官方持久化方案
  - Schema 包含 UserProfile、CourseProgress、UserStatistics、TrainingSession
  - 供 AppState.loadOrCreateUser、saveTrainingSession 使用
- **实现**: WindowGroup.modelContainer(sharedModelContainer)，Schema 与 ModelConfiguration

### 2. AppState 全局状态

- **决策**: AppState 作为 ObservableObject，通过 @StateObject 注入，@EnvironmentObject 下发
- **理由**:
  - 集中管理 isFirstLaunch、currentUser
  - 提供 loadOrCreateUser、saveTrainingSession 等业务入口
  - 与 SwiftData ModelContext 配合
- **实现**: BilliardTrainerApp 持有一个 @StateObject appState，ContentView.environmentObject(appState)

### 3. 五 Tab 架构

- **决策**: MainTabView 使用 TabView，五个 Tab 分别承载 HomeView、CourseListView、TrainingListView、StatisticsView、SettingsView
- **理由**:
  - 清晰的一级导航，用户可快速切换核心模块
  - 各 Tab 内部可再建 NavigationStack 做二级导航
  - 绿色 tint 统一主题
- **实现**: TabView(selection: $selectedTab)，Tab 枚举 home/course/training/statistics/settings

### 4. 首次启动与引导

- **决策**: UserDefaults.hasLaunchedBefore 控制首次启动，ContentView 根据 appState.isFirstLaunch 与 showOnboarding 显示 OnboardingView
- **理由**:
  - 首次启动展示产品价值（欢迎、课程、物理引擎）
  - 支持跳过，减少强制步骤
- **实现**: AppState.init 中设置 isFirstLaunch，OnboardingView 多页 TabView + 页面指示器 + 下一步/跳过/开始使用

### 5. 设置持久化

- **决策**: 游戏设置使用 @AppStorage 存储 soundEnabled、hapticEnabled、aimLineEnabled、trajectoryEnabled
- **理由**:
  - 轻量级键值对，无需 SwiftData
  - 与 Toggle 天然绑定
  - AudioManager 可通过 syncWithUserSettings 同步
- **实现**: SettingsView 中 @AppStorage("soundEnabled") private var soundEnabled = true 等

### 6. AudioManager 单例

- **决策**: AudioManager 为单例，预置 SoundType 枚举，使用系统音效 SystemSoundID 作为临时方案
- **理由**:
  - 全局唯一实例，便于训练场景、课程等多处调用
  - 支持加载自定义 mp3/wav（loadCustomSound），当前回退到系统音
  - 击球、碰撞、进袋等按力度/冲量选择不同音效
- **实现**: AudioManager.shared，playCueHit(power:)、playBallCollision(impulse:)、playPocketDrop 等，playHaptic 根据 SoundType 选择 UIImpactFeedbackGenerator/UINotificationFeedbackGenerator

### 7. 中式八球规则

- **决策**: GameRules 中实现 EightBallRules.isLegalShot，纯逻辑无 UI
- **理由**:
  - 训练或对战时需判定击球是否合法、犯规类型
  - 支持球名格式 ball_N 与 _N（USDZ 模型）
- **实现**: GameEvent 枚举（ballBallCollision、ballCushionCollision、ballPocketed、cueBallPocketed），Foul 枚举，isLegalShot 返回 (legal, fouls)

### 8. 屏幕方向控制

- **决策**: OrientationHelper 与 AppDelegate 控制支持的方向，训练场景单独调用 forceLandscape/restorePortrait
- **理由**:
  - 主界面竖屏，训练场景横屏
  - 通过 UIWindowScene.requestGeometryUpdate 动态切换
- **实现**: BilliardTrainerApp.swift 中 OrientationHelper、AppDelegate.supportedInterfaceOrientationsFor

## 项目结构

### 文档（本功能）

```text
specs/5-base-ui/
├── spec.md      # 本功能规格（回溯）
├── plan.md      # 本实施计划（回溯）
└── tasks.md     # 任务列表（回溯）
```

### 源代码

```text
current_work/BilliardTrainer/
├── App/
│   ├── BilliardTrainerApp.swift   # App 入口、ModelContainer、AppState、OrientationHelper、AppDelegate
│   └── ContentView.swift         # 根视图、MainTabView
├── Features/
│   ├── Home/
│   │   └── Views/
│   │       ├── HomeView.swift    # 首页
│   │       └── OnboardingView.swift # 引导
│   ├── Course/
│   │   └── Views/
│   │       └── CourseListView.swift # 课程列表
│   ├── Statistics/
│   │   └── Views/
│   │       └── StatisticsView.swift # 统计
│   └── Settings/
│       └── Views/
│           └── SettingsView.swift  # 设置、已购内容、帮助
└── Core/
    ├── Audio/
    │   └── AudioManager.swift    # 音效与震动
    └── Rules/
        └── GameRules.swift      # 中式八球规则
```

### 结构说明

- **BilliardTrainerApp**: @main、WindowGroup、sharedModelContainer、@UIApplicationDelegateAdaptor
- **ContentView**: 根据 appState.isFirstLaunch 与 showOnboarding 切换 OnboardingView / MainTabView
- **MainTabView**: TabView 五个 Tab，tint .green
- **HomeView**: UserInfoCard、QuickAccessSection、LearningProgressSection、TodayStatsSection
- **CourseListView**: CourseSection 分组，CourseCard 展示单课，Course 模型含 freeCourses、basicCourses、advancedCourses、expertCourses
- **StatisticsView**: OverviewCard、AccuracyCard、PracticeTimeCard、SkillRadarCard（占位）
- **SettingsView**: List 分 Section，游戏设置、购买管理、关于、反馈；PurchasedContentView、HelpView 子页面
