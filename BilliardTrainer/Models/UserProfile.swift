//
//  UserProfile.swift
//  BilliardTrainer
//
//  用户数据模型
//

import Foundation
import SwiftData

// MARK: - User Profile
/// 用户档案
@Model
final class UserProfile {
    /// 用户ID
    var id: UUID
    
    /// 昵称
    var nickname: String
    
    /// 等级
    var level: Int
    
    /// 经验值
    var experience: Int
    
    /// 创建时间
    var createdAt: Date
    
    /// 最后活跃时间
    var lastActiveAt: Date
    
    /// 购买记录
    var purchasedProducts: [String]
    
    /// 设置项
    var soundEnabled: Bool
    var hapticEnabled: Bool
    var aimLineEnabled: Bool
    var trajectoryEnabled: Bool
    
    // MARK: - Initialization
    
    init(
        nickname: String = "新玩家",
        level: Int = 1,
        experience: Int = 0
    ) {
        self.id = UUID()
        self.nickname = nickname
        self.level = level
        self.experience = experience
        self.createdAt = Date()
        self.lastActiveAt = Date()
        self.purchasedProducts = []
        self.soundEnabled = true
        self.hapticEnabled = true
        self.aimLineEnabled = true
        self.trajectoryEnabled = false
    }
    
    // MARK: - Level System
    
    /// 经验值到下一级所需
    var experienceToNextLevel: Int {
        switch level {
        case 1: return 500
        case 2: return 1500
        case 3: return 4000
        case 4: return 10000
        default: return 10000
        }
    }
    
    /// 等级名称
    var levelName: String {
        switch level {
        case 1: return "新手"
        case 2: return "入门"
        case 3: return "进阶"
        case 4: return "熟练"
        case 5: return "专家"
        default: return "大师"
        }
    }
    
    /// 添加经验值
    func addExperience(_ amount: Int) {
        experience += amount
        checkLevelUp()
    }
    
    /// 检查升级
    private func checkLevelUp() {
        while experience >= experienceToNextLevel && level < 5 {
            experience -= experienceToNextLevel
            level += 1
        }
    }
    
    // MARK: - Purchase
    
    /// 是否已购买
    func hasPurchased(_ productId: String) -> Bool {
        return purchasedProducts.contains(productId)
    }
    
    /// 添加购买
    func addPurchase(_ productId: String) {
        if !purchasedProducts.contains(productId) {
            purchasedProducts.append(productId)
        }
    }
}

// MARK: - Course Progress
/// 课程进度
@Model
final class CourseProgress {
    /// 关联的用户ID
    var userId: UUID
    
    /// 课程ID
    var courseId: Int
    
    /// 是否完成
    var isCompleted: Bool
    
    /// 完成时间
    var completedAt: Date?
    
    /// 最高分数
    var bestScore: Int
    
    /// 学习次数
    var practiceCount: Int
    
    init(userId: UUID, courseId: Int) {
        self.userId = userId
        self.courseId = courseId
        self.isCompleted = false
        self.bestScore = 0
        self.practiceCount = 0
    }
    
    /// 标记完成
    func markCompleted(score: Int) {
        if !isCompleted {
            isCompleted = true
            completedAt = Date()
        }
        if score > bestScore {
            bestScore = score
        }
        practiceCount += 1
    }
}

// MARK: - User Statistics
/// 用户统计数据
@Model
final class UserStatistics {
    /// 关联的用户ID
    var userId: UUID
    
    /// 总练习时长（秒）
    var totalPracticeTime: Int
    
    /// 总进球数
    var totalPocketed: Int
    
    /// 总击球数
    var totalShots: Int
    
    /// 直球进球数
    var straightShotsMade: Int
    var straightShotsAttempted: Int
    
    /// 角度球进球数（按角度分类）
    var angle30ShotsMade: Int
    var angle30ShotsAttempted: Int
    var angle45ShotsMade: Int
    var angle45ShotsAttempted: Int
    var angle60ShotsMade: Int
    var angle60ShotsAttempted: Int
    
    /// 各杆法使用次数
    var centerShotCount: Int
    var topSpinCount: Int
    var drawShotCount: Int
    var leftEnglishCount: Int
    var rightEnglishCount: Int
    
    /// 连续签到天数
    var consecutiveDays: Int
    
    /// 最后练习日期
    var lastPracticeDate: Date?
    
    // MARK: - Initialization
    
    init(userId: UUID) {
        self.userId = userId
        self.totalPracticeTime = 0
        self.totalPocketed = 0
        self.totalShots = 0
        self.straightShotsMade = 0
        self.straightShotsAttempted = 0
        self.angle30ShotsMade = 0
        self.angle30ShotsAttempted = 0
        self.angle45ShotsMade = 0
        self.angle45ShotsAttempted = 0
        self.angle60ShotsMade = 0
        self.angle60ShotsAttempted = 0
        self.centerShotCount = 0
        self.topSpinCount = 0
        self.drawShotCount = 0
        self.leftEnglishCount = 0
        self.rightEnglishCount = 0
        self.consecutiveDays = 0
    }
    
    // MARK: - Computed Properties
    
    /// 总进球率
    var overallAccuracy: Double {
        guard totalShots > 0 else { return 0 }
        return Double(totalPocketed) / Double(totalShots)
    }
    
    /// 直球进球率
    var straightShotAccuracy: Double {
        guard straightShotsAttempted > 0 else { return 0 }
        return Double(straightShotsMade) / Double(straightShotsAttempted)
    }
    
    /// 30度角度球进球率
    var angle30Accuracy: Double {
        guard angle30ShotsAttempted > 0 else { return 0 }
        return Double(angle30ShotsMade) / Double(angle30ShotsAttempted)
    }
    
    /// 45度角度球进球率
    var angle45Accuracy: Double {
        guard angle45ShotsAttempted > 0 else { return 0 }
        return Double(angle45ShotsMade) / Double(angle45ShotsAttempted)
    }
    
    /// 60度角度球进球率
    var angle60Accuracy: Double {
        guard angle60ShotsAttempted > 0 else { return 0 }
        return Double(angle60ShotsMade) / Double(angle60ShotsAttempted)
    }
    
    /// 格式化练习时长
    var formattedPracticeTime: String {
        let hours = totalPracticeTime / 3600
        let minutes = (totalPracticeTime % 3600) / 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
    
    // MARK: - Update Methods
    
    /// 记录击球
    func recordShot(type: ShotType, made: Bool) {
        totalShots += 1
        if made {
            totalPocketed += 1
        }
        
        switch type {
        case .straight:
            straightShotsAttempted += 1
            if made { straightShotsMade += 1 }
        case .angle30:
            angle30ShotsAttempted += 1
            if made { angle30ShotsMade += 1 }
        case .angle45:
            angle45ShotsAttempted += 1
            if made { angle45ShotsMade += 1 }
        case .angle60:
            angle60ShotsAttempted += 1
            if made { angle60ShotsMade += 1 }
        }
    }
    
    /// 记录杆法使用
    func recordSpin(type: SpinType) {
        switch type {
        case .center: centerShotCount += 1
        case .top: topSpinCount += 1
        case .draw: drawShotCount += 1
        case .left: leftEnglishCount += 1
        case .right: rightEnglishCount += 1
        }
    }
    
    /// 添加练习时长
    func addPracticeTime(_ seconds: Int) {
        totalPracticeTime += seconds
    }
    
    /// 更新签到
    func updateCheckIn() {
        let today = Calendar.current.startOfDay(for: Date())
        
        if let lastDate = lastPracticeDate {
            let lastDay = Calendar.current.startOfDay(for: lastDate)
            let daysDiff = Calendar.current.dateComponents([.day], from: lastDay, to: today).day ?? 0
            
            if daysDiff == 1 {
                consecutiveDays += 1
            } else if daysDiff > 1 {
                consecutiveDays = 1
            }
            // daysDiff == 0 means same day, don't update
        } else {
            consecutiveDays = 1
        }
        
        lastPracticeDate = Date()
    }
    
    // MARK: - Enums
    
    enum ShotType {
        case straight
        case angle30
        case angle45
        case angle60
    }
    
    enum SpinType {
        case center
        case top
        case draw
        case left
        case right
    }
}

// MARK: - Training Session
/// 训练会话记录
@Model
final class TrainingSession {
    /// 会话ID
    var id: UUID
    
    /// 用户ID
    var userId: UUID
    
    /// 训练类型
    var trainingType: String
    
    /// 开始时间
    var startTime: Date
    
    /// 结束时间
    var endTime: Date?
    
    /// 总击球数
    var totalShots: Int
    
    /// 进球数
    var pocketedCount: Int
    
    /// 得分
    var score: Int
    
    init(userId: UUID, trainingType: String) {
        self.id = UUID()
        self.userId = userId
        self.trainingType = trainingType
        self.startTime = Date()
        self.totalShots = 0
        self.pocketedCount = 0
        self.score = 0
    }
    
    /// 会话时长（秒）
    var duration: Int {
        let end = endTime ?? Date()
        return Int(end.timeIntervalSince(startTime))
    }
    
    /// 进球率
    var accuracy: Double {
        guard totalShots > 0 else { return 0 }
        return Double(pocketedCount) / Double(totalShots)
    }
    
    /// 结束会话
    func endSession() {
        endTime = Date()
    }
}
