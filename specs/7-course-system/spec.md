# 功能规格：课程系统 (Course System)

**功能分支**: `7-course-system`  
**创建日期**: 2025-02-20  
**状态**: 草案 (Draft)  
**说明**: 球道 (Billiard Trainer) iOS App 课程系统是 V1.0 MVP 最关键的剩余功能。当前仅存在课程列表 UI（约 20% 完成），课程内容与流程尚未实现。

## 概述

课程系统提供结构化的台球教学流程，包含教学阶段（图文讲解、动画演示）、练习阶段（球桌场景、任务执行、结果反馈）和完成阶段（得分统计、星级评价）。V1.0 MVP 需实现 L1-L8 共八节课程，其中 L1-L3 免费，L4-L8 需通过 IAP 购买（¥18）。

## 用户故事与验收场景

### 用户故事 1 - 课程学习流程 (优先级: P1)

用户点击课程列表中的课程卡片后，进入课程场景；按教学→练习→完成三阶段完成课时，可随时通过返回按钮退出。

**验收场景**:

1. **Given** 用户在课程列表，**When** 点击未锁定的课程卡片（如 L1），**Then** 进入该课程场景，显示第一个教学步骤
2. **Given** 用户在教学阶段，**When** 阅读完文字/插图并看完动画演示，**Then** 显示「下一步」按钮，点击后进入下一步骤或练习阶段
3. **Given** 用户在练习阶段，**When** 看到任务提示（如「完成 5 个直球瞄准」），**Then** 球桌场景就绪，可执行击球操作
4. **Given** 用户完成练习任务，**When** 系统判定通过（如 L2 命中 ≥3），**Then** 进入完成阶段，显示得分、星级、返回/下一课按钮
5. **Given** 用户在课程任意阶段，**When** 点击返回/退出，**Then** 返回课程列表，进度按完成阶段保存（教学进度可选性保存）

**独立测试**: 从课程列表进入 L1，完整走完教学→练习→完成，验证三阶段切换与返回逻辑。

---

### 用户故事 2 - 课程进度与评分 (优先级: P2)

用户完成课时后，系统记录完成状态、最高分、练习次数；课程列表与首页显示正确的完成进度；支持重玩以刷新成绩。

**验收场景**:

1. **Given** 用户完成 L1 测验并通过（≥80%），**When** 点击「完成」或「下一课」，**Then** CourseProgress 更新 isCompleted、bestScore、practiceCount
2. **Given** 用户多次练习 L2，**When** 某次得分高于历史最高分，**Then** bestScore 更新为该次分数
3. **Given** 用户已完成 L1-L3，**When** 进入课程列表，**Then** L1-L3 显示完成状态（✓），首页学习进度显示 3/18 或类似
4. **Given** 用户已完成某课，**When** 再次进入该课并完成，**Then** 可刷新 bestScore，practiceCount 累加

**独立测试**: 完成 L2 后查询 CourseProgress(courseId=2)，验证 isCompleted、bestScore、practiceCount；重玩后验证 bestScore 更新。

---

### 用户故事 3 - 课程解锁与 IAP (优先级: P3)

免费课程 L1-L3 始终可进入；基础课程 L4-L8 需购买「基础课程包」（¥18）后解锁；未购买时点击显示购买入口或提示。

**验收场景**:

1. **Given** 用户未购买基础课程包，**When** 点击 L4-L8 任一课程，**Then** 显示购买弹窗或跳转购买页，不进入课程内容
2. **Given** 用户已购买基础课程包，**When** 点击 L4-L8，**Then** 正常进入课程场景
3. **Given** 用户完成购买，**When** App 重启或从后台恢复，**Then** 已购状态正确恢复（通过 StoreKit 验证）
4. **Given** 用户在设置页，**When** 点击「恢复购买」，**Then** 重新验证购买记录并更新 unlockedCourses

**独立测试**: 未购买时 L4 点击应弹出购买；购买后 L4 可进入；重启后仍保持已购状态。

---

## 课程内容规格 (L1-L8)

### 免费课程 (L1-L3)

| 课程 | 标题 | 时长 | 教学内容 | 练习任务 | 通过条件 |
|-----|------|------|----------|----------|----------|
| L1 | 认识台球 | 5min | 规则、术语、基本概念 | 测验 3 题 | 正确率 ≥80% |
| L2 | 瞄准入门 | 8min | 直球瞄准、厚薄球概念 | 完成 5 个直球 | 进袋 ≥3 |
| L3 | 第一次进球 | 10min | 直球练习说明 | 完成 10 个直球 | 进袋 10 个 |

### 基础课程 (L4-L8，¥18)

| 课程 | 标题 | 时长 | 教学内容 | 练习任务 | 通过条件 |
|-----|------|------|----------|----------|----------|
| L4 | 角度球基础 | 12min | 30°/45°/60° 角度进球 | 5×30° + 5×45° | 命中率 ≥50% |
| L5 | 打点入门 | 12min | 中杆、高杆、低杆 | 各技法成功 ≥2 次 | 每类 ≥2 |
| L6 | 分离角原理 | 10min | 预判母球碰后方向 | 预测角度 + 选厚薄 | 正确率 ≥60% |
| L7 | 左右塞基础 | 12min | 塞球对库边的影响 | 完成全部练习 | 完成所有 |
| L8 | 单球走位 | 15min | 进球 + 控制母球落点 | 走位成功 | 成功 ≥3 次 |

---

## 功能需求

### 课程流程与场景

- **FR-001**: 系统必须支持课程三阶段流：教学 (Teaching) → 练习 (Practice) → 完成 (Completion)
- **FR-002**: 教学阶段必须支持多步骤：每步含文本、插图（可选）、动画演示（可选）、下一步按钮
- **FR-003**: 练习阶段必须复用现有 BilliardScene、EventDrivenEngine、瞄准系统、TrainingSceneView 相关能力
- **FR-004**: 完成阶段必须显示：得分统计、星级评价 (1-5)、返回列表/下一课按钮
- **FR-005**: 每课时必须有明确的通过条件（测验正确率、进球数、命中率等）和计分逻辑

### 课程内容数据

- **FR-006**: 系统必须定义课程内容数据模型：LessonData、LessonStep、LessonScenario
- **FR-007**: LessonData 必须包含：lessonId、title、duration、steps（教学步骤）、scenarios（练习场景）、passCondition
- **FR-008**: LessonStep 必须包含：stepType（text/animation/quiz）、content、mediaRef、nextAction
- **FR-009**: LessonScenario 必须包含：scenarioType、ballPositions、targetZone（可选）、taskPrompt、scoringRule

### 进度与持久化

- **FR-010**: 系统必须使用现有 CourseProgress 模型记录每课时进度（userId、courseId、isCompleted、bestScore、practiceCount）
- **FR-011**: 课程完成后必须调用 CourseProgress.markCompleted(score:)
- **FR-012**: 课程列表必须根据 CourseProgress 显示完成状态、最高分（可选）

### 课程解锁与 IAP

- **FR-013**: L1-L3 必须始终可进入，无需购买
- **FR-014**: L4-L8 必须检查 UserProfile.hasPurchased("basic_course_pack") 或等价产品 ID
- **FR-015**: 未购买时点击 L4-L8 必须显示购买入口，不进入课程内容

### 集成约束

- **FR-016**: 课程练习场景必须与 EventDrivenEngine 集成，用于物理模拟与进袋检测
- **FR-017**: 课程练习场景必须与 BilliardScene/BilliardSceneView 集成，复用球桌、球杆、瞄准线、打点选择
- **FR-018**: 课程场景必须支持横屏模式（与 TrainingSceneView 一致）

---

## 关键实体

| 实体 | 说明 | 属性/关联 |
|------|------|-----------|
| **Lesson** | 课时定义（UI 层） | id、title、description、duration、tier（free/basic/advanced/expert）、contentRef |
| **LessonData** | 课时内容数据 | lessonId、title、duration、steps、scenarios、passCondition |
| **LessonStep** | 教学步骤 | stepType（text/animation/quiz）、content、mediaRef、options（测验用）、correctIndex |
| **LessonScenario** | 练习场景 | scenarioType、ballPositions、targetZone、taskPrompt、scoringRule、passThreshold |
| **CourseProgress** | 课程进度（SwiftData） | userId、courseId、isCompleted、completedAt、bestScore、practiceCount |
| **CourseSceneState** | 课程场景状态 | phase（teaching/practice/completion）、currentStepIndex、scenarioIndex、score、passed |

---

## 成功标准

### 可衡量结果

- **SC-001**: L1-L3 可从课程列表进入，完整走完教学→练习→完成三阶段
- **SC-002**: L1 测验 3 题，通过条件正确率 ≥80%；L2 直球 5 次进袋 ≥3 通过；L3 直球 10 次全进通过
- **SC-003**: 完成课时后 CourseProgress 正确更新，课程列表显示完成状态
- **SC-004**: L4-L8 未购买时不可进入，购买后可正常进入
- **SC-005**: 课程场景与训练场共享物理引擎、瞄准、打点，无崩溃、无物理异常
- **SC-006**: 课程场景横屏显示，返回后恢复竖屏

---

## 边界情况

### 流程边界

- **中途退出**: 用户在教学或练习中途退出，教学进度可选保存（如当前步骤索引），练习进度不保存
- **未通过**: 用户未达到通过条件时，显示「未通过」提示，允许重试或返回
- **重复完成**: 已完成的课可重玩，bestScore 与 practiceCount 按规则更新

### 数据边界

- **无 CourseProgress**: 首次进入某课时，自动创建 CourseProgress(userId, courseId)
- **课程内容缺失**: 若 LessonData 未找到，显示错误提示并返回列表
- **IAP 未就绪**: StoreKit 未初始化时，L4-L8 显示「购买功能即将开放」或禁用

### 技术边界

- **物理引擎**: 课程练习复用 EventDrivenEngine，需确保球位初始化、进袋检测、多球场景正确
- **横竖屏**: 进入课程场景时强制横屏，退出时恢复；与 TrainingSceneView 行为一致
- **内存**: 课程内容可预加载当前课时，避免一次性加载 L1-L18 全部数据

---

## 源文件索引

| 文件 | 说明 |
|------|------|
| Features/Course/Views/CourseListView.swift | 课程列表 UI（已存在） |
| Features/Course/Models/ | 课程数据模型（待建） |
| Features/Course/Views/CourseSceneView.swift | 课程场景主视图（待建） |
| Features/Course/ViewModels/CourseSceneViewModel.swift | 课程场景状态机（待建） |
| Models/UserProfile.swift | CourseProgress、UserProfile.hasPurchased |
