# Utilities - 验证与回归

> 对应 README：[README.md](./README.md)
> 文档最后更新：2026-02-27

## 影响面清单

改动本模块时，必须检查以下影响面：

- [ ] 调用方：Core/Physics（PhysicsConstants）、Core/Scene（PhysicsConstants、SCNVector3 扩展）、Core/Aiming（PhysicsConstants）、Features/Training（PhysicsConstants、Extensions）
- [ ] 共享常量/状态：所有 PhysicsConstants 常量、SCNVector3 扩展方法、Extensions 样式
- [ ] UI 交互链：Extensions 的 View 样式影响所有使用 cardStyle/primaryButtonStyle 的视图
- [ ] 持久化/数据映射：无
- [ ] 配置/开关：无

## 最小回归门禁

每次改动后必须验证（不可跳过）：

### 主路径验证

- [ ] **物理常量使用**：启动训练场景 → 球体/球台应使用正确尺寸 → 物理计算应使用正确常量
- [ ] **向量运算**：物理引擎进行向量计算 → SCNVector3 扩展方法应正确工作 → 归一化零向量应返回自身，不崩溃

### 相邻流程验证（至少 2 个）

- [ ] **View 样式**：使用 cardStyle/primaryButtonStyle 的视图 → 应正确应用样式
- [ ] **数值转换**：角度/弧度转换 → degrees/radians 扩展应正确工作
- [ ] **重力常量对照**：检查 TablePhysics.gravity 是否为 9.81 → 应与 pooltool 参考实现一致

## 测试入口

| 测试文件 | 覆盖内容 | 运行方式 |
|----------|----------|----------|
| 无 | Utilities 模块暂无专用测试 | PhysicsConstants 通过物理引擎测试间接验证 |

## 可观测性

- 日志前缀：无（Utilities 模块不直接输出日志）
- 关键观测点：
  - 物理常量值：通过断点或单元测试验证
  - 向量运算结果：通过物理引擎行为验证
- 可视化开关：无

## 常见问题排查

| 症状 | 可能原因 | 排查路径 |
|------|----------|----------|
| 物理计算不正确 | 物理常量值错误或单位不统一 | 检查 PhysicsConstants 常量值，确认使用 SI 单位，对照 pooltool 参考实现 |
| 向量归一化崩溃 | 零向量未保护 | 检查 SCNVector3.normalized() 的零向量保护逻辑 |
| 重力计算偏差 | gravity 值错误 | 检查 TablePhysics.gravity 是否为 9.81，对照 pooltool |
| spinFriction 计算错误 | 公式错误或硬编码 | 检查 spinFriction 是否使用公式计算（proportionality * radius），不可硬编码 |
| View 样式不生效 | Extensions 方法未正确调用 | 检查 View 是否调用 cardStyle/primaryButtonStyle 等方法 |

## 未覆盖风险与待补测项

| 风险描述 | 等级 | 建议补测方式 |
|----------|------|-------------|
| 物理常量与 pooltool 不一致 | 高 | 创建对照测试，验证所有关键常量与参考实现一致 |
| 向量运算边界情况 | 中 | 添加单元测试，验证零向量、极大值、NaN 等边界情况 |
| 单位转换错误 | 中 | 添加单元测试，验证 SI 单位到 SceneKit 单位的转换 |
| Extensions 方法性能 | 低 | 添加性能测试，验证 View 样式方法的性能影响 |

## 变更验证记录

| 日期 | 变更摘要 | 验证结果 | 未覆盖项 |
|------|----------|----------|----------|
| 2026-02-27 | 创建模块文档 | 通过 | 无 |
