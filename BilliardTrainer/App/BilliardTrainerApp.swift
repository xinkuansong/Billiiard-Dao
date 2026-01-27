//
//  BilliardTrainerApp.swift
//  BilliardTrainer
//
//  台球训练App - 主入口
//

import SwiftUI
import SwiftData

@main
struct BilliardTrainerApp: App {
    @StateObject private var appState = AppState()

    /// SwiftData 模型容器
    var sharedModelContainer: ModelContainer = {
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
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
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
