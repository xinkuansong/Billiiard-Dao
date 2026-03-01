# Home 模块 - 设计与约束

> 对应 README：[README.md](./README.md)
> 文档最后更新：2026-02-27

## 设计目标与非目标

- **目标**：
  - 提供清晰的首页信息展示，包括用户信息、快捷入口、学习进度、今日统计
  - 实现首次启动引导流程，帮助用户了解应用核心功能
  - 通过导航路由访问其他功能模块，降低模块间耦合
  - 从 `AppState` 读取用户数据，不管理数据持久化逻辑
- **非目标**：
  - 不处理具体的训练或游戏逻辑（由 Training 和 FreePlay 模块处理）
  - 不管理用户数据和持久化（由 AppState 或其他数据层处理）
  - 不实现数据统计计算（统计数据由其他模块计算后存储到 AppState）

## 不变量与约束（改动护栏）

### 单位与坐标系

- UI 布局使用 SwiftUI 标准单位（点，points），不涉及物理坐标计算
- 时间单位：分钟（min），今日统计中的练习时长以分钟显示

### 数值稳定性保护

- **引导页索引保护**：`OnboardingView` 中 `currentPage` 使用 `@State` 管理，通过 `TabView(selection:)` 绑定，索引范围 0..<pages.count，防止越界
- **进度条计算保护**：`LearningProgressSection` 中进度条宽度计算使用 `geometry.size.width * 0.17`（假设3/18课程），实际应从 `AppState` 读取，需检查除零情况
- **统计数据格式化保护**：`TodayStatsSection` 中统计数据格式化（如百分比）需检查除零情况，避免显示 "NaN%" 或崩溃

### 时序与状态约束

- **首次启动流程**：`ContentView` 中必须先检查 `appState.isFirstLaunch`，再决定显示 `OnboardingView` 或 `MainTabView`，不可跳过检查
- **引导页完成流程**：用户点击"开始使用"或"跳过" → 调用 `appState.completeOnboarding()` → 设置 `isPresented = false` → `ContentView` 检测到变化后隐藏引导页
- **快捷入口导航流程**：用户点击快捷入口 → 触发导航（`NavigationLink` 或 `fullScreenCover`） → 打开目标视图，不可阻塞主线程

### 常量与阈值清单

| 常量/阈值 | 值 | 来源/理由 | 改动影响 |
|-----------|-----|----------|----------|
| 引导页数量 | 3页 | 业务需求，介绍核心功能 | 影响引导页流程长度，增加需更新 `pages` 数组 |
| 引导页内容 | 欢迎、系统化课程、真实物理引擎 | 业务需求，介绍应用特色 | 影响用户首次体验，改动需同步更新UI文案 |
| 进度条宽度比例 | 0.17（示例，实际应从 AppState 读取） | UI设计，假设3/18课程 | 影响进度条显示，必须与实际进度数据一致 |
| 今日统计项目 | 练习时长、进球数、进球率 | 业务需求，展示核心数据 | 影响用户对当日表现的了解，增加需更新UI布局 |

## 状态机 / 事件模型

### 首次启动流程状态机

```
应用启动 (ContentView)
  ↓ 检查 isFirstLaunch
isFirstLaunch == true
  ↓ 显示 OnboardingView
引导页显示中 (currentPage: 0..<3)
  ├─ 点击"下一步" → currentPage += 1
  ├─ 点击"跳过" → 完成引导
  └─ 最后一页点击"开始使用" → 完成引导
  ↓ 完成引导 (appState.completeOnboarding(), isPresented = false)
isFirstLaunch == false
  ↓ 显示 MainTabView
首页显示 (HomeView)
```

### 引导页状态机

```
第1页 (currentPage = 0)
  ↓ 点击"下一步"
第2页 (currentPage = 1)
  ↓ 点击"下一步"
第3页 (currentPage = 2)
  ↓ 点击"开始使用" 或 "跳过"
完成 (isPresented = false)
```

## 错误处理与降级策略

- **AppState 数据缺失**：`HomeView` 访问 `appState` 数据时，若数据缺失（如等级、经验值），应显示默认值（如 "Lv.1 新手"、"0 经验值"），不应崩溃
- **导航目标不存在**：快捷入口导航到其他模块时，若目标视图不存在或初始化失败，应显示错误提示，不应崩溃
- **引导页数据加载失败**：`OnboardingView` 中 `pages` 数组为空或加载失败时，应跳过引导页直接显示主界面，不应阻塞应用启动
- **统计数据计算错误**：今日统计数据计算错误（如除零、负数）时，应显示默认值（如 "0分钟"、"0个"、"0%"），不应崩溃

## 性能考量

- **视图更新频率**：`HomeView` 使用 `@EnvironmentObject` 访问 `AppState`，`AppState` 状态变更会触发视图更新，但首页数据更新频率低（用户等级、经验值、统计数据），性能影响可忽略
- **引导页动画**：`OnboardingView` 使用 `TabView` 和 `withAnimation` 实现页面切换动画，性能可接受
- **导航性能**：快捷入口使用 `NavigationLink` 和 `fullScreenCover` 导航，SwiftUI 自动管理视图生命周期，性能可接受
- **数据读取性能**：从 `AppState` 读取用户数据为内存访问，无I/O开销，性能可忽略

## 参考实现对照（如适用）

| Swift 文件/函数 | 参考来源 | 偏离说明 |
|----------------|--------------|----------|
| `OnboardingView` 多页引导 | SwiftUI 标准模式，无参考实现 | 使用 `TabView` 和页面指示器实现多页引导，为标准实现 |
| `HomeView` 首页布局 | UI设计需求，无参考实现 | 卡片式布局，展示用户信息和快捷入口，为标准首页设计 |

## 设计决策记录（ADR）

### ADR-001：使用 @EnvironmentObject 访问 AppState 而非单例

- **背景**：`HomeView` 需要访问应用全局状态（用户数据、首次启动标志）
- **候选方案**：
  1. 使用 `@EnvironmentObject var appState: AppState` 注入
  2. 使用单例 `AppState.shared` 直接访问
  3. 通过参数传递 `AppState` 实例
- **结论**：选择方案1，`@EnvironmentObject` 符合 SwiftUI 最佳实践，支持依赖注入和测试，视图更新自动响应状态变更
- **后果**：需要在视图层次结构中注入 `AppState`，但 SwiftUI 自动管理，维护成本低

### ADR-002：引导页使用 TabView 而非自定义页面切换

- **背景**：需要实现多页引导流程，支持滑动切换和页面指示器
- **候选方案**：
  1. 使用 `TabView` 和 `tabViewStyle(.page)`
  2. 使用自定义 `ScrollView` 和 `PageTabViewStyle`
  3. 使用第三方引导页库
- **结论**：选择方案1，`TabView` 是 SwiftUI 标准组件，支持页面切换和指示器，代码简单，性能好
- **后果**：页面切换动画和指示器样式受系统限制，但可接受

### ADR-003：快捷入口直接导入 FreePlayView 而非通过路由抽象

- **背景**：快捷入口需要导航到自由练习，需要访问 `FreePlayView`
- **候选方案**：
  1. 直接导入 `FreePlayView` 并使用 `fullScreenCover`
  2. 通过路由抽象层（如 `Router`）访问
  3. 使用 `NavigationLink` 和路径管理
- **结论**：选择方案1，直接导入简单直接，`FreePlayView` 是公开API，无隐藏依赖，代码清晰
- **后果**：`HomeView` 直接依赖 `FreePlayView`，但依赖关系明确，维护成本低
