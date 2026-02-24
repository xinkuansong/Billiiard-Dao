# 任务列表：课程系统 (Course System)

**输入**: `specs/7-course-system/` 下的设计文档  
**说明**: 课程系统实施任务列表，所有任务均为未完成状态 [ ]。路径基于 `current_work/BilliardTrainer/`。

## 格式：`[ID] [P?] [US?] 描述`

- **[P]**: 可并行执行（不同文件，无依赖）
- **[US?]**: 所属用户故事（US1=课程学习流程，US2=进度跟踪，US3=课程解锁 IAP）
- 路径基于 `current_work/BilliardTrainer/`

---

## 阶段 1：基础搭建

**目的**: 课程数据模型、内容结构、进度服务

- [ ] T001 [P] 创建 LessonStep 模型：stepType、content、mediaRef、quizOptions、correctOptionIndex；Features/Course/Models/LessonStep.swift
- [ ] T002 [P] 创建 LessonScenario 模型：scenarioType、ballPositions、targetZone、taskPrompt、scoringRule、passThreshold；Features/Course/Models/LessonScenario.swift
- [ ] T003 [P] 创建 LessonData 模型：lessonId、title、duration、steps、scenarios、passCondition；Features/Course/Models/LessonData.swift
- [ ] T004 创建 PassCondition 枚举：quizCorrectRate、pocketCount、hitRate、techniqueCount、allScenariosComplete、positionSuccessCount；Features/Course/Models/LessonData.swift
- [ ] T005 [P] 创建 LessonContentProvider：load(lessonId)、allLessonIds；Features/Course/Models/LessonContentProvider.swift
- [ ] T006 实现 LessonContentProvider 中 L1 内容：3 步教学 + 测验 3 题 + passCondition 正确率≥80%
- [ ] T007 实现 LessonContentProvider 中 L2 内容：教学步骤 + 直球 5 次场景 + passCondition 进袋≥3
- [ ] T008 实现 LessonContentProvider 中 L3 内容：教学步骤 + 直球 10 次场景 + passCondition 进袋 10
- [ ] T009 创建 CourseProgressService：fetchProgress(userId, courseId)、saveCompletion(userId, courseId, score)；Features/Course/ViewModels/CourseProgressService.swift
- [ ] T010 [P] 研究 BilliardScene 球位初始化 API，确认是否支持从外部 BallPosition 列表布置；文档记录于 plan.md 或 research 笔记

---

## 阶段 2：课程场景框架

**目的**: 三阶段流程、状态机、主视图与各阶段 UI 骨架

- [ ] T011 创建 CourseSceneViewModel：phase、currentStepIndex、currentScenarioIndex、scenarioScores、totalScore、passed、lessonData；Features/Course/ViewModels/CourseSceneViewModel.swift
- [ ] T012 实现 CourseSceneViewModel 教学阶段逻辑：advanceStep、handleQuizAnswer、transitionToPractice
- [ ] T013 实现 CourseSceneViewModel 练习阶段逻辑：startScenario、onShotResult、checkScenarioPass、transitionToCompletion
- [ ] T014 实现 CourseSceneViewModel 完成阶段逻辑：calculateStars、saveProgress
- [ ] T015 创建 CourseSceneView：根据 phase 切换 TeachingPhaseView / PracticePhaseView / CompletionPhaseView；Features/Course/Views/CourseSceneView.swift
- [ ] T016 [US1] 创建 TeachingPhaseView：展示 LessonStep 文本、插图、下一步按钮；Features/Course/Views/TeachingPhaseView.swift
- [ ] T017 [US1] 创建 TeachingPhaseView 测验支持：quiz 类型显示选项、选择后校验、正确/错误反馈
- [ ] T018 [US1] 创建 PracticePhaseView 骨架：占位 HUD、taskPrompt 展示、后续嵌入 BilliardSceneView；Features/Course/Views/PracticePhaseView.swift
- [ ] T019 [US1] 创建 CompletionPhaseView：得分、星级、返回/下一课按钮；Features/Course/Views/CompletionPhaseView.swift
- [ ] T020 [P] 在 CourseSceneView 中集成 OrientationHelper：onAppear forceLandscape、onDisappear restorePortrait
- [ ] T021 在 CourseListView 中添加 NavigationLink：点击 CourseCard 进入 CourseSceneView(lessonId)；Features/Course/Views/CourseListView.swift

---

## 阶段 3 (US1)：L1-L3 免费课程实现

**目的**: 每节课完整打通教学→练习→完成

- [ ] T022 [US1] 实现 L1 TeachingPhaseView 展示：3 步教学内容 + 测验 3 题 UI；验证步骤切换与测验提交
- [ ] T023 [US1] 实现 L1 测验逻辑：3 题选择、正确率计算、≥80% 通过；与 CourseSceneViewModel 集成
- [ ] T024 [US1] L1 无练习阶段，测验通过后直接进入 CompletionPhaseView
- [ ] T025 [US1] 实现 L2 练习阶段：将 LessonScenario 转为球桌布置，嵌入 BilliardSceneView；5 个直球场景
- [ ] T026 [US1] 实现 L2 进袋检测与通过条件：监听 EventDrivenEngine 进袋事件，累计进袋数≥3 通过
- [ ] T027 [US1] 实现 L3 练习阶段：10 个直球场景，进袋 10 个通过
- [ ] T028 [US1] 实现 LessonScenario 到 TrainingConfig/BallPosition 的转换：供 PracticePhaseView 初始化 BilliardScene
- [ ] T029 [US1] 实现 BilliardScene 或桥接层「按 ballPositions 布置球」：支持课程场景动态球位；Core/Scene/BilliardScene.swift 或新建扩展

---

## 阶段 4 (US2)：L4-L8 基础课程实现

**目的**: 付费课程内容与场景

- [ ] T030 [US2] 实现 LessonContentProvider 中 L4 内容：角度球 30°/45°/60° 教学 + 5×30° + 5×45° 场景 + passCondition 命中率≥50%
- [ ] T031 [US2] 实现 L4 练习场景：角度球 ballPositions 配置、命中率统计
- [ ] T032 [US2] 实现 LessonContentProvider 中 L5 内容：中杆/高杆/低杆教学 + 各技法成功≥2 场景
- [ ] T033 [US2] 实现 L5 练习逻辑：识别击球打点类型（SpinType）、累计各技法成功次数
- [ ] T034 [US2] 实现 LessonContentProvider 中 L6 内容：分离角教学 + 预测角度与厚薄选择 + passCondition≥60%
- [ ] T035 [US2] 实现 L6 练习 UI：角度预测选择、厚薄选择、结果校验
- [ ] T036 [US2] 实现 LessonContentProvider 中 L7 内容：左右塞教学 + 库边练习场景 + 完成所有 drill
- [ ] T037 [US2] 实现 L7 练习逻辑：塞球对库边影响、drill 完成判定
- [ ] T038 [US2] 实现 LessonContentProvider 中 L8 内容：单球走位教学 + 走位成功≥3 场景
- [ ] T039 [US2] 实现 L8 练习逻辑：目标球进袋 + 母球落入 TargetZone 判定为走位成功

---

## 阶段 5 (US2)：进度跟踪与列表联动

**目的**: CourseProgress 持久化、列表展示完成状态

- [ ] T040 [US2] CourseProgressService 与 ModelContext 集成：从 AppState 或 Environment 获取 context
- [ ] T041 [US2] 课程完成时调用 CourseProgress.markCompleted(score:)，并 persist
- [ ] T042 [US2] 修改 CourseListView：注入 ModelContext，按当前用户查询各 courseId 的 CourseProgress；Features/Course/Views/CourseListView.swift
- [ ] T043 [US2] 修改 CourseCard：接收 CourseProgress? 参数，显示 isCompleted（✓）、bestScore（可选）
- [ ] T044 [US2] 修改 HomeView 学习进度区块：根据 CourseProgress 统计已完成课程数（如 3/18）；Features/Home/Views/HomeView.swift

---

## 阶段 6 (US3)：课程解锁与 IAP

**目的**: L4-L8 购买校验、未购买时购买入口

- [ ] T045 [US3] 定义 IAP 产品 ID 常量：basic_course_pack = "com.xxx.billiard.basic_course"（或项目约定）；Utilities/Constants/IAPConstants.swift 或 Features/Course/
- [ ] T046 [US3] 修改 CourseListView：L4-L8 的 CourseSection 根据 UserProfile.hasPurchased 判断 isLocked
- [ ] T047 [US3] 实现 CourseCard 点击 L4-L8 未购买时：弹出购买 Sheet 或 Alert，不进入 CourseSceneView
- [ ] T048 [US3] 实现购买 Sheet/View：展示基础课程包说明、价格、购买按钮（StoreKit 2 集成可后续细化）
- [ ] T049 [US3] 购买成功后 UserProfile.addPurchase(productId)，更新 isLocked 状态
- [ ] T050 [US3] 设置页「恢复购买」：调用 StoreKit 验证，更新 UserProfile.purchasedProducts

---

## 阶段 7：打磨

**目的**: 体验优化、边界情况、错误处理

- [ ] T051 课程场景返回按钮：教学/练习阶段确认弹窗「确定退出？进度不保存」
- [ ] T052 未通过时 UI：显示「未通过」提示、重试按钮、返回按钮
- [ ] T053 课程内容缺失时：LessonContentProvider.load 返回 nil 时显示错误页、返回列表
- [ ] T054 音效/震动：课程完成、测验正确/错误、进袋时调用 AudioManager；与用户设置同步
- [ ] T055 课程列表「下一课」：完成当前课后，下一课若未锁定则高亮或引导
- [ ] T056 移除 Course 模型中的硬编码 isCompleted，全部改为从 CourseProgress 动态读取；Features/Course/Views/CourseListView.swift

---

## 任务汇总

| 阶段 | 任务数 | 说明 |
|------|--------|------|
| 阶段 1 | 10 | 数据模型、内容提供者、进度服务 |
| 阶段 2 | 11 | 场景框架、三阶段 UI、导航 |
| 阶段 3 | 8 | L1-L3 实现 |
| 阶段 4 | 10 | L4-L8 实现 |
| 阶段 5 | 5 | 进度持久化与列表联动 |
| 阶段 6 | 6 | IAP 解锁 |
| 阶段 7 | 6 | 打磨 |
| **合计** | **56** | |

**状态**: 草案 (Draft)
