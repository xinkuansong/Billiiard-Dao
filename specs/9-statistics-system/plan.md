# 实施计划：数据统计系统

**Branch**: `9-statistics-system` | **Date**: 2026-02-20 | **Spec**: specs/9-statistics-system/spec.md
**Status**: 草案 (Draft)

## 概要

为球道 App 构建完整的数据统计系统，包括数据采集管道、图表可视化和六维技能雷达图，将训练数据转化为用户可感知的进步反馈。

## 技术上下文

**Language/Version**: Swift 5.x
**Primary Dependencies**: SwiftUI, Swift Charts (iOS 16+), SwiftData
**Storage**: SwiftData (UserStatistics, TrainingSession)
**Target Platform**: iOS 17.0+ (iPhone)
**Project Type**: iOS 单应用

## 关键技术决策

### 决策 1: 图表框架选择

- **选择**: Swift Charts（Apple 原生）
- **理由**: iOS 16+ 原生支持，无需第三方依赖，与 SwiftUI 深度集成
- **替代方案**: Charts (第三方) — 被拒绝，违反宪法「Apple 生态原生」原则

### 决策 2: 六维技能雷达图实现

- **选择**: SwiftUI Path 自绘
- **理由**: Swift Charts 不支持雷达图，Path 绘制灵活且性能好
- **六维度**: 瞄准准度、杆法控制、走位能力、库边技术、策略思维、解球能力
- **计算方式**: 各维度 0-100 分，基于对应统计数据加权计算

### 决策 3: 数据采集管道

- **选择**: 在 TrainingViewModel 击球结束时同步写入 ShotRecord，训练结束时批量保存 TrainingSession
- **数据流**: BilliardScene → TrainingViewModel.recordShot() → sessionShots 数组 → saveTrainingSession() → SwiftData
- **角度计算**: 从母球位置和目标球位置计算击球角度，映射到 6 个区间（0°, 15°, 30°, 45°, 60°, 75°）

### 决策 4: 练习时长聚合

- **选择**: 基于 TrainingSession.startTime/endTime 按日聚合
- **存储**: 不额外存储聚合数据，查询时实时计算
- **展示**: Swift Charts 柱状图，最近 7 天/30 天

## 项目结构

```text
Features/Statistics/
├── StatisticsView.swift        # 已有 - 需改造为数据驱动
├── Views/
│   ├── OverviewCard.swift      # 新建 - 总览卡片
│   ├── AccuracyCard.swift      # 新建 - 角度准确率
│   ├── SpinUsageCard.swift     # 新建 - 杆法使用统计
│   ├── PracticeTimeChart.swift # 新建 - 练习时长图表
│   ├── SkillRadarView.swift    # 新建 - 六维雷达图
│   └── SessionHistoryView.swift# 新建 - 历史会话列表
├── ViewModels/
│   └── StatisticsViewModel.swift # 新建 - 统计数据聚合
└── Helpers/
    └── AngleCalculator.swift    # 新建 - 击球角度计算
```

## 风险与缓解

| 风险 | 缓解措施 |
|------|---------|
| 训练中缺少足够的 ShotRecord 数据 | 提供示例数据用于 UI 开发，空状态友好提示 |
| 雷达图六维度中部分维度缺少数据支撑 | 初期可用占位值，后续迭代完善计算公式 |
| Swift Charts 样式定制受限 | 评估后降级为 Path 自绘 |
