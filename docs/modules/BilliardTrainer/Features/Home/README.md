# Home 模块

> 代码路径：`BilliardTrainer/Features/Home/`
> 文档最后更新：2026-02-27

## 模块定位

Home 模块是 BilliardTrainer 应用的首页入口，提供用户信息展示、快捷入口导航、学习进度追踪、今日统计等功能，以及首次启动时的引导流程。该模块不处理具体的训练或游戏逻辑（由 Training 和 FreePlay 模块处理），专注于首页信息展示和导航路由。

## 入口文件

| 文件 | 职责 | 行数 |
|------|------|------|
| `Views/HomeView.swift` | 首页视图，包含用户信息卡片（等级、经验进度）、快捷入口（继续学习、快速练习、自由练习）、学习进度（课程进度条）、今日统计（练习时长、进球数、进球率） | ~240 |
| `Views/OnboardingView.swift` | 首次启动引导页，多页 TabView（欢迎、系统化课程、真实物理引擎），页面指示器，"下一步/开始使用"和"跳过"按钮，完成后设置 `isPresented = false` | ~130 |

## 核心概念与术语

| 术语 | 含义 |
|------|------|
| **用户等级（User Level）** | 用户当前等级（如 Lv.1 新手），基于经验值计算 |
| **经验值（Experience Points）** | 用户累计经验值，通过完成训练和课程获得，达到阈值后升级 |
| **学习进度（Learning Progress）** | 课程完成进度，显示已完成课程数/总课程数（如 3/18 课程） |
| **今日统计（Today Stats）** | 当日练习数据：练习时长（分钟）、进球数（个）、进球率（百分比） |
| **首次启动（First Launch）** | 应用首次启动时显示引导页，通过 `AppState.isFirstLaunch` 判断 |
| **引导页（Onboarding）** | 多页引导流程，介绍应用核心功能，完成后不再显示 |

## 端到端流程

```
应用启动 → ContentView 检查 isFirstLaunch
  ↓ true
显示 OnboardingView（引导页）
  ↓ 用户点击"开始使用"或"跳过"
设置 isFirstLaunch = false → 隐藏引导页
  ↓
显示 MainTabView（主界面）
  ↓
HomeView 作为首页 Tab
  ↓
显示用户信息、快捷入口、学习进度、今日统计
  ↓
用户点击快捷入口
  ├─ "继续学习" → 导航到课程列表
  ├─ "快速练习" → 导航到训练列表
  └─ "自由练习" → fullScreenCover 打开 FreePlayView
```

## 对外能力（Public API）

### HomeView

- `init()`：创建首页视图，使用 `@EnvironmentObject var appState: AppState` 访问应用状态
- 子视图组件：
  - `UserInfoCard`：用户信息卡片，显示等级、经验进度条
  - `QuickAccessSection`：快捷入口区域，包含继续学习、快速练习、自由练习按钮
  - `LearningProgressSection`：学习进度区域，显示课程进度条和完成数量
  - `TodayStatsSection`：今日统计区域，显示练习时长、进球数、进球率

### OnboardingView

- `init(isPresented: Binding<Bool>)`：创建引导页视图，通过 `isPresented` 绑定控制显示/隐藏
- `var pages: [OnboardingPage]`：引导页数据，包含3页：欢迎、系统化课程、真实物理引擎
- `OnboardingPage`：引导页数据模型，包含标题、描述、图标名称、颜色
- `OnboardingPageView`：引导页视图组件，显示图标、标题、描述

## 依赖与边界

- **依赖**：
  - `App/AppState`：应用全局状态，访问 `isFirstLaunch` 和用户数据
  - `Features/FreePlay`：`FreePlayView`（通过快捷入口导航）
  - `SwiftUI`：视图框架
- **被依赖**：
  - `App/ContentView`：`MainTabView` 包含 `HomeView` 作为首页 Tab
  - `App/ContentView`：`ContentView` 根据 `isFirstLaunch` 显示 `OnboardingView`
- **间接依赖**：
  - `Features/Training`：通过快捷入口导航到训练列表（未直接导入）
  - `Features/Course`：通过快捷入口导航到课程列表（未直接导入）
- **禁止依赖**：不应直接依赖 `Features` 层其他业务模块的实现细节，仅通过导航路由访问

## 与其他模块的耦合点

- **AppState**：
  - `HomeView` 使用 `@EnvironmentObject var appState: AppState` 访问用户数据（等级、经验值、学习进度、今日统计）
  - `OnboardingView` 完成后调用 `appState.completeOnboarding()` 设置 `isFirstLaunch = false`
- **ContentView**：
  - `ContentView` 根据 `appState.isFirstLaunch` 决定是否显示 `OnboardingView`
  - `MainTabView` 包含 `HomeView` 作为首页 Tab
- **FreePlay 模块**：
  - `HomeView` 中 `QuickAccessSection` 通过 `fullScreenCover` 打开 `FreePlayView`，直接导入 `FreePlayView`
- **Training/Course 模块**：
  - `HomeView` 中快捷入口通过导航路由访问训练列表和课程列表，不直接导入，降低耦合

## 关键数据结构

| 结构/枚举 | 字段/Case | 单位/生命周期 |
|-----------|-----------|---------------|
| `HomeView` | `@EnvironmentObject var appState: AppState` | 应用生命周期内持续访问 |
| `OnboardingView` | `@Binding var isPresented: Bool`, `@State private var currentPage: Int` | 引导页显示期间维护 |
| `OnboardingPage` | `title: String`, `description: String`, `imageName: String`, `color: Color` | 静态数据，应用生命周期内不变 |
| `UserInfoCard` | 显示等级、经验值进度 | 从 `AppState` 读取数据 |
| `QuickAccessSection` | 快捷入口按钮 | 导航到其他模块 |
| `LearningProgressSection` | 课程进度条 | 从 `AppState` 读取数据 |
| `TodayStatsSection` | 今日统计 | 从 `AppState` 读取数据 |

## 最近变更记录

| 日期 | 变更摘要 | 影响面 |
|------|----------|--------|
| 2026-02-27 | 创建模块文档 | 无代码变更 |
