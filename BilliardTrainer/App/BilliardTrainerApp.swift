//
//  BilliardTrainerApp.swift
//  BilliardTrainer
//
//  台球训练App - 主入口
//

import SwiftUI
import SwiftData
import UIKit

/// 屏幕方向控制辅助类
class OrientationHelper {
    /// 当前允许的方向
    static var orientationMask: UIInterfaceOrientationMask = .allButUpsideDown
    
    /// 强制横屏
    static func forceLandscape() {
        // 使用 landscape 掩码而非单侧方向，避免过渡期 VC 方向约束不一致导致请求失败
        orientationMask = .landscape
        requestOrientationUpdate(.landscape)
    }
    
    /// 恢复竖屏
    static func restorePortrait() {
        orientationMask = .allButUpsideDown
        requestOrientationUpdate(.allButUpsideDown)
    }
    
    private static func requestOrientationUpdate(_ targetMask: UIInterfaceOrientationMask) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        
        // 先通知 VC 更新 supportedInterfaceOrientations，再请求系统旋转
        windowScene.windows.forEach { window in
            window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
        if #unavailable(iOS 16.0) {
            UIViewController.attemptRotationToDeviceOrientation()
        }

        let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: targetMask)
        windowScene.requestGeometryUpdate(geometryPreferences) { error in
            // iOS 在场景过渡期间可能短暂拒绝方向请求；避免噪声日志影响排障
            print("[OrientationHelper] Geometry update warning: \(error)")
        }
    }
}

/// AppDelegate 用于控制支持的方向
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return OrientationHelper.orientationMask
    }
}

@main
struct BilliardTrainerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appState = AppState()

    /// SwiftData 模型容器
    var sharedModelContainer: ModelContainer = {
        print("[App] 🚀 创建 ModelContainer...")
        let schema = Schema([
            UserProfile.self,
            CourseProgress.self,
            UserStatistics.self,
            TrainingSession.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("[App] ✅ ModelContainer 创建成功")
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    print("[App] ✅ ContentView 已出现")
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - App State
/// 全局应用状态管理
class AppState: ObservableObject {
    @Published var isFirstLaunch: Bool
    @Published var currentUser: UserProfile?

    init() {
        self.isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        self.currentUser = nil

        // 首次启动标记
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }
    }

    // MARK: - User Management

    /// 加载或创建用户数据
    func loadOrCreateUser(context: ModelContext) {
        let descriptor = FetchDescriptor<UserProfile>()

        do {
            let users = try context.fetch(descriptor)
            if let existingUser = users.first {
                currentUser = existingUser
                existingUser.lastActiveAt = Date()
            } else {
                // 创建新用户
                let newUser = UserProfile()
                context.insert(newUser)
                try context.save()
                currentUser = newUser
            }
        } catch {
            print("Failed to load user: \(error)")
            // 创建新用户作为后备
            let newUser = UserProfile()
            context.insert(newUser)
            currentUser = newUser
        }
    }

    /// 保存训练会话
    func saveTrainingSession(
        context: ModelContext,
        trainingType: String,
        totalShots: Int,
        pocketedCount: Int,
        score: Int,
        duration: Int
    ) {
        guard let userId = currentUser?.id else { return }

        let session = TrainingSession(userId: userId, trainingType: trainingType)
        session.totalShots = totalShots
        session.pocketedCount = pocketedCount
        session.score = score
        session.endSession()

        context.insert(session)

        // 更新用户统计
        updateUserStatistics(
            context: context,
            userId: userId,
            totalShots: totalShots,
            pocketedCount: pocketedCount,
            duration: duration
        )

        do {
            try context.save()
        } catch {
            print("Failed to save training session: \(error)")
        }
    }

    /// 更新用户统计
    private func updateUserStatistics(
        context: ModelContext,
        userId: UUID,
        totalShots: Int,
        pocketedCount: Int,
        duration: Int
    ) {
        let descriptor = FetchDescriptor<UserStatistics>(
            predicate: #Predicate { $0.userId == userId }
        )

        do {
            let stats = try context.fetch(descriptor)
            let userStats: UserStatistics

            if let existingStats = stats.first {
                userStats = existingStats
            } else {
                userStats = UserStatistics(userId: userId)
                context.insert(userStats)
            }

            userStats.totalShots += totalShots
            userStats.totalPocketed += pocketedCount
            userStats.addPracticeTime(duration)
            userStats.updateCheckIn()

        } catch {
            print("Failed to update statistics: \(error)")
        }
    }
}
