# Audio - 验证与回归

> 对应 README：[README.md](./README.md)
> 文档最后更新：2026-02-27

## 影响面清单

改动本模块时，必须检查以下影响面：

- [ ] 调用方：BilliardSceneViewModel（通过 Extension 快捷方法调用）、Settings（通过 syncWithUserSettings 同步）
- [ ] 共享常量/状态：AudioManager.shared 单例、isSoundEnabled/isHapticEnabled 状态
- [ ] UI 交互链：SettingsView 修改设置 → syncWithUserSettings → 音效状态更新
- [ ] 持久化/数据映射：通过 UserProfile.soundEnabled/hapticEnabled 持久化设置
- [ ] 配置/开关：isSoundEnabled、isHapticEnabled、volume

## 最小回归门禁

每次改动后必须验证（不可跳过）：

### 主路径验证

- [ ] **音效播放**：触发击球/碰撞/进袋事件 → 应播放对应音效（需开启音效设置）
- [ ] **震动反馈**：触发击球/进袋/成功事件 → 应触发对应震动（需开启震动设置）

### 相邻流程验证（至少 2 个）

- [ ] **设置同步**：在设置页关闭音效 → 返回训练场景 → 触发音效事件 → 应不播放音效
- [ ] **力度分级**：轻击球（power < 0.3）→ 应播放 soft 音效 → 重击球（power > 0.7）→ 应播放 hard 音效
- [ ] **冲量分级**：轻碰撞（impulse < 0.5）→ 应播放 light 音效 → 重碰撞（impulse > 2.0）→ 应播放 hard 音效

## 测试入口

| 测试文件 | 覆盖内容 | 运行方式 |
|----------|----------|----------|
| 无 | Audio 模块暂无专用测试 | 通过 UI 手动验证 |

## 可观测性

- 日志前缀：`AudioManager:`
- 关键观测点：
  - `AudioManager: Failed to setup audio session:`：音频会话配置失败（非致命）
  - `AudioManager: Sound file not found:`：自定义音效文件加载失败（回退到系统音效）
  - `AudioManager: Failed to load sound:`：自定义音效文件加载失败（回退到系统音效）
- 可视化开关：无

## 常见问题排查

| 症状 | 可能原因 | 排查路径 |
|------|----------|----------|
| 无音效播放 | isSoundEnabled 为 false 或 AVAudioSession 配置失败 | 检查 UserProfile.soundEnabled、AVAudioSession 配置日志 |
| 无震动反馈 | isHapticEnabled 为 false 或设备不支持 | 检查 UserProfile.hapticEnabled、设备震动能力 |
| 音效分级不正确 | 力度/冲量阈值错误 | 检查 playCueHit/playBallCollision 的阈值定义 |
| 音量无法调节 | volume setter 未实现范围限制 | 检查 volume 设置逻辑，添加范围限制 |

## 未覆盖风险与待补测项

| 风险描述 | 等级 | 建议补测方式 |
|----------|------|-------------|
| 并发播放音效 | 中 | 添加并发测试，验证多音效同时播放时的行为 |
| 自定义音频文件加载 | 低 | 添加单元测试，验证 loadCustomSound 与 playCustomSound 的正确性 |
| 震动反馈性能 | 低 | 添加性能测试，验证频繁触发震动时的性能影响 |

## 变更验证记录

| 日期 | 变更摘要 | 验证结果 | 未覆盖项 |
|------|----------|----------|----------|
| 2026-02-27 | 创建模块文档 | 通过 | 无 |
