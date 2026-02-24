# 实现计划：场景渲染 (Scene Rendering)

**分支**：`2-scene-rendering` | **日期**：2025-02-20 | **规格**：[spec.md](./spec.md)  
**状态**：已完成 (回溯记录)

## 摘要

场景渲染功能采用 SceneKit 构建 3D 台球场景，支持 USDZ 模型加载、多相机模式与手势控制。核心架构为**视觉-物理分离**：SceneKit 仅负责渲染，物理计算由独立引擎处理。

## 技术背景

**语言/版本**：Swift 5.x  
**主要依赖**：SceneKit, SwiftUI  
**目标平台**：iOS 15+  
**项目类型**：移动端应用 (BilliardTrainer)  
**性能目标**：60fps 稳定渲染  
**约束**：视觉层与物理层完全解耦，物理引擎可独立更换

## 技术决策

### 1. 选用 SceneKit

- **决策**：使用 Apple 原生 SceneKit 进行 3D 渲染
- **原因**：与 SwiftUI 集成良好，iOS 原生支持，无需第三方引擎
- **备选**：Unity/Unreal 体积过大，Metal 直接开发成本高

### 2. USDZ 模型

- **决策**：球台与球杆使用 USDZ 3D 模型
- **原因**：Apple 生态推荐格式，支持坐标系自动转换
- **实现**：TableModelLoader 负责加载 TaiQiuZhuo.usdz，处理 Z-up → Y-up 转换及缩放

### 3. 视觉-物理分离

- **决策**：SceneKit 不参与物理计算，仅根据物理引擎输出的轨迹进行视觉播放
- **原因**：物理引擎使用解析式/事件驱动方法保证精度，不受渲染帧率限制
- **实现**：BilliardScene 接收轨迹数据，通过 SCNAction 驱动球节点运动

### 4. 球杆实现

- **决策**：优先使用 USDZ 模型球杆，失败时降级为程序化 SCNCone 球杆
- **原因**：模型球杆视觉效果好，程序化方案保证可用性

## 项目结构

### 文档

```text
specs/2-scene-rendering/
├── spec.md
├── plan.md
└── tasks.md
```

### 源码

```text
current_work/BilliardTrainer/
└── Core/
    └── Scene/
        ├── BilliardScene.swift      # 场景管理
        ├── BilliardSceneView.swift  # SwiftUI 集成 + 手势
        ├── TableModelLoader.swift   # USDZ 加载
        ├── TableGeometry.swift      # 球台几何
        └── CueStick.swift          # 球杆模型
```

## 架构要点

- **BilliardScene**：管理 tableNode、cueBallNode、targetBallNodes、cameraNode、lightNodes 等
- **BilliardSceneView**：UIViewRepresentable 包装 SCNView，Coordinator 处理手势与 CADisplayLink 渲染循环
- **TableModelLoader**：保留 rootNode transform 以正确应用 Z-up → Y-up 旋转，计算边界框进行缩放
- **TableGeometry**：chineseEightBall() 提供线性库边、圆弧库边、袋口定义，供物理引擎使用
