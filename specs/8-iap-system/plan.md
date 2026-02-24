# 实施计划：内购系统 (IAP System)

**分支**: `8-iap-system` | **日期**: 2026-02-20 | **规格**: [spec.md](./spec.md)  
**说明**: 内购系统技术方案，基于 StoreKit 2 的 IAPManager 服务设计与产品配置

## 摘要

内购系统采用 StoreKit 2 异步 API，通过 IAPManager（ObservableObject）统一管理产品加载、购买、恢复与 entitlement 计算。ContentView 注入 IAPManager，课程与训练视图通过 `isUnlocked(productId)` 或 `isCourseGroupUnlocked` / `isTrainingGroundUnlocked` 判定解锁。购买前使用自定义确认对话框，失败场景统一错误处理。产品配置通过 StoreKit Configuration 文件本地测试，App Store Connect 正式配置。

## 技术上下文

**语言/版本**: Swift 5.x  
**主要依赖**: StoreKit 2、SwiftUI  
**目标平台**: iOS 17+  
**项目类型**: 原生 iOS 应用  
**架构**: MVVM，IAPManager 为单例/环境注入  
**约束**: 纯本地 + Apple 收据，无自有服务器，无用户账户  
**规模**: Core/IAP/、Features/Settings/、Features/Course/、Features/Training/

## 核心架构决策

### 1. StoreKit 2 选型

- **决策**: 使用 StoreKit 2 现代 async/await API，不采用 StoreKit 1
- **理由**:
  - StoreKit 2 为 Apple 推荐，类型安全，async/await 与 Swift 并发一致
  - `Transaction.currentEntitlements` 自动反映最新购买
  - `Product`、`Transaction` 为值类型，易于测试
- **实现**: 导入 `StoreKit`，使用 `Product.products(for:)`、`Product.purchase()`、`Transaction.currentEntitlements`

### 2. IAPManager 服务设计

- **决策**: IAPManager 为 ObservableObject，承担产品加载、购买、恢复、entitlement 计算
- **理由**:
  - 单一职责，便于测试与维护
  - 通过 `@Published` 向 UI 发布 products、purchasedProductIds、loading、error
  - 课程/训练视图仅消费「是否解锁」结果，不直接接触 StoreKit
- **实现**:
  - `loadProducts()`: 加载 4 个 productId
  - `purchase(_ product:)`: 发起购买，返回 `Result<Transaction, Error>`
  - `restorePurchases()`: 调用 `Transaction.currentEntitlements` 刷新
  - `isPurchased(_ productId:)`: 检查 purchasedProductIds
  - `isCourseGroupUnlocked(group:)`: 根据包与课程组映射判断
  - `isTrainingGroundUnlocked(groundId:)`: 根据包与训练场映射判断

### 3. 产品 ID 与内容映射

- **决策**: 使用常量枚举集中定义 Product ID 与内容映射
- **理由**: 避免魔法字符串，便于修改与审核
- **实现**:

```swift
enum IAPProduct {
    static let basic = "com.app.course.basic"
    static let advanced = "com.app.course.advanced"
    static let expert = "com.app.course.expert"
    static let full = "com.app.course.full"

    static let all: [String] = [basic, advanced, expert, full]
}
```

- **课程组映射**:
  - basic → L4–L8、杆法训练场 (spin)
  - advanced → L9–L14、翻袋(bank)、K球(kick)、传球(pass)、颗星(diamond)
  - expert → L15–L18、解球(solve)、清台挑战
  - full → 全部

### 4. 购买前确认对话框

- **决策**: 自定义 SwiftUI 确认 sheet/alert，不依赖系统弹窗
- **理由**: 确保用户明确看到产品名、价格、确认/取消，符合 spec 要求
- **实现**: `IAPConfirmSheet` 或 `.confirmationDialog`，展示 product.displayName、product.displayPrice、确认/取消；确认后调用 `IAPManager.purchase(product)`

### 5. 购买失败处理

- **决策**: 统一通过 `IAPManager.error: String?` 与 `IAPManager.clearError()` 管理
- **理由**: UI 可绑定同一错误状态，显示 alert；用户确认后清除
- **实现**: `.userCancelled` → 「已取消」；`.networkError` → 「网络错误，请检查后重试」；其他 → 「购买失败，请稍后重试」

### 6. 恢复购买流程

- **决策**: 调用 `Transaction.currentEntitlements` 遍历，更新本地 purchasedProductIds
- **理由**: StoreKit 2 推荐方式，无需收据验证服务器
- **实现**: `restorePurchases()` async，遍历 `Transaction.currentEntitlements`，提取 productId，更新 `purchasedProductIds`，若 full 购买则等效于三个包均解锁

### 7. 与现有模型集成

- **决策**: 课程/训练解锁以 IAPManager 为唯一来源，不依赖 UserProfile.purchasedProducts 持久化
- **理由**: UserProfile.purchasedProducts 与 StoreKit 可能不一致；StoreKit 2 的 Transaction 为权威来源
- **实现**: App 启动时调用 `IAPManager.loadProducts()` 与 `Task { await IAPManager.syncEntitlements() }`，从 Transaction 同步；CourseListView、TrainingListView 通过 `@EnvironmentObject iapManager` 获取解锁状态

### 8. StoreKit Configuration 本地测试

- **决策**: 使用 .storekit 配置文件进行沙盒测试
- **理由**: 无需 App Store Connect 即可本地验证购买流程
- **实现**: Xcode 中创建 StoreKit Configuration，配置 4 个产品，Scheme 中启用 StoreKit Testing

## 项目结构

### 文档（本功能）

```text
specs/8-iap-system/
├── spec.md      # 功能规格
├── plan.md      # 本实施计划
└── tasks.md     # 任务列表
```

### 源代码

```text
current_work/BilliardTrainer/
├── Core/
│   └── IAP/
│       ├── IAPManager.swift           # 核心服务：产品加载、购买、恢复、entitlement
│       ├── IAPProduct.swift           # Product ID 与内容映射常量
│       └── IAPConfirmSheet.swift      # 购买确认对话框（可选独立文件）
├── Features/
│   ├── Settings/
│   │   └── Views/
│   │       ├── SettingsView.swift     # 恢复购买按钮接入 IAPManager
│   │       └── PurchasedContentView.swift  # 已购内容页接入 IAPManager
│   ├── Course/
│   │   └── Views/
│   │       └── CourseListView.swift   # 根据 IAPManager 决定 isLocked
│   └── Training/
│       └── Views/
│           └── TrainingListView.swift # 根据 IAPManager 决定 TrainingGround.isLocked
├── App/
│   └── BilliardTrainerApp.swift       # 注入 IAPManager 到 environmentObject
└── Configuration/
    └── Products.storekit              # StoreKit Configuration（Xcode 创建）
```

## IAPManager 接口设计

```swift
@MainActor
final class IAPManager: ObservableObject {
    // 产品列表（来自 StoreKit）
    @Published var products: [Product] = []
    // 已购 Product ID（从 Transaction 同步）
    @Published var purchasedProductIds: Set<String> = []
    // 加载/购买/恢复中
    @Published var isLoading = false
    // 错误提示（用户可见）
    @Published var errorMessage: String?
    // 恢复购买结果
    @Published var restoreResult: RestoreResult?

    func loadProducts() async
    func purchase(_ product: Product) async -> Result<Transaction, Error>
    func restorePurchases() async
    func syncEntitlements() async  // 从 Transaction 同步 purchasedProductIds
    func clearError()
    func isPurchased(_ productId: String) -> Bool
    func isCourseGroupUnlocked(group: CourseGroup) -> Bool
    func isTrainingGroundUnlocked(groundId: String) -> Bool
}

enum CourseGroup { case free, basic, advanced, expert }
enum RestoreResult { case success(Int), noPurchases, failed(String) }
```

## 内容映射表

| 课程组 / 训练场        | 所需 Product IDs                          |
|------------------------|--------------------------------------------|
| 入门 (L1–L3)           | 无（免费）                                 |
| 基础 (L4–L8)           | basic 或 full                              |
| 进阶 (L9–L14)          | advanced 或 full                           |
| 高级 (L15–L18)         | expert 或 full                             |
| 杆法训练场 (spin)      | basic 或 full                              |
| 翻袋训练场 (bank)      | advanced 或 full                           |
| K球训练场 (kick)       | advanced 或 full                           |
| 传球训练场 (pass)      | advanced 或 full                           |
| 颗星训练场 (diamond)   | advanced 或 full                           |
| 解球训练场 (solve)     | expert 或 full                             |
| 清台挑战               | expert 或 full                              |

## 依赖与执行顺序

- **阶段 1**: StoreKit 配置（.storekit、App Store Connect 产品配置）
- **阶段 2**: IAPManager 实现（产品加载、购买、恢复、映射）
- **阶段 3**: UI 集成（确认对话框、SettingsView、PurchasedContentView）
- **阶段 4**: 课程/训练视图解锁逻辑
- **阶段 5**: 沙盒测试与错误场景验证
