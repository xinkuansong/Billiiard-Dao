# Models - 设计与约束

> 对应 README：[README.md](./README.md)
> 文档最后更新：2026-02-27

## 设计目标与非目标

- **目标**：提供清晰的数据模型定义，支持 SwiftData 持久化，提供基础计算属性（如进球率、经验值升级）与更新方法
- **非目标**：不处理复杂业务逻辑（如训练规则判定、课程解锁条件），不管理 UI 展示逻辑

## 不变量与约束（改动护栏）

### 单位与坐标系

- 无物理单位依赖（Models 层不涉及物理计算）
- 时间使用 `Date` 类型，时长使用 `Int`（秒）或 `TimeInterval`（Double，秒）
- 经验值、分数、击球数等使用 `Int` 类型

### 数值稳定性保护

- **除法保护**：所有计算属性（如 `overallAccuracy`、`straightShotAccuracy`）必须使用 `guard totalShots > 0 else { return 0 }` 保护，避免除零错误
- **等级上限**：`UserProfile.level` 最大值为 5，`checkLevelUp()` 中必须检查 `level < 5`
- **经验值阈值**：`experienceToNextLevel` 的阈值（500/1500/4000/10000）必须保持稳定，变更会影响用户等级计算

### 时序与状态约束

- `TrainingSession.endSession()` 必须在训练结束时调用，设置 `endTime`，否则 `duration` 计算不准确
- `UserStatistics.updateCheckIn()` 必须在每次训练结束时调用，更新 `consecutiveDays` 与 `lastPracticeDate`
- `UserProfile.addExperience(_:)` 会自动触发 `checkLevelUp()`，确保等级与经验值同步

### 常量与阈值清单

| 常量/阈值 | 值 | 来源/理由 | 改动影响 |
|-----------|-----|----------|----------|
| UserProfile.level 最大值 | 5 | 等级系统设计 | 变更会影响最高等级显示 |
| experienceToNextLevel (level 1) | 500 | 经验值系统设计 | 变更会影响升级速度 |
| experienceToNextLevel (level 2) | 1500 | 经验值系统设计 | 变更会影响升级速度 |
| experienceToNextLevel (level 3) | 4000 | 经验值系统设计 | 变更会影响升级速度 |
| experienceToNextLevel (level 4) | 10000 | 经验值系统设计 | 变更会影响升级速度 |
| UserProfile 默认值 | nickname="新玩家", level=1, experience=0 | 新用户初始化 | 变更会影响新用户体验 |

## 状态机 / 事件模型

```
UserProfile 创建
  ↓
addExperience(amount)
  ↓
experience += amount
  ↓
checkLevelUp()
  ↓
while experience >= experienceToNextLevel && level < 5
  ↓
level += 1, experience -= experienceToNextLevel
```

```
TrainingSession 创建
  ↓
startTime = Date()
  ↓
训练进行中（记录 totalShots, pocketedCount, score）
  ↓
endSession()
  ↓
endTime = Date()
  ↓
duration = endTime - startTime
```

## 错误处理与降级策略

- **计算属性除零保护**：所有除法计算使用 `guard` 检查分母，返回默认值（0 或 0.0）
- **数据加载失败**：由调用方（AppState）处理，Models 层不抛出异常
- **SwiftData 保存失败**：由调用方处理，Models 层不处理持久化错误

## 性能考量

- SwiftData 使用 `@Model` 宏自动生成持久化代码，性能由框架保证
- 计算属性（如 `overallAccuracy`）每次访问都重新计算，如频繁访问可考虑缓存（当前未实现）
- `UserStatistics` 的多个统计字段使用独立 Int 存储，避免数组查询开销

## 参考实现对照（如适用）

| Swift 文件/函数 | pooltool 对应 | 偏离说明 |
|----------------|--------------|----------|
| 无 | 无 | Models 层无物理计算，无需对照 |

## 设计决策记录（ADR）

### 使用 SwiftData 而非 Core Data
- **背景**：需要数据持久化，SwiftData 是 SwiftUI 生态的标准选择
- **候选方案**：SwiftData（当前）、Core Data、UserDefaults、文件存储
- **结论**：SwiftData 与 SwiftUI 集成更好，代码更简洁，支持 @Model 宏
- **后果**：依赖 iOS 17+，无法支持旧版本系统

### 经验值升级使用 while 循环而非 if
- **背景**：单次添加大量经验值可能跨越多个等级
- **候选方案**：while 循环（当前）、if 单次升级、递归升级
- **结论**：while 循环确保一次性处理所有升级，避免遗漏
- **后果**：极端情况下（如一次性添加 100000 经验值）可能多次循环，但实际场景中经验值增量较小，影响可忽略

### 统计数据使用独立字段而非数组
- **背景**：需要记录各角度/杆法的使用次数
- **候选方案**：独立字段（当前）、字典、数组
- **结论**：独立字段查询性能更好，SwiftData 索引更高效
- **后果**：新增统计维度需要修改模型定义，但维度相对稳定，影响可控
