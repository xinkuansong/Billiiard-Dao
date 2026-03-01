# Settings（设置）

> 代码路径：`BilliardTrainer/Features/Settings/`
> 文档最后更新：2026-02-27

## 模块定位

设置模块负责管理应用配置项（音效、震动、瞄准辅助线、轨迹预测），展示已购内容，提供使用帮助和反馈入口。不负责购买流程实现，仅提供 UI 入口。

## 入口文件

| 文件 | 职责 | 行数 |
|------|------|------|
| `SettingsView.swift` | 设置主视图，包含游戏设置、购买管理、关于、反馈等 Section，以及 PurchasedContentView 和 HelpView 子视图 | ~210 |

## 核心概念与术语

| 术语 | 含义 |
|------|------|
| @AppStorage | SwiftUI 属性包装器，用于持久化用户设置到 UserDefaults |
| PurchasedContentView | 已购内容视图，展示已解锁和未解锁的课程包 |
| HelpView | 使用帮助视图，说明基础操作和相机控制方法 |

## 端到端流程

```
用户打开设置 Tab → SettingsView 渲染 → 读取 @AppStorage 设置值 → 用户修改设置 → 自动保存到 UserDefaults → AudioManager 读取设置
```

## 对外能力（Public API）

- `SettingsView`：设置主视图
- `PurchasedContentView`：已购内容视图
- `HelpView`：使用帮助视图
- `@AppStorage` 键值：
  - `soundEnabled`：音效开关
  - `hapticEnabled`：震动反馈开关
  - `aimLineEnabled`：瞄准辅助线开关
  - `trajectoryEnabled`：轨迹预测开关

## 依赖与边界

- **依赖**：SwiftUI（UI 框架）、@AppStorage（UserDefaults 持久化）
- **被依赖**：App 层 TabView 导航（ContentView）、AudioManager（读取音效设置）
- **禁止依赖**：其他 Features 模块、Core 层物理引擎（通过 AudioManager 间接使用）

## 与其他模块的耦合点

- **AudioManager**：读取 `soundEnabled` 和 `hapticEnabled` 设置（需同步）
- **Core/Scene**：读取 `aimLineEnabled` 和 `trajectoryEnabled` 设置（需同步）
- **Models/UserProfile**：UserProfile 模型也包含相同设置字段，需保持一致性

## 关键数据结构

| 结构/枚举 | 字段/Case | 单位/生命周期 |
|-----------|-----------|---------------|
| `SettingsView` | `@AppStorage` 属性：soundEnabled, hapticEnabled, aimLineEnabled, trajectoryEnabled | 设置值持久化到 UserDefaults |
| `PurchasedContentView` | 无参数 | 视图组件，展示购买状态（当前硬编码） |
| `HelpView` | 无参数 | 视图组件，展示帮助信息 |

## 最近变更记录

| 日期 | 变更摘要 | 影响面 |
|------|----------|--------|
| 2026-02-27 | 初始文档创建 | 无 |
