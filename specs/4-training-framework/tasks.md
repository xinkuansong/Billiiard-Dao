# 任务：训练场框架

**Input**: 设计文档 `/specs/4-training-framework/`
**Status**: 已完成 (回溯记录)

## 阶段 1：基础搭建

- [x] T001 创建 Features/Training/ 目录结构（Views/、ViewModels/、Models/）
- [x] T002 [P] 创建 TrainingConfig 模型 Features/Training/Models/TrainingConfig.swift

---

## 阶段 2：训练场 UI

- [x] T003 实现 TrainingListView Features/Training/Views/TrainingListView.swift
- [x] T004 实现 TrainingDetailView Features/Training/Views/TrainingDetailView.swift
- [x] T005 [P] 实现 PowerGaugeView 力度控制组件 Features/Training/Views/PowerGaugeView.swift
- [x] T006 [P] 实现 CuePointSelectorView 打点选择组件 Features/Training/Views/CuePointSelectorView.swift

---

## 阶段 3：训练场景与业务逻辑

- [x] T007 实现 TrainingSceneView 全屏训练场景 Features/Training/Views/TrainingSceneView.swift
- [x] T008 实现 TrainingViewModel 训练状态管理 Features/Training/ViewModels/TrainingViewModel.swift
- [x] T009 实现训练计分逻辑（进球数、用时、得分计算）
- [x] T010 实现星级评价算法（基于 TrainingConfig 通过条件）

---

## 阶段 4：集成与数据

- [x] T011 集成 TrainingSceneView 与 BilliardScene/物理引擎
- [x] T012 集成 TrainingViewModel 与 SwiftData TrainingSession 保存
- [x] T013 实现训练场列表锁定/解锁状态显示
- [x] T014 实现最佳记录展示

---

## 依赖与执行顺序

- 阶段 1 无依赖
- 阶段 2 依赖阶段 1
- 阶段 3 依赖阶段 2 + 物理引擎（specs/1-physics-engine）
- 阶段 4 依赖阶段 3 + 数据模型（specs/6-data-models）
