# App

> 代码路径：`BilliardTrainer/App/`
> 文档最后更新：2026-02-27

## 模块定位

App 模块是应用的入口层，负责应用生命周期管理、全局状态管理、SwiftData 容器初始化与屏幕方向控制。它不处理具体业务逻辑，仅提供基础设施与状态注入。

## 入口文件

| 文件 | 职责 | 行数 |
|------|------|------|
| `BilliardTrainerApp.swift` | @main 应用入口，AppState 全局状态管理，ModelContainer 初始化，屏幕方向控制 | ~207 |
| `ContentView.swift` | 根视图，根据首次启动状态显示引导页或主界面，TabView 导航 | ~80 |

## 核心概念与术语

| 术语 | 含义 |
|------|------|
| AppState | 全局应用状态 ObservableObject，管理首次启动标记与当前用户 |
| OrientationHelper | 静态屏幕方向控制辅助类，提供强制横屏/恢复竖屏能力 |
| AppDelegate | UIApplicationDelegate 适配器，响应系统方向查询 |
| ModelContainer | SwiftData 模型容器，统一管理 UserProfile、CourseProgress、UserStatistics、TrainingSession |
| hasLaunchedBefore | UserDefaults 键，标记是否已完成首次启动 |

## 端到端流程

```
应用启动 → BilliardTrainerApp 初始化 → ModelContainer 创建 → ContentView 渲染 → 
检查 isFirstLaunch → 显示 OnboardingView 或 MainTabView → 
AppState 注入到子视图 → 用户操作触发状态更新
```

## 对外能力（Public API）

- `AppState`：全局状态管理类，提供 `isFirstLaunch`、`currentUser`、`loadOrCreateUser(context:)`、`saveTrainingSession(...)` 方法
- `OrientationHelper`：静态方向控制，提供 `forceLandscape()`、`restorePortrait()` 方法
- `BilliardTrainerApp`：@main 入口，提供 `sharedModelContainer` 与 `appState` 环境注入
- `ContentView`：根视图，通过 `@EnvironmentObject` 接收 AppState

## 依赖与边界

- **依赖**：SwiftUI、SwiftData、UIKit（方向控制）
- **被依赖**：所有 Features 模块（通过 @EnvironmentObject 获取 AppState，通过 @Environment 获取 ModelContainer）
- **禁止依赖**：不应反向依赖 Features 或 Core 模块的具体实现

## 与其他模块的耦合点

- **Models**：ModelContainer 依赖 Models 模块的 UserProfile、CourseProgress、UserStatistics、TrainingSession
- **Features/Home**：ContentView 直接引用 OnboardingView 与 MainTabView（包含 HomeView）
- **Features/Settings**：AppState 的 `saveTrainingSession` 方法更新 UserStatistics，可能影响 Statistics 视图

## 关键数据结构

| 结构/枚举 | 字段/Case | 单位/生命周期 |
|-----------|-----------|---------------|
| AppState | isFirstLaunch: Bool, currentUser: UserProfile? | 应用生命周期 |
| OrientationHelper.orientationMask | UIInterfaceOrientationMask | 静态变量，应用级 |
| ModelContainer schema | [UserProfile, CourseProgress, UserStatistics, TrainingSession] | 应用生命周期 |
| MainTabView.Tab | home, course, training, statistics, settings | 视图状态 |

## 最近变更记录

| 日期 | 变更摘要 | 影响面 |
|------|----------|--------|
| 2026-02-27 | 创建模块文档 | 无 |
