# 任务列表：数据模型 (Data Models)

**输入**: `specs/6-data-models/` 下设计文档  
**说明**: 本文档为回溯性任务列表，状态为 **已完成（回溯记录）**，所有任务均已标记为已完成 [x]

## 格式：`[ID] [P?] 描述`

- **[P]**: 可并行执行（不同文件，无依赖）
- 路径基于 `current_work/BilliardTrainer/`

---

## 阶段 1：核心数据模型

**目的**: 定义 SwiftData 模型与 Codable 击球记录

- [x] T001 创建 UserProfile SwiftData 模型（Models/UserProfile.swift）
- [x] T002 创建 CourseProgress 模型（Models/UserProfile.swift）
- [x] T003 创建 UserStatistics 模型（Models/UserProfile.swift）
- [x] T004 创建 TrainingSession 模型（Models/UserProfile.swift）
- [x] T005 创建 ShotRecord Codable 结构体（Models/UserProfile.swift 或训练模块；含 timestamp、位置、打点、力度、结果等）

---

## 阶段 2：等级与 SwiftData 配置

**目的**: 用户等级阈值与持久化容器

- [x] T006 定义用户等级阈值（Lv.1 新手 0→Lv.2 入门 500→Lv.3 进阶 1500→Lv.4 熟练 4000→Lv.5 专家 10000）
- [x] T007 在 App 入口配置 SwiftData ModelContainer（App/BilliardTrainerApp.swift）

---

## 阶段 3：物理常量与扩展工具

**目的**: 物理引擎与 UI 共享常量与扩展

- [x] T008 创建 PhysicsConstants（Utilities/Constants/PhysicsConstants.swift）
- [x] T009 创建 SCNVector3 扩展（Utilities/Extensions/SCNVector3+Extensions.swift）
- [x] T010 创建通用 Extensions（Utilities/Extensions/Extensions.swift）

---

## 依赖与执行顺序

### 阶段依赖

- **阶段 1**: 无依赖，可立即开始
- **阶段 2**: 依赖阶段 1
- **阶段 3**: 可与阶段 1 并行，无交叉依赖

### 可并行任务

- T008、T009、T010 可并行（不同文件）

---

## 完成度说明

本功能约 **90%** 完成：

- **已完成**: UserProfile、CourseProgress、UserStatistics、TrainingSession 模型与 SwiftData 集成；等级系统；PhysicsConstants；SCNVector3 与 Extensions；T005 ShotRecord 在技术方案中已定义，实现可分散于训练模块
- **待完善**（如有后续迭代）: ShotRecord 与 TrainingSession.shots 的完整绑定；六维技能雷达的显式持久化与 UI 展示
