//
//  TrainingViewModel.swift
//  BilliardTrainer
//
//  训练状态管理
//

import Foundation
import SwiftUI
import Combine

// MARK: - Training View Model
/// 训练场视图模型
@MainActor
class TrainingViewModel: ObservableObject {

    // MARK: - Published Properties

    /// 当前得分
    @Published var currentScore: Int = 0

    /// 剩余球数
    @Published var remainingBalls: Int = 10

    /// 剩余时间（秒），nil表示无限时
    @Published var timeRemaining: Int?

    /// 当前击球次数
    @Published var shotCount: Int = 0

    /// 进球数
    @Published var pocketedCount: Int = 0

    /// 训练是否完成
    @Published var isTrainingComplete: Bool = false

    /// 训练是否暂停
    @Published var isPaused: Bool = false

    /// 是否显示结果页面
    @Published var showResult: Bool = false

    /// 当前连击数
    @Published var comboCount: Int = 0

    /// 最大连击数
    @Published var maxCombo: Int = 0

    // MARK: - Properties

    /// 训练配置
    let config: TrainingConfig

    /// 场景视图模型
    let sceneViewModel: BilliardSceneViewModel

    /// 训练开始时间
    private var startTime: Date?

    /// 计时器
    private var timer: Timer?

    /// 取消订阅集合
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    /// 训练时长（秒）
    var elapsedTime: Int {
        guard let start = startTime else { return 0 }
        return Int(Date().timeIntervalSince(start))
    }

    /// 进球率
    var accuracy: Double {
        guard shotCount > 0 else { return 0 }
        return Double(pocketedCount) / Double(shotCount)
    }

    /// 格式化进球率
    var formattedAccuracy: String {
        return String(format: "%.0f%%", accuracy * 100)
    }

    /// 格式化剩余时间
    var formattedTimeRemaining: String {
        guard let time = timeRemaining else { return "--:--" }
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// 目标进度 (0-1)
    var progress: Double {
        return Double(pocketedCount) / Double(config.goalCount)
    }

    // MARK: - Initialization

    init(config: TrainingConfig) {
        self.config = config
        self.sceneViewModel = BilliardSceneViewModel()
        self.remainingBalls = config.goalCount
        self.timeRemaining = config.timeLimit

        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // 监听游戏状态变化
        sceneViewModel.$gameState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleGameStateChange(state)
            }
            .store(in: &cancellables)
    }

    // MARK: - Training Control

    /// 开始训练
    func startTraining() {
        // 重置状态
        currentScore = 0
        remainingBalls = config.goalCount
        shotCount = 0
        pocketedCount = 0
        comboCount = 0
        maxCombo = 0
        isTrainingComplete = false
        isPaused = false
        showResult = false

        // 设置时间限制
        timeRemaining = config.timeLimit

        // 记录开始时间
        startTime = Date()

        // 设置场景
        setupScene()

        // 开始计时器
        startTimer()
    }

    /// 暂停训练
    func pauseTraining() {
        isPaused = true
        timer?.invalidate()
    }

    /// 恢复训练
    func resumeTraining() {
        isPaused = false
        startTimer()
    }

    /// 结束训练
    func endTraining() {
        timer?.invalidate()
        isTrainingComplete = true
        showResult = true
    }

    /// 重新开始训练
    func restartTraining() {
        startTraining()
    }

    // MARK: - Scene Setup

    private func setupScene() {
        // 根据训练类型设置场景
        switch config.trainingType {
        case .aiming:
            sceneViewModel.setupTrainingScene(type: .aiming(difficulty: config.difficulty))
        case .spin:
            let spinType = spinTypeForDifficulty(config.difficulty)
            sceneViewModel.setupTrainingScene(type: .spin(spinType))
        case .bankShot:
            sceneViewModel.setupTrainingScene(type: .bankShot)
        case .kickShot:
            sceneViewModel.setupTrainingScene(type: .kickShot)
        case .diamond:
            sceneViewModel.setupTrainingScene(type: .kickShot) // 使用K球场景
        }
    }

    private func spinTypeForDifficulty(_ difficulty: Int) -> BilliardSceneViewModel.SpinType {
        switch difficulty {
        case 1: return .center
        case 2: return .top
        case 3: return .bottom
        case 4: return .left
        default: return .right
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()

        guard config.timeLimit != nil else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateTimer()
            }
        }
    }

    private func updateTimer() {
        guard !isPaused else { return }

        if let remaining = timeRemaining {
            if remaining > 0 {
                timeRemaining = remaining - 1
            } else {
                // 时间到
                endTraining()
            }
        }
    }

    // MARK: - Event Handlers

    /// 处理球进袋
    func handleBallPocketed() {
        pocketedCount += 1
        remainingBalls -= 1
        comboCount += 1

        if comboCount > maxCombo {
            maxCombo = comboCount
        }

        // 计算得分
        let baseScore = 100
        let comboBonus = (comboCount - 1) * 20
        let difficultyBonus = config.difficulty * 10
        let pointsEarned = baseScore + comboBonus + difficultyBonus

        currentScore += pointsEarned

        // 检查是否完成目标
        if pocketedCount >= config.goalCount {
            endTraining()
        } else {
            // 重置场景准备下一球
            resetForNextShot()
        }
    }

    /// 处理击球（未进袋）
    func handleShotMissed() {
        shotCount += 1
        comboCount = 0

        // 重置场景
        resetForNextShot()
    }

    /// 处理击球
    func handleShotTaken() {
        shotCount += 1
    }

    private func handleGameStateChange(_ state: BilliardSceneViewModel.GameState) {
        switch state {
        case .turnEnd:
            // 回合结束，检查是否需要重置
            break
        default:
            break
        }
    }

    private func resetForNextShot() {
        // 延迟重置场景
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self, !self.isTrainingComplete else { return }
            self.setupScene()
        }
    }

    // MARK: - Result Calculation

    /// 计算最终结果
    func calculateFinalResult() -> TrainingResult {
        let duration = elapsedTime
        let maxPossibleScore = config.goalCount * (100 + config.difficulty * 10 + 100) // 最大连击奖励
        let stars = TrainingResult.calculateStars(score: currentScore, maxScore: maxPossibleScore)

        return TrainingResult(
            score: currentScore,
            pocketedCount: pocketedCount,
            totalShots: shotCount,
            duration: duration,
            stars: stars
        )
    }

    // MARK: - Cleanup

    deinit {
        timer?.invalidate()
    }
}
