# App - 设计与约束

> 对应 README：[README.md](./README.md)
> 文档最后更新：2026-02-27

## 设计目标与非目标

- **目标**：提供轻量级应用入口与全局状态管理，确保 SwiftData 容器与 AppState 在应用启动时正确初始化并注入到视图树
- **非目标**：不处理具体业务逻辑（如训练流程、课程进度计算），不管理 UI 细节（如 TabView 的选中状态由子视图管理）

## 不变量与约束（改动护栏）

### 单位与坐标系

- 无物理单位依赖（App 层不涉及物理计算）
- 屏幕方向使用 UIKit 标准枚举 `UIInterfaceOrientationMask`

### 数值稳定性保护

- `hasLaunchedBefore` UserDefaults 键必须保持稳定，不可随意变更键名（影响首次启动判断）
- ModelContainer 初始化失败必须 `fatalError`（启动关键路径，无法降级）

### 时序与状态约束

- AppState 必须在 `BilliardTrainerApp` 的 `@StateObject` 中初始化，确保生命周期与 App 一致
- ContentView 必须在 `onAppear` 中检查 `isFirstLaunch`，避免状态未初始化时渲染错误视图
- OrientationHelper 的方向变更请求必须在窗口场景可用时执行，iOS 16+ 使用 `requestGeometryUpdate`，旧版本使用 `attemptRotationToDeviceOrientation`

### 常量与阈值清单

| 常量/阈值 | 值 | 来源/理由 | 改动影响 |
|-----------|-----|----------|----------|
| UserDefaults key "hasLaunchedBefore" | "hasLaunchedBefore" | 首次启动标记 | 变更会导致所有用户重新看到引导页 |
| MainTabView.tint | .green | 台球主题色 | 影响所有 Tab 图标颜色 |
| Tab 数量 | 5 | 功能模块数量 | 新增 Tab 需同步更新 MainTabView |

## 状态机 / 事件模型

```
应用启动
  ↓
检查 UserDefaults["hasLaunchedBefore"]
  ↓
false → isFirstLaunch = true → 显示 OnboardingView
  ↓
true → isFirstLaunch = false → 显示 MainTabView
  ↓
用户操作 → AppState 状态更新 → 子视图响应
```

## 错误处理与降级策略

- **ModelContainer 初始化失败**：`fatalError`（启动关键路径，无法降级）
- **用户数据加载失败**：创建新 UserProfile 作为后备，记录错误日志
- **方向变更请求失败**：记录警告日志但不中断流程（iOS 可能在场景过渡期拒绝请求）

## 性能考量

- ModelContainer 使用单例模式，避免重复创建
- AppState 使用 `@StateObject` 确保单例，避免重复初始化
- OrientationHelper 使用静态方法，避免实例化开销

## 参考实现对照（如适用）

| Swift 文件/函数 | pooltool 对应 | 偏离说明 |
|----------------|--------------|----------|
| 无 | 无 | App 层无物理计算，无需对照 |

## 设计决策记录（ADR）

### 使用 @StateObject 而非 @ObservedObject 管理 AppState
- **背景**：需要确保 AppState 生命周期与 App 一致，避免重复创建
- **候选方案**：@StateObject（当前）、@ObservedObject、单例模式
- **结论**：@StateObject 确保在 App 作用域内单例，且自动管理生命周期
- **后果**：AppState 必须通过 @EnvironmentObject 注入到子视图

### ModelContainer 初始化失败使用 fatalError
- **背景**：SwiftData 容器是应用数据持久化的基础，初始化失败无法降级
- **候选方案**：fatalError（当前）、返回可选值、使用内存存储
- **结论**：启动关键路径失败应 fail-fast，避免后续数据操作异常
- **后果**：应用无法启动，需修复数据模型或存储权限问题

### OrientationHelper 使用静态方法
- **背景**：屏幕方向控制是全局状态，无需实例化
- **候选方案**：静态方法（当前）、单例模式、环境值注入
- **结论**：静态方法最简洁，符合工具类设计模式
- **后果**：方向状态无法通过依赖注入测试，需通过 UIApplication 模拟测试
