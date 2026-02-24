# 任务列表：内购系统 (IAP System)

**输入**: `specs/8-iap-system/` 下设计文档  
**状态**: 草案 (Draft)  
**完成度**: 0%  
**说明**: 内购系统实现任务，所有任务待完成。

## 格式：`[ID] [P?] [US?] 描述` + 文件路径

- **[P]**: 可并行执行（不同文件，无依赖）
- **[US?]**: 所属用户故事（US1–US6）
- 路径基于 `current_work/BilliardTrainer/`

---

## 阶段 1：StoreKit 2 配置

**目的**: 产品配置与本地测试环境

- [ ] T001 [P] 创建 StoreKit Configuration 文件（Products.storekit），配置 4 个非消耗型产品：com.app.course.basic、com.app.course.advanced、com.app.course.expert、com.app.course.full
  `Configuration/Products.storekit` 或 Xcode 新建

- [ ] T002 [P] 在 Scheme 中启用 StoreKit Testing，指向 Products.storekit
  项目 Scheme 配置

- [ ] T003 在 App Store Connect 中创建对应 In-App Purchase 产品（可选，提交审核前完成）
  外部 App Store Connect

---

## 阶段 2：IAP 核心服务

**目的**: IAPManager 与产品/内容映射

- [ ] T004 [P] 创建 IAPProduct 常量：定义 4 个 productId 与 all 数组
  `Core/IAP/IAPProduct.swift`

- [ ] T005 [P] 创建 IAPManager：@MainActor ObservableObject，@Published products、purchasedProductIds、isLoading、errorMessage、restoreResult
  `Core/IAP/IAPManager.swift`

- [ ] T006 实现 IAPManager.loadProducts()：Product.products(for: IAPProduct.all)，加载并赋值 products
  `Core/IAP/IAPManager.swift`

- [ ] T007 实现 IAPManager.syncEntitlements()：遍历 Transaction.currentEntitlements，更新 purchasedProductIds（含 full 等价于三包）
  `Core/IAP/IAPManager.swift`

- [ ] T008 实现 IAPManager.isPurchased(_ productId:)：检查 purchasedProductIds
  `Core/IAP/IAPManager.swift`

- [ ] T009 实现 IAPManager.isCourseGroupUnlocked(group:)：根据 basic/advanced/expert/full 映射返回 Bool
  `Core/IAP/IAPManager.swift`

- [ ] T010 实现 IAPManager.isTrainingGroundUnlocked(groundId:)：根据训练场与包映射返回 Bool
  `Core/IAP/IAPManager.swift`

- [ ] T011 实现 IAPManager.purchase(_ product:)：调用 product.purchase()，处理成功/失败，更新 purchasedProductIds，设置 errorMessage
  `Core/IAP/IAPManager.swift`

- [ ] T012 实现 IAPManager.restorePurchases()：调用 syncEntitlements，设置 restoreResult（success/noPurchases/failed）
  `Core/IAP/IAPManager.swift`

- [ ] T013 实现 IAPManager.clearError()：清除 errorMessage
  `Core/IAP/IAPManager.swift`

---

## 阶段 3：产品列表与购买流程

**目的**: 产品展示与购买确认 UI

- [ ] T014 [US1] 创建 IAPConfirmSheet：展示 product.displayName、product.displayPrice，确认/取消按钮，确认后调用 iapManager.purchase(product)
  `Core/IAP/IAPConfirmSheet.swift` 或 Settings 模块内

- [ ] T015 [US1] 实现 PurchasedContentView 产品列表：从 iapManager.products 渲染，已购显示「已解锁」，未购显示价格与购买按钮
  `Features/Settings/Views/SettingsView.swift` 或 PurchasedContentView

- [ ] T016 [US1] 购买按钮点击：弹出 IAPConfirmSheet，传入对应 Product
  `Features/Settings/Views/SettingsView.swift` PurchasedContentView / PurchaseRow

- [ ] T017 [US3] 确保购买流程：点击购买 → 先显示 IAPConfirmSheet → 用户确认后才调用 purchase
  `Core/IAP/IAPConfirmSheet.swift`

- [ ] T018 [US5] 购买失败时：设置 iapManager.errorMessage，UI 显示 alert 或 toast
  `Features/Settings/Views/SettingsView.swift` 或 PurchasedContentView

- [ ] T019 [US5] 实现错误文案映射：userCancelled→「已取消」，networkError→「网络错误」，其他→「购买失败，请稍后重试」
  `Core/IAP/IAPManager.swift`

---

## 阶段 4：恢复购买

**目的**: 恢复购买入口与流程

- [ ] T020 [US2] 在 SettingsView 恢复购买按钮中调用 iapManager.restorePurchases()
  `Features/Settings/Views/SettingsView.swift`

- [ ] T021 [US2] 恢复中显示 loading 状态（如 ProgressView 或 disabled 按钮）
  `Features/Settings/Views/SettingsView.swift`

- [ ] T022 [US2] 恢复成功：显示「已恢复 X 项购买」或类似提示；若 restoreResult == .noPurchases 显示「未发现购买记录」
  `Features/Settings/Views/SettingsView.swift`

- [ ] T023 [US2] 恢复失败：显示 iapManager.restoreResult?.failed 或 errorMessage
  `Features/Settings/Views/SettingsView.swift`

---

## 阶段 5：内容解锁逻辑

**目的**: 课程与训练场根据购买状态解锁

- [ ] T024 [US4] 修改 CourseListView：注入 @EnvironmentObject iapManager，CourseSection 的 isLocked 根据 iapManager.isCourseGroupUnlocked 计算
  `Features/Course/Views/CourseListView.swift`

- [ ] T025 [US4] 定义 CourseGroup 与课程组映射（free→L1-L3, basic→L4-L8, advanced→L9-L14, expert→L15-L18）
  `Features/Course/Views/CourseListView.swift` 或 IAPProduct/IAPManager

- [ ] T026 [US4] 修改 TrainingListView：TrainingGround 的 isLocked 根据 iapManager.isTrainingGroundUnlocked(groundId) 计算，不再硬编码
  `Features/Training/Views/TrainingListView.swift`

- [ ] T027 [US4] 修改 CourseCard / TrainingGroundCard：点击锁定项时，可跳转至购买页或弹出购买入口（可选）
  `Features/Course/Views/CourseListView.swift` 或 `Features/Training/Views/TrainingListView.swift`

---

## 阶段 6：App 启动与注入

**目的**: IAPManager 注入与启动同步

- [ ] T028 在 BilliardTrainerApp 或 ContentView 中创建 @StateObject iapManager，注入 .environmentObject(iapManager)
  `App/BilliardTrainerApp.swift` 或 `App/ContentView.swift`

- [ ] T029 应用启动时调用 Task { await iapManager.loadProducts(); await iapManager.syncEntitlements() }
  `App/BilliardTrainerApp.swift` 或根视图 .task

---

## 阶段 7：已购内容页完善

**目的**: 已购内容页与购买状态一致

- [ ] T030 [US6] PurchasedContentView 已购 Section：根据 purchasedProductIds 动态展示已解锁项
  `Features/Settings/Views/SettingsView.swift` PurchasedContentView

- [ ] T031 [US6] PurchasedContentView 未购 Section：从 products 获取价格，替换硬编码「¥18」等
  `Features/Settings/Views/SettingsView.swift` PurchaseRow

- [ ] T032 [US6] 全功能解锁购买后，已购 Section 显示全部包为已解锁
  `Core/IAP/IAPManager.swift` isPurchased 逻辑（full 视为三包均已购）

---

## 阶段 8：沙盒测试

**目的**: 验证购买与恢复流程

- [ ] T033 沙盒购买：使用 StoreKit Configuration，完成基础/进阶/高级/全功能各一次购买，验证解锁正确
  手动测试

- [ ] T034 恢复购买：购买后清除应用数据或重装，点击恢复购买，验证已购内容恢复
  手动测试

- [ ] T035 失败场景：模拟用户取消、网络断开，验证错误提示与无崩溃
  手动测试

- [ ] T036 购买前确认：验证点击购买必先弹出确认对话框，取消无扣款
  手动测试

---

## 依赖与执行顺序

### 阶段依赖

- **阶段 1**: 无依赖
- **阶段 2**: 依赖 T001（产品 ID 可用即可，StoreKit 配置可后补）
- **阶段 3**: 依赖 T005–T013
- **阶段 4**: 依赖 T005–T013
- **阶段 5**: 依赖 T005–T013、T024–T026 依赖 CourseListView、TrainingListView 存在
- **阶段 6**: 依赖 T005
- **阶段 7**: 依赖 T005–T013、T015–T016
- **阶段 8**: 依赖阶段 1–7

### 可并行任务

- T001、T002 可并行
- T004、T005 可并行
- T014、T015 可并行（不同 UI 组件）
- T024、T026 可并行（不同视图文件）
