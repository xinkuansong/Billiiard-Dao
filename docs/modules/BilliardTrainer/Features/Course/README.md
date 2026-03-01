# Course（课程）

> 代码路径：`BilliardTrainer/Features/Course/`
> 文档最后更新：2026-02-27

## 模块定位

课程模块负责展示系统化课程列表，按难度等级分组（入门、基础、进阶、高级），显示课程信息、锁定状态和完成状态。不负责课程内容播放或训练执行逻辑。

## 入口文件

| 文件 | 职责 | 行数 |
|------|------|------|
| `CourseListView.swift` | 课程列表视图，包含 CourseSection、CourseCard 组件和 Course 数据模型 | ~190 |

## 核心概念与术语

| 术语 | 含义 |
|------|------|
| Course | 课程数据模型，包含 id、标题、描述、时长、完成状态 |
| CourseSection | 课程分组组件，展示同一难度等级的课程集合 |
| CourseCard | 单个课程卡片组件，显示课程信息和状态 |
| isLocked | 课程组锁定状态，决定是否可访问该组课程 |

## 端到端流程

```
用户打开课程页 → CourseListView 渲染 → 按等级分组展示 → 显示锁定/完成状态 → 用户点击课程卡片
```

## 对外能力（Public API）

- `CourseListView`：课程列表主视图
- `Course`：课程数据模型（Identifiable）
  - `freeCourses`：免费课程（L1-L3）
  - `basicCourses`：基础课程（L4-L8）
  - `advancedCourses`：进阶课程（L9-L14）
  - `expertCourses`：高级课程（L15-L18）

## 依赖与边界

- **依赖**：SwiftUI（仅 UI 框架）
- **被依赖**：App 层 TabView 导航（ContentView）
- **禁止依赖**：其他 Features 模块、Core 层、物理引擎

## 与其他模块的耦合点

- **Home 模块**：首页可能显示课程进度，需同步 Course 完成状态（当前为静态数据）
- **Training 模块**：课程完成后可能触发训练场解锁（当前未实现）

## 关键数据结构

| 结构/枚举 | 字段/Case | 单位/生命周期 |
|-----------|-----------|---------------|
| `Course` | `id: Int`, `title: String`, `description: String`, `duration: Int`, `isCompleted: Bool` | duration 单位为分钟，isCompleted 为可变状态 |
| `CourseSection` | `title: String`, `subtitle: String`, `courses: [Course]`, `isLocked: Bool` | 视图组件，无状态 |
| `CourseCard` | `course: Course`, `isLocked: Bool` | 视图组件，无状态 |

## 最近变更记录

| 日期 | 变更摘要 | 影响面 |
|------|----------|--------|
| 2026-02-27 | 初始文档创建 | 无 |
