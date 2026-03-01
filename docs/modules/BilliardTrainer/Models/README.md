# Models

> 代码路径：`BilliardTrainer/Models/`
> 文档最后更新：2026-02-27

## 模块定位

Models 模块提供 SwiftData 数据模型定义，包括用户档案、课程进度、用户统计与训练会话。它不处理业务逻辑，仅定义数据结构与基础计算属性（如经验值升级、进球率计算）。

## 入口文件

| 文件 | 职责 | 行数 |
|------|------|------|
| `UserProfile.swift` | SwiftData 模型定义：UserProfile（用户档案）、CourseProgress（课程进度）、UserStatistics（统计数据）、TrainingSession（训练会话） | ~400 |

## 核心概念与术语

| 术语 | 含义 |
|------|------|
| UserProfile | 用户档案模型，包含 ID、昵称、等级、经验值、设置项（音效/震动/瞄准线/轨迹） |
| CourseProgress | 课程进度模型，关联用户与课程，记录完成状态、最高分数、练习次数 |
| UserStatistics | 用户统计数据模型，记录击球/进球统计、各角度/杆法使用、签到天数 |
| TrainingSession | 训练会话模型，记录单次训练的类型、时长、击球/进球/得分 |
| ShotType | 击球类型枚举：straight（直球）、angle30/45/60（角度球） |
| SpinType | 杆法类型枚举：center（中杆）、top（高杆）、draw（低杆）、left/right（左右塞） |
| experienceToNextLevel | 经验值到下一级所需阈值：500/1500/4000/10000 |

## 端到端流程

```
用户创建 → UserProfile 初始化 → 关联 UserStatistics → 
训练开始 → TrainingSession 创建 → 记录击球/进球 → 
训练结束 → TrainingSession.endSession() → 更新 UserStatistics → 
保存到 ModelContainer → 持久化
```

## 对外能力（Public API）

- `UserProfile`：用户档案模型，提供 `addExperience(_:)`、`hasPurchased(_:)`、`addPurchase(_:)` 方法
- `CourseProgress`：课程进度模型，提供 `markCompleted(score:)` 方法
- `UserStatistics`：统计数据模型，提供 `recordShot(type:made:)`、`recordSpin(type:)`、`addPracticeTime(_:)`、`updateCheckIn()` 方法
- `TrainingSession`：训练会话模型，提供 `endSession()` 方法，计算属性 `duration`、`accuracy`
- `ShotType`、`SpinType`：枚举类型，用于统计分类

## 依赖与边界

- **依赖**：Foundation、SwiftData
- **被依赖**：App（ModelContainer schema）、Statistics（UserStatistics 查询与展示）、Settings（UserProfile.settings 读写）、Training（TrainingSession 创建与更新）
- **禁止依赖**：不应依赖 Features 或 Core 模块

## 与其他模块的耦合点

- **App**：ModelContainer schema 包含 Models 模块的所有 @Model 类
- **Statistics**：StatisticsView 查询 UserStatistics 并展示统计数据
- **Settings**：SettingsView 读写 UserProfile.settings（soundEnabled、hapticEnabled 等）
- **Training**：TrainingViewModel 创建 TrainingSession 并调用 UserStatistics 更新方法

## 关键数据结构

| 结构/枚举 | 字段/Case | 单位/生命周期 |
|-----------|-----------|---------------|
| UserProfile | id: UUID, nickname: String, level: Int (1-5), experience: Int, soundEnabled/hapticEnabled/aimLineEnabled/trajectoryEnabled: Bool | SwiftData 持久化 |
| CourseProgress | userId: UUID, courseId: Int, isCompleted: Bool, bestScore: Int, practiceCount: Int | SwiftData 持久化 |
| UserStatistics | userId: UUID, totalShots/totalPocketed/totalPracticeTime: Int, consecutiveDays: Int, lastPracticeDate: Date? | SwiftData 持久化 |
| TrainingSession | id: UUID, userId: UUID, trainingType: String, startTime/endTime: Date?, totalShots/pocketedCount/score: Int | SwiftData 持久化 |
| ShotType | straight, angle30, angle45, angle60 | 枚举 |
| SpinType | center, top, draw, left, right | 枚举 |

## 最近变更记录

| 日期 | 变更摘要 | 影响面 |
|------|----------|--------|
| 2026-02-27 | 创建模块文档 | 无 |
