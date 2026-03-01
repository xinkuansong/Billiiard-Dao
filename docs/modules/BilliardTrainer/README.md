# BilliardTrainer 模块文档索引

> 文档最后更新：2026-02-27

## 文档使用流程

每次修改 `BilliardTrainer/**/*.swift` 时，必须遵循 **读-改-回填** 三步流程（详见 `.cursor/rules/10-module-doc-read-change-backfill.mdc`）：

1. **改前**：找到受影响模块文档 → 阅读 README + design + validation
2. **改中**：遵守 design.md 中记录的不变量与约束
3. **改后**：回填文档（变更原因、影响面、验证结果、未覆盖风险）

## 路径映射规则

代码路径 → 文档路径的对应关系：

```
BilliardTrainer/<Layer>/<Module>/ → docs/modules/BilliardTrainer/<Layer>/<Module>/
```

唯一的三级拆分：`Core/Scene/Camera/` 作为独立子模块。

## 模块地图

### Core 层（核心引擎）

| 模块 | 代码路径 | 文件数 | 行数 | 文档 |
|------|---------|--------|------|------|
| **Physics** | `Core/Physics/` | 11 | ~3900 | [README](Core/Physics/README.md) · [design](Core/Physics/design.md) · [validation](Core/Physics/validation.md) |
| **Scene** | `Core/Scene/`（不含 Camera/） | 8 | ~6200 | [README](Core/Scene/README.md) · [design](Core/Scene/design.md) · [validation](Core/Scene/validation.md) |
| **Camera** | `Core/Scene/Camera/` | 5 | ~600 | [README](Core/Scene/Camera/README.md) · [design](Core/Scene/Camera/design.md) · [validation](Core/Scene/Camera/validation.md) |
| **Aiming** | `Core/Aiming/` | 2 | ~770 | [README](Core/Aiming/README.md) · [design](Core/Aiming/design.md) · [validation](Core/Aiming/validation.md) |
| **Rules** | `Core/Rules/` | 2 | ~530 | [README](Core/Rules/README.md) · [design](Core/Rules/design.md) · [validation](Core/Rules/validation.md) |

### Features 层（功能模块）

| 模块 | 代码路径 | 文件数 | 行数 | 文档 |
|------|---------|--------|------|------|
| **Training** | `Features/Training/` | 7 | ~2100 | [README](Features/Training/README.md) · [design](Features/Training/design.md) · [validation](Features/Training/validation.md) |
| **FreePlay** | `Features/FreePlay/` | 2 | ~780 | [README](Features/FreePlay/README.md) · [design](Features/FreePlay/design.md) · [validation](Features/FreePlay/validation.md) |
| **Home** | `Features/Home/` | 2 | ~370 | [README](Features/Home/README.md) · [design](Features/Home/design.md) · [validation](Features/Home/validation.md) |
| **Course** | `Features/Course/` | 1 | ~190 | [README](Features/Course/README.md) · [design](Features/Course/design.md) · [validation](Features/Course/validation.md) |
| **Statistics** | `Features/Statistics/` | 1 | ~240 | [README](Features/Statistics/README.md) · [design](Features/Statistics/design.md) · [validation](Features/Statistics/validation.md) |
| **Settings** | `Features/Settings/` | 1 | ~210 | [README](Features/Settings/README.md) · [design](Features/Settings/design.md) · [validation](Features/Settings/validation.md) |

### 支撑层

| 模块 | 代码路径 | 文件数 | 行数 | 文档 |
|------|---------|--------|------|------|
| **App** | `App/` | 2 | ~290 | [README](App/README.md) · [design](App/design.md) · [validation](App/validation.md) |
| **Models** | `Models/` | 1 | ~400 | [README](Models/README.md) · [design](Models/design.md) · [validation](Models/validation.md) |
| **Audio** | `Core/Audio/` | 1 | ~290 | [README](Core/Audio/README.md) · [design](Core/Audio/design.md) · [validation](Core/Audio/validation.md) |
| **Utilities** | `Utilities/` | 3 | ~730 | [README](Utilities/README.md) · [design](Utilities/design.md) · [validation](Utilities/validation.md) |

## 全局约定

- **单位系统**：SI（米、千克、秒、弧度），详见 `PhysicsConstants.swift`
- **坐标系**：SceneKit Y-up（USDZ 模型从 Z-up 变换）
- **球命名**：`cueBall`、`_N`（1-15）、`ball_N`（兼容）
- **数据流**：输入 → 物理模拟 → 事件提取 → 规则判定 → UI 状态（单向）
- **物理参考基线**：`pooltool-main/`，改动物理引擎必须先对照

## 资源约定（Resources/）

- `TaiQiuZhuo.usdz`：台球桌 3D 模型，由 `TableModelLoader` 加载
- `Assets.xcassets`：App 图标与颜色资源
- `LaunchScreen.storyboard`：启动屏
- 新增资源须遵循命名规范并在相关模块文档中注明引用关系

## 文档模板

新建模块文档时，从 `docs/modules/_templates/` 复制模板：

- [module_README.md](_templates/module_README.md)
- [module_design.md](_templates/module_design.md)
- [module_validation.md](_templates/module_validation.md)
