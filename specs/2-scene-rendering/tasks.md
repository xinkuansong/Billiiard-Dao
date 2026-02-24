# 任务列表：场景渲染 (Scene Rendering)

**输入**：`/specs/2-scene-rendering/` 设计文档  
**状态**：已完成 (回溯记录)

## 格式说明

- **[P]**：可并行执行（不同文件、无依赖）
- **[Story]**：所属用户故事（US1, US2, US3）
- 任务格式：`[x] 已完成`

---

## Phase 1：基础架构

- [x] T001 [P] 创建 BilliardScene 类，实现场景初始化、环境、光照
- [x] T002 [P] 创建 TableGeometry 结构体，定义中式八球球台几何（库边、袋口）
- [x] T003 [P] 创建 TableModelLoader，实现 USDZ 加载与 Z-up → Y-up 坐标转换

---

## Phase 2：球台与球杆

- [x] T004 [US1] 在 BilliardScene 中集成 TableModelLoader，加载 TaiQiuZhuo.usdz
- [x] T005 [US1] 实现球台模型缩放与定位，适配场景坐标系
- [x] T006 [P] [US1] 创建 CueStick 类，支持 USDZ 模型与程序化球杆两种模式

---

## Phase 3：相机系统

- [x] T007 [US2] 实现 CameraMode 枚举：firstPerson, topDown2D, perspective3D, shooting, free
- [x] T008 [US2] 实现 setCameraMode，配置各模式相机位置、角度、正交/透视
- [x] T009 [US2] 实现第一人称相机跟随瞄准方向
- [x] T010 [US2] 实现 cycleNextCameraMode，双击切换视角

---

## Phase 4：SwiftUI 集成与手势

- [x] T011 [US1] 创建 BilliardSceneView，UIViewRepresentable 包装 SCNView
- [x] T012 [US3] 实现单指拖拽手势（handlePan），旋转视角
- [x] T013 [US3] 实现双指捏合手势（handlePinch），缩放
- [x] T014 [US3] 实现双指平移手势（handleTwoFingerPan），调整俯仰角
- [x] T015 [US2] 实现双击手势（handleDoubleTap），切换相机模式

---

## Phase 5：渲染循环与优化

- [x] T016 [US1] 实现 CADisplayLink 渲染循环，更新第一人称相机与球杆
- [x] T017 [US1] 配置 SCNView：antialiasingMode、preferredFramesPerSecond、pointOfView
- [x] T018 [US1] 实现 dismantleUIView 停止渲染循环，避免循环引用

---

## 验收检查点

- [x] 球台、球、球杆正确渲染
- [x] 四种相机模式可切换
- [x] 手势控制流畅
- [x] 视觉与物理分离架构落地
