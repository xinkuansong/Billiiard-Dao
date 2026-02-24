# 球道 (Billiard Trainer) Constitution

## Core Principles

### I. 物理真实性优先

所有击球模拟 MUST 基于事件驱动引擎与解析式运动方程实现，确保零累积误差。旋转系统（高杆、低杆、左右塞）、库边反弹修正、Squirt 效应 MUST 基于专业台球物理公式（Alciatore、Mathavan 模型），不得使用简化近似替代。连续碰撞检测 MUST 消除隧道效应。物理参数（球径 57.15mm、球质量 170g、台面摩擦系数 0.2、库边弹性 0.85、球球弹性 0.95）MUST 以真实台球数据为基准。

### II. 视觉-物理分离架构

物理计算层（EventDrivenEngine）与视觉渲染层（SceneKit）MUST 严格解耦。物理引擎一次性计算完整轨迹，TrajectoryRecorder 作为桥梁连接两层，支持可重复回放。不得在 SceneKit 物理引擎中执行台球运动计算。视觉层仅负责根据轨迹数据驱动 USDZ 模型动画。

### III. 教学价值导向

功能设计 MUST 服务于教学目标，非娱乐化导向。App 擅长理论与策略侧重内容（瞄准原理、分离角计算、走位规划、颗星公式）。课程体系采用结构化 18 课设计（免费 3 课 + 基础 5 课 + 进阶 6 课 + 高级 4 课），训练场按技能维度拆分（瞄准、杆法、翻袋、K 球、传球、解球、颗星）。身体力学、真实手感等内容 SHOULD 以视频教学补充，不强行在 App 内模拟。

### IV. Apple 生态原生

技术栈 MUST 使用 Swift 5.x + SwiftUI + SceneKit + SwiftData，架构模式为 MVVM。不得引入第三方重型游戏引擎或物理引擎。内购 MUST 使用 StoreKit 2，数据持久化 MUST 使用 SwiftData（iOS 17+）。UIKit 仅在 SwiftUI 无法满足复杂交互时作为补充。目标平台仅 iPhone，iOS 17.0+。

### V. MVP 渐进交付

V1.0 MUST 聚焦核心 MVP：物理引擎 + L1-L8 课程 + 瞄准/杆法训练场 + 基础数据统计 + 内购。功能膨胀 MUST 被拒绝——挑战模式、每日系统、AI 对战等归入 V1.1/V1.2/V2.0 迭代。每个功能模块 SHOULD 独立可测试、独立可交付。商业模式为纯付费解锁（基础 ¥18、进阶 ¥25、高级 ¥20、全功能 ¥48），不含广告。

## 合规与质量

- 所有数据 MUST 仅存储在用户设备本地，不上传服务器
- 隐私政策 MUST 在上架前准备完毕
- 年龄分级为 4+（无暴力/赌博内容）
- MUST 提供恢复购买功能
- MUST 适配全系 iPhone 屏幕（SE 至 Pro Max）、深色模式、动态字体
- 启动时间 MUST < 3 秒，帧率 MUST 稳定 60fps，无内存泄漏

## 开发工作流

- 每个功能模块 MUST 有独立的 SpecKit 规范（spec.md → plan.md → tasks.md）
- 代码提交前 SHOULD 通过对应 tasks.md 中的验收标准
- 物理引擎参数修改 MUST 记录变更理由与测试结果
- 宪法修订 MUST 遵循语义化版本号，重大原则变更需要明确理由

## Governance

本宪法为球道项目的最高开发准则，所有 spec、plan、tasks 文档 MUST 与宪法原则保持一致。宪法修订需记录变更理由并更新版本号。原则冲突时，物理真实性 > 教学价值 > MVP 范围 > 技术栈约束。

**Version**: 1.0.0 | **Ratified**: 2026-02-20 | **Last Amended**: 2026-02-20
