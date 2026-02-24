# 实施计划：训练框架 (Training Framework)

**分支**: `4-training-framework` | **日期**: 2025-02-20 | **规格**: [spec.md](./spec.md)  
**说明**: 本文档为回溯性计划，记录已实现训练框架的技术决策与架构

## 摘要

训练框架采用 MVVM 模式，TrainingViewModel 负责得分、计时、连击、星级计算等业务逻辑，与 BilliardSceneViewModel 通过 Combine 绑定。视图层分为 TrainingListView（列表）、TrainingDetailView（详情）、TrainingSceneView（全屏场景），并包含 PowerGaugeView、CuePointSelectorView 等专用 UI 组件。训练会话状态采用基于事件的流程设计。

## 技术上下文

**语言/版本**: Swift 5.x  
**主要依赖**: SwiftUI、Combine、SceneKit、SwiftData  
**目标平台**: iOS 17+  
**项目类型**: 原生 iOS 应用  
**架构**: MVVM  
**性能目标**: 训练场景 60fps，HUD 与控件响应流畅  
**约束**: 训练场景强制横屏，退出后恢复竖屏  
**规模**: Features/Training/ 下 7 个 Swift 文件

## 核心架构决策

### 1. MVVM 分层

- **决策**: TrainingViewModel 与 BilliardSceneViewModel 分层协作
- **理由**:
  - TrainingViewModel 负责训练层逻辑（得分、目标、计时、结果）
  - BilliardSceneViewModel 负责场景层逻辑（球局、瞄准、击球、物理）
  - 通过 Combine 订阅 sceneViewModel.$gameState 与回调（onTargetBallPocketed、onCueBallPocketed、onShotCompleted）同步状态
- **实现**: TrainingViewModel.init 中 setupBindings()，监听 gameState 与各类回调，handleBallPocketed 更新得分与连击

### 2. 训练配置模型

- **决策**: TrainingConfig 作为不可变配置，通过静态方法生成预设
- **理由**:
  - 不同训练类型（aiming、spin、bankShot、kickShot、diamond）有统一结构
  - 难度 1–5 映射到场景初始化参数（如 spin 对应 center/top/bottom/left/right）
  - 便于扩展新训练类型
- **实现**: TrainingConfig.static func aimingConfig/spinConfig/bankShotConfig/kickShotConfig/diamondConfig(difficulty:)

### 3. 训练会话状态机

- **决策**: 训练生命周期为 start → (pause/resume) → end，通过 showResult 控制结果页展示
- **理由**:
  - 明确的状态转换，便于处理暂停、重新开始、退出
  - 计时器与 isPaused 联动，暂停时停止计时
- **实现**: startTraining() 重置状态、setupScene、startTimer；pauseTraining/resumeTraining 控制 timer；handleBallPocketed 或 updateTimer 时间到 时 endTraining()

### 4. SwiftUI 全屏覆盖

- **决策**: TrainingSceneView 通过 fullScreenCover 呈现，内部 ZStack 叠加 3D 场景与 HUD
- **理由**:
  - 训练场景需横屏沉浸式体验
  - HUD 层（TopHUD、打点、力度、BottomHint）叠加在场景之上
  - 暂停、结果使用半透明覆盖
- **实现**: TrainingDetailView.fullScreenCover(isPresented:) { TrainingSceneView(config:) }

### 5. 打点与力度 UI 组件

- **决策**: CuePointSelectorView 与 PowerGaugeView 独立为可复用组件
- **理由**:
  - 打点选择器需要复杂手势（拖拽映射到圆内 0–1 坐标）
  - 力度条需要渐变色与刻度标记
  - 仅在 aiming/charging 状态显示，由 showGameControls 控制
- **实现**: CuePointSelectorView 通过 Binding&lt;CGPoint&gt; 与 sceneViewModel.selectedCuePoint 同步；PowerGaugeView 接收 power 与 isCharging

### 6. 星级计算

- **决策**: TrainingResult.calculateStars(score:maxScore:) 基于得分比例
- **理由**:
  - 简单直观：90%+ 五星，75–90% 四星，60–75% 三星，40–60% 二星，&lt;40% 一星
  - maxScore 由 goalCount、难度加成、最大连击奖励估算
- **实现**: TrainingViewModel.calculateFinalResult() 调用 TrainingResult.calculateStars

## 项目结构

### 文档（本功能）

```text
specs/4-training-framework/
├── spec.md      # 本功能规格（回溯）
├── plan.md      # 本实施计划（回溯）
└── tasks.md     # 任务列表（回溯）
```

### 源代码

```text
current_work/BilliardTrainer/Features/Training/
├── Views/
│   ├── TrainingListView.swift    # 训练场列表、挑战模式入口
│   ├── TrainingDetailView.swift  # 训练详情、难度选择、开始训练
│   ├── TrainingSceneView.swift   # 全屏场景、HUD、暂停、结果
│   ├── PowerGaugeView.swift     # 力度指示条
│   └── CuePointSelectorView.swift # 打点选择器
├── ViewModels/
│   └── TrainingViewModel.swift  # 训练逻辑、得分、计时、星级
└── Models/
    └── TrainingConfig.swift     # TrainingConfig、TrainingSceneType、BallPosition、TargetZone、TrainingResult
```

### 结构说明

- **TrainingListView**: TrainingGround.allGrounds 静态数据，TrainingGroundCard、ChallengeSection 子视图
- **TrainingDetailView**: 根据 ground.id 创建对应 TrainingConfig，fullScreenCover 呈现 TrainingSceneView
- **TrainingSceneView**: 持有一个 TrainingViewModel，集成 BilliardSceneView、TopHUD、CuePointSelectorView、PowerGaugeView、BottomHint、PauseMenuOverlay、TrainingResultOverlay
- **TrainingViewModel**: 与 BilliardSceneViewModel 通过 setupBindings 建立绑定，handleBallPocketed 更新得分与连击，calculateFinalResult 生成 TrainingResult
