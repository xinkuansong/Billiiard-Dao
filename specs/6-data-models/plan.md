# 实施计划：数据模型 (Data Models)

**分支**: `6-data-models` | **日期**: 2025-02-20 | **规格**: [spec.md](./spec.md)  
**说明**: 本文档为回溯性计划，记录已实现数据模型的技术决策与架构

## 摘要

球道 App 数据层采用 SwiftData（iOS 17+）进行本地持久化，所有 @Model 类集中在 Models/UserProfile.swift 中。数据仅存于设备本地，满足隐私要求；经验/等级采用阈值推进制；物理常量与扩展工具类提供支撑。

## 技术上下文

**语言/版本**: Swift 5.x  
**主要依赖**: SwiftData（基于 Swift Concurrency，替代 Core Data）  
**目标平台**: iOS 17+  
**项目类型**: 原生 iOS 应用  
**约束**: 无联网、纯本地存储；单设备单用户  
**规模**: Models/ 下 UserProfile.swift 单文件，Utilities/ 下常量与扩展若干

## 核心架构决策

### 1. SwiftData 而非 Core Data

- **决策**: 使用 SwiftData 作为持久化框架
- **理由**:
  - SwiftData 为 iOS 17+ 原生现代 API，与 Swift 类型系统更契合
  - 声明式 @Model 宏，无需 .xcdatamodeld 图形建模
  - 与 SwiftUI、@Query 集成更自然
- **实现**: Schema 显式注册 UserProfile、CourseProgress、UserStatistics、TrainingSession；ModelContainer 在 BilliardTrainerApp 中创建并注入

### 2. 单文件集中模型

- **决策**: 所有 @Model 类定义于 Models/UserProfile.swift 单文件
- **理由**:
  - 模型数量有限（4 个 @Model 类），集中管理便于维护
  - 避免循环依赖，便于 SwiftData Schema 一次性加载
- **实现**: UserProfile、CourseProgress、UserStatistics、TrainingSession 均在同一文件中，通过 userId 建立逻辑关联

### 3. 全本地、无服务器

- **决策**: 所有数据仅存储于设备本地，无云端同步
- **理由**:
  - 隐私要求：用户数据不出设备
  - 简化架构，无需后端、认证、同步逻辑
- **实现**: ModelConfiguration 使用 `isStoredInMemoryOnly: false`，持久化至本地 SQLite；无网络相关代码

### 4. 经验/等级阈值推进

- **决策**: 等级采用固定阈值经验值推进
- **理由**:
  - 规则清晰，便于展示与计算
  - 与常见游戏等级体系一致
- **实现**: UserProfile.experienceToNextLevel 按 level 返回 500/1500/4000/10000；addExperience 后 checkLevelUp 循环晋级；最高 Lv.5

### 5. ShotRecord 为 Codable 结构体

- **决策**: 单次击球记录使用 Codable struct，而非 @Model
- **理由**:
  - 击球记录为会话内细粒度数据，可嵌入 TrainingSession 或作为 JSON 存储
  - Codable 便于序列化、日志、导出
- **实现**: ShotRecord 定义 timestamp、位置、打点、力度、结果等字段；可按需挂载至 TrainingSession

### 6. 物理常量与扩展分离

- **决策**: 物理常量、向量扩展、通用扩展放入 Utilities/
- **理由**:
  - 物理引擎与数据层共享常量（如球直径、台面尺寸）
  - SCNVector3 扩展被物理引擎广泛依赖
  - 通用扩展（Date、Int、Color 等）供 UI 与业务使用
- **实现**: PhysicsConstants.swift、SCNVector3+Extensions.swift、Extensions.swift

## 项目结构

### 文档（本功能）

```text
specs/6-data-models/
├── spec.md    # 本功能规格（回溯）
├── plan.md    # 本实施计划（回溯）
└── tasks.md   # 任务列表（回溯）
```

### 源代码

```text
current_work/BilliardTrainer/
├── Models/
│   └── UserProfile.swift      # UserProfile, CourseProgress, UserStatistics, TrainingSession
├── App/
│   └── BilliardTrainerApp.swift   # ModelContainer 配置、Schema 注册、AppState 用户加载
└── Utilities/
    ├── Constants/
    │   └── PhysicsConstants.swift # BallPhysics, TablePhysics, SpinPhysics, StrokePhysics, 等
    └── Extensions/
        ├── Extensions.swift       # Color, View, Double, Date, Array, CGPoint, Int, TimeInterval, HapticFeedback
        └── SCNVector3+Extensions.swift  # 向量运算（length, normalized, dot, cross, +, -, *, /, rotatedY）
```

### 结构说明

- **UserProfile**: 主实体，持有等级、经验、设置；AppState.loadOrCreateUser 负责创建或加载
- **CourseProgress**: 按 userId + courseId 一对多；未使用 @Relationship，通过 FetchDescriptor 按 userId 查询
- **UserStatistics**: 按 userId 一对一；saveTrainingSession 时通过 updateUserStatistics 创建或更新
- **TrainingSession**: 按 userId 一对多；AppState.saveTrainingSession 写入并联动 UserStatistics
