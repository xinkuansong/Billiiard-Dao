# Statistics（统计）

> 代码路径：`BilliardTrainer/Features/Statistics/`
> 文档最后更新：2026-02-27

## 模块定位

统计模块负责展示用户训练数据概览，包括总练习时长、总进球数、平均进球率、按角度分类的进球率、每周练习时长分布。不负责数据收集和计算，仅负责从 UserStatistics 模型读取并展示。

## 入口文件

| 文件 | 职责 | 行数 |
|------|------|------|
| `StatisticsView.swift` | 统计视图，包含 OverviewCard、AccuracyCard、PracticeTimeCard、SkillRadarCard 组件 | ~240 |

## 核心概念与术语

| 术语 | 含义 |
|------|------|
| OverviewCard | 总览卡片，显示总练习时长、总进球数、平均进球率 |
| AccuracyCard | 进球率卡片，按角度分类显示直球、30°、45°、60°进球率 |
| PracticeTimeCard | 练习时长卡片，显示本周每日练习时长的柱状图 |
| SkillRadarCard | 技能雷达图卡片，V1.2 占位功能 |

## 端到端流程

```
用户打开统计 Tab → StatisticsView 渲染 → 读取 UserStatistics（待集成） → 展示各统计卡片 → 用户查看数据
```

## 对外能力（Public API）

- `StatisticsView`：统计主视图
- `OverviewCard`：总览卡片组件
- `AccuracyCard`：进球率卡片组件
- `PracticeTimeCard`：练习时长卡片组件
- `SkillRadarCard`：技能雷达图卡片组件（占位）

## 依赖与边界

- **依赖**：SwiftUI（UI 框架）、Models/UserStatistics（SwiftData 模型，当前为硬编码数据）
- **被依赖**：App 层 TabView 导航（ContentView）
- **禁止依赖**：其他 Features 模块、Core 层、物理引擎

## 与其他模块的耦合点

- **Models 层**：依赖 UserStatistics SwiftData 模型读取统计数据（当前为硬编码，待集成）
- **Training 模块**：训练完成后更新统计数据（当前未实现）

## 关键数据结构

| 结构/枚举 | 字段/Case | 单位/生命周期 |
|-----------|-----------|---------------|
| `OverviewCard` | 无参数 | 视图组件，当前使用硬编码数据 |
| `AccuracyCard` | 无参数 | 视图组件，当前使用硬编码数据 |
| `PracticeTimeCard` | `weekData: [(day, minutes, isToday)]` | 视图组件，当前使用硬编码数据 |
| `SkillRadarCard` | 无参数 | 视图组件，V1.2 占位 |

## 最近变更记录

| 日期 | 变更摘要 | 影响面 |
|------|----------|--------|
| 2026-02-27 | 初始文档创建 | 无 |
