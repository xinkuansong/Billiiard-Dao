//
//  TrainingConfig.swift
//  BilliardTrainer
//
//  训练场配置模型
//

import Foundation
import SceneKit

// MARK: - Training Config
/// 训练场配置
struct TrainingConfig {
    /// 训练场ID
    let groundId: String

    /// 难度等级 (1-5星)
    let difficulty: Int

    /// 球的位置配置
    let ballPositions: [BallPosition]

    /// 目标区域（可选）
    let targetZone: TargetZone?

    /// 时间限制（秒），nil表示无限时
    let timeLimit: Int?

    /// 目标进球数
    let goalCount: Int

    /// 训练类型
    let trainingType: TrainingSceneType

    // MARK: - Initialization

    init(
        groundId: String,
        difficulty: Int,
        ballPositions: [BallPosition] = [],
        targetZone: TargetZone? = nil,
        timeLimit: Int? = nil,
        goalCount: Int = 10,
        trainingType: TrainingSceneType = .aiming
    ) {
        self.groundId = groundId
        self.difficulty = min(max(difficulty, 1), 5)
        self.ballPositions = ballPositions
        self.targetZone = targetZone
        self.timeLimit = timeLimit
        self.goalCount = goalCount
        self.trainingType = trainingType
    }

    // MARK: - Preset Configs

    /// 瞄准训练配置
    static func aimingConfig(difficulty: Int) -> TrainingConfig {
        TrainingConfig(
            groundId: "aiming",
            difficulty: difficulty,
            goalCount: 10,
            trainingType: .aiming
        )
    }

    /// 杆法训练配置
    static func spinConfig(difficulty: Int) -> TrainingConfig {
        TrainingConfig(
            groundId: "spin",
            difficulty: difficulty,
            goalCount: 10,
            trainingType: .spin
        )
    }

    /// 翻袋训练配置
    static func bankShotConfig(difficulty: Int) -> TrainingConfig {
        TrainingConfig(
            groundId: "bank",
            difficulty: difficulty,
            goalCount: 10,
            trainingType: .bankShot
        )
    }

    /// K球训练配置
    static func kickShotConfig(difficulty: Int) -> TrainingConfig {
        TrainingConfig(
            groundId: "kick",
            difficulty: difficulty,
            goalCount: 10,
            trainingType: .kickShot
        )
    }

    /// 颗星计算训练配置
    static func diamondConfig(difficulty: Int) -> TrainingConfig {
        TrainingConfig(
            groundId: "diamond",
            difficulty: difficulty,
            goalCount: 10,
            trainingType: .diamond
        )
    }
}

// MARK: - Training Scene Type
/// 训练场景类型
enum TrainingSceneType: String, CaseIterable {
    case aiming = "瞄准训练"
    case spin = "杆法训练"
    case bankShot = "翻袋训练"
    case kickShot = "K球训练"
    case diamond = "颗星训练"

    /// 图标名称
    var iconName: String {
        switch self {
        case .aiming: return "target"
        case .spin: return "circle.circle"
        case .bankShot: return "arrow.triangle.swap"
        case .kickShot: return "arrow.turn.up.right"
        case .diamond: return "diamond"
        }
    }

    /// 训练说明
    var description: String {
        switch self {
        case .aiming: return "练习直球和角度球的瞄准"
        case .spin: return "练习高杆、低杆和侧旋"
        case .bankShot: return "练习翻袋技术"
        case .kickShot: return "练习K球解球"
        case .diamond: return "练习颗星系统计算"
        }
    }
}

// MARK: - Ball Position
/// 球的位置配置
struct BallPosition {
    /// 球号 (0=母球, 1-15=目标球)
    let ballNumber: Int

    /// 位置坐标
    let position: SCNVector3

    /// 是否为母球
    var isCueBall: Bool {
        return ballNumber == 0
    }

    // MARK: - Initialization

    init(ballNumber: Int, position: SCNVector3) {
        self.ballNumber = ballNumber
        self.position = position
    }

    init(ballNumber: Int, x: Float, z: Float) {
        self.ballNumber = ballNumber
        self.position = SCNVector3(
            x,
            TablePhysics.height + BallPhysics.radius + 0.001,
            z
        )
    }

    // MARK: - Preset Positions

    /// 母球默认位置（开球区）
    static let defaultCueBall = BallPosition(
        ballNumber: 0,
        x: -TablePhysics.innerLength / 4,
        z: 0
    )

    /// 直球目标位置
    static func straightTarget(number: Int = 1) -> BallPosition {
        BallPosition(ballNumber: number, x: 0.5, z: 0)
    }

    /// 角度球目标位置
    static func angleTarget(number: Int = 1, angle: Float) -> BallPosition {
        let radians = angle * .pi / 180
        let z = 0.5 * sin(radians)
        return BallPosition(ballNumber: number, x: 0.5, z: z)
    }
}

// MARK: - Target Zone
/// 目标区域（用于走位训练等）
struct TargetZone {
    /// 区域中心位置
    let center: SCNVector3

    /// 区域半径
    let radius: Float

    /// 区域颜色（用于显示）
    let color: (r: Float, g: Float, b: Float, a: Float)

    // MARK: - Initialization

    init(
        center: SCNVector3,
        radius: Float,
        color: (r: Float, g: Float, b: Float, a: Float) = (0, 1, 0, 0.3)
    ) {
        self.center = center
        self.radius = radius
        self.color = color
    }

    init(x: Float, z: Float, radius: Float) {
        self.center = SCNVector3(
            x,
            TablePhysics.height + 0.001,
            z
        )
        self.radius = radius
        self.color = (0, 1, 0, 0.3)
    }

    // MARK: - Hit Test

    /// 检测点是否在目标区域内
    func contains(_ point: SCNVector3) -> Bool {
        let dx = point.x - center.x
        let dz = point.z - center.z
        let distance = sqrt(dx * dx + dz * dz)
        return distance <= radius
    }

    /// 计算点与目标中心的距离比例（0=中心，1=边缘，>1=外部）
    func distanceRatio(from point: SCNVector3) -> Float {
        let dx = point.x - center.x
        let dz = point.z - center.z
        let distance = sqrt(dx * dx + dz * dz)
        return distance / radius
    }
}

// MARK: - Training Result
/// 训练结果
struct TrainingResult {
    /// 总得分
    let score: Int

    /// 进球数
    let pocketedCount: Int

    /// 总击球数
    let totalShots: Int

    /// 用时（秒）
    let duration: Int

    /// 星级评价 (1-5)
    let stars: Int

    /// 进球率
    var accuracy: Double {
        guard totalShots > 0 else { return 0 }
        return Double(pocketedCount) / Double(totalShots)
    }

    /// 格式化进球率
    var formattedAccuracy: String {
        return String(format: "%.1f%%", accuracy * 100)
    }

    /// 格式化时长
    var formattedDuration: String {
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Star Calculation

    /// 根据得分计算星级
    static func calculateStars(score: Int, maxScore: Int) -> Int {
        let ratio = Double(score) / Double(maxScore)
        switch ratio {
        case 0.9...: return 5
        case 0.75..<0.9: return 4
        case 0.6..<0.75: return 3
        case 0.4..<0.6: return 2
        default: return 1
        }
    }
}
