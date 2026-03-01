# Models - 验证与回归

> 对应 README：[README.md](./README.md)
> 文档最后更新：2026-02-27

## 影响面清单

改动本模块时，必须检查以下影响面：

- [ ] 调用方：App（ModelContainer schema）、Statistics（UserStatistics 查询）、Settings（UserProfile.settings 读写）、Training（TrainingSession 创建）
- [ ] 共享常量/状态：experienceToNextLevel 阈值、UserProfile.level 最大值、UserProfile 默认值
- [ ] UI 交互链：StatisticsView 展示统计数据、SettingsView 读写设置、TrainingViewModel 创建会话
- [ ] 持久化/数据映射：SwiftData schema 变更会影响现有数据迁移
- [ ] 配置/开关：无

## 最小回归门禁

每次改动后必须验证（不可跳过）：

### 主路径验证

- [ ] **用户创建与加载**：首次启动创建用户 → 退出应用重新启动 → 应加载已有用户，不重复创建
- [ ] **经验值升级**：添加经验值触发升级 → 等级应正确递增，经验值应正确扣除 → 达到最高等级（5）后不再升级

### 相邻流程验证（至少 2 个）

- [ ] **统计数据记录**：完成一次训练 → 记录击球/进球 → 应正确更新 UserStatistics 的 totalShots、totalPocketed、各角度统计
- [ ] **训练会话时长**：开始训练 → 进行一段时间 → 结束训练 → TrainingSession.duration 应正确计算
- [ ] **计算属性除零保护**：新用户（totalShots=0）查看统计 → overallAccuracy 应返回 0，不应崩溃

## 测试入口

| 测试文件 | 覆盖内容 | 运行方式 |
|----------|----------|----------|
| UserProfileTests | UserProfile 模型测试（如存在） | `⌘U` / CLI |

## 可观测性

- 日志前缀：无（Models 层不直接输出日志）
- 关键观测点：
  - SwiftData 保存错误：由调用方（AppState）记录日志
  - 计算属性访问：通过断点或单元测试验证
- 可视化开关：无

## 常见问题排查

| 症状 | 可能原因 | 排查路径 |
|------|----------|----------|
| 计算属性返回 NaN 或崩溃 | 除零错误 | 检查所有计算属性的 `guard` 保护逻辑 |
| 经验值升级不正确 | experienceToNextLevel 阈值错误 | 检查阈值定义与 `checkLevelUp()` 逻辑 |
| SwiftData 迁移失败 | schema 变更未提供迁移 | 检查模型字段变更，提供迁移策略 |
| 统计数据不更新 | 未调用更新方法或未保存 | 检查 TrainingViewModel 是否调用 `recordShot`、`addPracticeTime` 等，并保存 ModelContext |

## 未覆盖风险与待补测项

| 风险描述 | 等级 | 建议补测方式 |
|----------|------|-------------|
| SwiftData schema 迁移 | 高 | 创建迁移测试，验证旧版本数据在新版本中可正常加载 |
| 并发访问 ModelContext | 中 | 添加并发测试，验证多线程环境下的数据一致性 |
| 大量数据查询性能 | 低 | 添加性能测试，验证 UserStatistics 查询在数据量大时的性能 |

## 变更验证记录

| 日期 | 变更摘要 | 验证结果 | 未覆盖项 |
|------|----------|----------|----------|
| 2026-02-27 | 创建模块文档 | 通过 | 无 |
