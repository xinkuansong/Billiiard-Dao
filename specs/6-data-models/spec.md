# 功能规格：数据模型 (Data Models)

**功能分支**: `6-data-models`  
**创建日期**: 2025-02-20  
**状态**: 已完成（回溯记录）  
**说明**: 本文档为回溯性规格，记录已实现的球道 (Billiard Trainer) iOS App 数据模型系统

## 概述

球道 App 采用 SwiftData (iOS 17+) 实现本地持久化，所有数据存储于设备本地，无服务器上传。核心模型集中定义于 Models/UserProfile.swift，涵盖用户档案、课程进度、统计数据与训练会话。

## 用户场景与测试 *(回溯)*

### 用户故事 1 - 用户档案持久化 (优先级: P1)

用户首次启动 App 时，系统自动创建用户档案；用户修改昵称、等级、经验值或偏好设置后，数据持久保存并在下次启动时恢复。

**独立测试**: 修改昵称或设置后重启 App，验证数据正确恢复。

**验收场景**:
1. **Given** 首次启动 App，**When** 用户进入主界面，**Then** 自动创建默认用户档案（昵称「新玩家」、等级 1、经验 0）
2. **Given** 用户已存在，**When** 修改昵称或音效/触感/瞄准线等设置，**Then** 数据持久化，重启后保持
3. **Given** 用户完成训练获得经验，**When** 经验值达到等级阈值，**Then** 自动升级并正确显示等级名称（新手→入门→进阶→熟练→专家）

---

### 用户故事 2 - 课程进度追踪 (优先级: P2)

用户完成课程中的某一课时，系统记录完成状态、最高分与练习次数；支持按课程 ID 查询当前进度。

**独立测试**: 完成一课时后，可查询 CourseProgress 验证 isCompleted、bestScore、practiceCount。

**验收场景**:
1. **Given** 用户开始某课程某课时，**When** 完成练习并提交分数，**Then** 记录完成状态、完成时间及分数
2. **Given** 用户多次练习同一课时，**When** 得分高于历史最高分，**Then** 更新 bestScore
3. **Given** 用户有课程进度，**When** 查询该用户某课程，**Then** 返回对应 CourseProgress 或空

---

### 用户故事 3 - 训练统计与技能维度 (优先级: P2)

用户进行训练时，系统累积总击球数、进球数、练习时长、直球/角度球进球率、各杆法使用次数；支持六维技能雷达（瞄准准度、杆法控制、走位能力、库边技术、策略思维、解球能力）。

**独立测试**: 完成多次训练后，UserStatistics 中 totalShots、totalPocketed、各种 accuracy 计算正确。

**验收场景**:
1. **Given** 用户完成一次训练，**When** 保存会话，**Then** UserStatistics 更新 totalShots、totalPocketed、totalPracticeTime
2. **Given** 用户使用不同杆法（中杆/高杆/低杆/左塞/右塞）击球，**When** 记录击球，**Then** 对应杆法计数累加
3. **Given** 用户连续多日练习，**When** 每日首次练习，**Then** 更新 consecutiveDays 与 lastPracticeDate

---

### 用户故事 4 - 训练会话记录 (优先级: P3)

用户开始训练时创建 TrainingSession，结束时记录击球数、进球数、得分、时长；支持查询历史会话。

**独立测试**: 完成一次训练后，可查询 TrainingSession 验证 totalShots、pocketedCount、score、duration。

**验收场景**:
1. **Given** 用户开始某类型训练，**When** 创建会话，**Then** 生成 id、记录 startTime、trainingType
2. **Given** 训练进行中，**When** 用户结束训练，**Then** 设置 endTime，计算 duration 与 accuracy
3. **Given** 会话已保存，**When** 按 userId 查询，**Then** 返回该用户所有 TrainingSession

---

### 边界情况

- 无用户时：首次启动自动创建 UserProfile，避免空引用
- 无 UserStatistics 时：保存训练会话时自动创建并插入
- 经验值升级：超过 5 级不再晋升，等级名称显示「大师」
- 本地数据：无网络，数据仅存设备，符合隐私要求

## 需求 *(回溯)*

### 功能需求

- **FR-001**: 系统必须使用 SwiftData (iOS 17+) 实现本地持久化
- **FR-002**: 所有数据必须仅存储于设备本地，不上传至服务器
- **FR-003**: 系统必须定义 UserProfile 模型（id、nickname、level、experience、settings、createdAt）
- **FR-004**: 系统必须定义 CourseProgress 模型（completed lessons、current lesson、lesson scores）
- **FR-005**: 系统必须定义 UserStatistics 模型（总击球数、进球数、练习时长、直球/角度球进球率、杆法使用统计）
- **FR-006**: 系统必须定义 TrainingSession 模型（id、type、startTime、endTime、shots、score）
- **FR-007**: 系统必须定义 ShotRecord 结构体（Codable）：timestamp、target ball position、cue ball position、aim point、spin parameters、power、result、final cue ball position
- **FR-008**: 用户等级系统必须按阈值晋升：Lv.1 新手(0) → Lv.2 入门(500) → Lv.3 进阶(1500) → Lv.4 熟练(4000) → Lv.5 专家(10000)
- **FR-009**: 系统必须支持六维技能雷达数据基础：瞄准准度、杆法控制、走位能力、库边技术、策略思维、解球能力
- **FR-010**: 系统必须在 App 入口配置 SwiftData ModelContainer，注册所有 @Model 类型
- **FR-011**: 系统必须提供物理常量（PhysicsConstants）及 SCNVector3、通用扩展（Extensions）供模型与业务层使用

### 关键实体

- **UserProfile**: 用户档案；属性含 id、nickname、level、experience、createdAt、lastActiveAt、purchasedProducts、soundEnabled、hapticEnabled、aimLineEnabled、trajectoryEnabled；逻辑关联 CourseProgress、UserStatistics、TrainingSession（通过 userId）
- **CourseProgress**: 课程进度；关联 userId、courseId；含 isCompleted、completedAt、bestScore、practiceCount
- **UserStatistics**: 用户统计；关联 userId；含 totalShots、totalPocketed、totalPracticeTime、直球/角度球统计、各杆法计数、consecutiveDays、lastPracticeDate
- **TrainingSession**: 训练会话；含 id、userId、trainingType、startTime、endTime、totalShots、pocketedCount、score
- **ShotRecord**: 单次击球记录（Codable）；含 timestamp、target ball position、cue ball position、aim point、spin parameters、power、result、final cue ball position

## 成功标准 *(回溯)*

### 可衡量结果

- **SC-001**: 用户档案在 App 重启后可正确恢复，无数据丢失
- **SC-002**: 课程进度、训练会话、统计数据可正确写入与读出 SwiftData 存储
- **SC-003**: 等级与经验值计算正确，经验达到阈值时自动晋级
- **SC-004**: UserStatistics 中各进球率（overallAccuracy、straightShotAccuracy、angle*Accuracy）计算无误
- **SC-005**: ModelContainer 配置无误，启动时无崩溃，Schema 包含 UserProfile、CourseProgress、UserStatistics、TrainingSession

## 源文件

| 文件 | 说明 |
|------|------|
| Models/UserProfile.swift | 所有 @Model 类（UserProfile、CourseProgress、UserStatistics、TrainingSession） |
| Utilities/Constants/PhysicsConstants.swift | 物理引擎常量（BallPhysics、TablePhysics、SpinPhysics 等） |
| Utilities/Extensions/Extensions.swift | 通用扩展（Color、View、Double、Date、Array 等） |
| Utilities/Extensions/SCNVector3+Extensions.swift | SCNVector3 向量运算扩展（向量运算被物理引擎依赖） |
