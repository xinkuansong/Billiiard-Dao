# Settings（设置）- 设计与约束

> 对应 README：[README.md](./README.md)
> 文档最后更新：2026-02-27

## 设计目标与非目标

- **目标**：提供统一的设置管理界面，持久化用户偏好设置，展示已购内容和帮助信息
- **非目标**：不实现购买流程（仅提供 UI 入口）、不实现 StoreKit 集成、不实现数据同步（当前 @AppStorage 独立于 UserProfile）

## 不变量与约束（改动护栏）

### 单位与坐标系

- 设置值为 Bool 类型，使用 @AppStorage 持久化
- 设置键名必须与 AudioManager 和 Scene 层读取的键名一致

### 数值稳定性保护

- @AppStorage 提供默认值，避免 nil 情况
- 设置键名变更需同步更新所有读取位置（AudioManager、Scene 层）

### 时序与状态约束

- 设置修改立即生效（@AppStorage 自动同步）
- AudioManager 需在设置变更时同步读取（当前可能需重启应用）

### 常量与阈值清单

| 常量/阈值 | 值 | 来源/理由 | 改动影响 |
|-----------|-----|----------|----------|
| soundEnabled 默认值 | true | 产品设计 | 影响首次启动音效状态 |
| hapticEnabled 默认值 | true | 产品设计 | 影响首次启动震动状态 |
| aimLineEnabled 默认值 | true | 产品设计 | 影响首次启动瞄准线显示 |
| trajectoryEnabled 默认值 | false | 产品设计 | 轨迹预测默认关闭 |
| @AppStorage 键名 | "soundEnabled", "hapticEnabled", "aimLineEnabled", "trajectoryEnabled" | 代码约定 | 键名变更需同步所有读取位置 |

## 状态机 / 事件模型

```
设置状态：
默认值（首次启动） → 用户修改 → @AppStorage 保存 → AudioManager/Scene 读取 → 生效
```

## 错误处理与降级策略

- @AppStorage 读取失败：使用默认值（true/false）
- 设置键名不一致：编译期无法检测，需代码审查保证一致性
- AudioManager 未同步：当前可能需重启应用，后续需添加观察者模式

## 性能考量

- @AppStorage 读写：UserDefaults 操作，性能开销可忽略
- 设置变更频率：低频操作，无性能热点
- 视图渲染：SwiftUI List 自动优化

## 参考实现对照（如适用）

不适用（纯 UI 和配置管理模块，无物理引擎或算法参考）

## 设计决策记录（ADR）

### 使用 @AppStorage 而非 UserProfile SwiftData

- **背景**：UserProfile 模型也包含相同设置字段，存在数据冗余
- **候选方案**：
  1. @AppStorage（当前方案）
  2. UserProfile SwiftData 模型
  3. 两者同步
- **结论**：使用 @AppStorage，简化设置管理，减少 SwiftData 查询开销
- **后果**：需保持 UserProfile 字段与 @AppStorage 同步（当前未实现）

### 购买流程仅提供 UI 入口

- **背景**：StoreKit 集成未完成，购买功能待实现
- **候选方案**：
  1. UI 入口 + TODO（当前方案）
  2. 隐藏购买入口
  3. 占位提示
- **结论**：保留 UI 入口，明确标识 TODO，保持 UI 完整性
- **后果**：需后续实现购买流程和状态同步

### 帮助信息硬编码

- **背景**：使用帮助内容相对固定，无需动态加载
- **候选方案**：
  1. 硬编码（当前方案）
  2. 本地化文件
  3. 远程配置
- **结论**：硬编码，简化实现，后续可迁移到本地化文件
- **后果**：多语言支持需重构为本地化文件
