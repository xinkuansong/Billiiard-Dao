# App - 验证与回归

> 对应 README：[README.md](./README.md)
> 文档最后更新：2026-02-27

## 影响面清单

改动本模块时，必须检查以下影响面：

- [ ] 调用方：所有 Features 模块（通过 @EnvironmentObject 获取 AppState，通过 @Environment 获取 ModelContainer）
- [ ] 共享常量/状态：UserDefaults key "hasLaunchedBefore"、AppState.currentUser、ModelContainer schema
- [ ] UI 交互链：ContentView 的首次启动判断 → OnboardingView / MainTabView 切换
- [ ] 持久化/数据映射：ModelContainer schema 变更会影响所有 SwiftData 模型
- [ ] 配置/开关：无

## 最小回归门禁

每次改动后必须验证（不可跳过）：

### 主路径验证

- [ ] **首次启动流程**：删除应用重新安装 → 启动应用 → 应显示 OnboardingView → 完成引导 → 应显示 MainTabView
- [ ] **非首次启动流程**：正常启动应用 → 应直接显示 MainTabView，不显示引导页

### 相邻流程验证（至少 2 个）

- [ ] **Tab 导航**：点击各个 Tab（首页、课程、训练、统计、设置）→ 应正常切换，Tab 图标为绿色
- [ ] **方向控制**：进入训练场景 → 应自动切换为横屏 → 退出训练 → 应恢复竖屏（如实现）
- [ ] **用户数据加载**：首次启动后创建用户 → 退出应用重新启动 → 应加载已有用户数据，不重复创建

## 测试入口

| 测试文件 | 覆盖内容 | 运行方式 |
|----------|----------|----------|
| 无 | App 模块暂无专用测试 | 通过 UI 手动验证 |

## 可观测性

- 日志前缀：`[App]`、`[OrientationHelper]`
- 关键观测点：
  - `[App] 🚀 创建 ModelContainer...` / `[App] ✅ ModelContainer 创建成功`：容器初始化状态
  - `[App] ✅ ContentView 已出现`：根视图渲染完成
  - `[OrientationHelper] Geometry update warning:`：方向变更请求失败（非致命）
- 可视化开关：无

## 常见问题排查

| 症状 | 可能原因 | 排查路径 |
|------|----------|----------|
| 应用启动崩溃 | ModelContainer 初始化失败 | 检查 SwiftData 模型定义、存储权限、schema 兼容性 |
| 每次启动都显示引导页 | UserDefaults key 变更或未正确保存 | 检查 "hasLaunchedBefore" 键名与保存逻辑 |
| Tab 图标不是绿色 | MainTabView.tint 被覆盖 | 检查子视图是否覆盖了 tint 设置 |
| 方向控制不生效 | iOS 版本兼容性或窗口场景未就绪 | 检查 iOS 版本、窗口场景可用性、OrientationHelper 调用时机 |

## 未覆盖风险与待补测项

| 风险描述 | 等级 | 建议补测方式 |
|----------|------|-------------|
| ModelContainer schema 迁移 | 高 | 创建迁移测试，验证旧版本数据在新版本中可正常加载 |
| 多窗口场景下的方向控制 | 中 | 在 iPad 多窗口模式下测试方向切换 |
| AppState 并发访问 | 低 | 添加并发测试，验证 @Published 属性的线程安全 |

## 变更验证记录

| 日期 | 变更摘要 | 验证结果 | 未覆盖项 |
|------|----------|----------|----------|
| 2026-02-27 | 创建模块文档 | 通过 | 无 |
