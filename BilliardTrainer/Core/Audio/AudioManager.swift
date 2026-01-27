//
//  AudioManager.swift
//  BilliardTrainer
//
//  音效管理器
//

import Foundation
import AVFoundation
import AudioToolbox
import UIKit

// MARK: - Audio Manager
/// 音效管理单例
class AudioManager {

    // MARK: - Singleton

    static let shared = AudioManager()

    // MARK: - Properties

    /// 音效播放器缓存
    private var audioPlayers: [SoundType: AVAudioPlayer] = [:]

    /// 是否启用音效
    var isSoundEnabled: Bool = true

    /// 是否启用震动
    var isHapticEnabled: Bool = true

    /// 音量 (0.0 - 1.0)
    var volume: Float = 1.0 {
        didSet {
            audioPlayers.values.forEach { $0.volume = volume }
        }
    }

    // MARK: - Sound Types

    enum SoundType: String, CaseIterable {
        case cueHitSoft = "cue_hit_soft"
        case cueHitMedium = "cue_hit_medium"
        case cueHitHard = "cue_hit_hard"
        case ballCollisionLight = "ball_collision_light"
        case ballCollisionMedium = "ball_collision_medium"
        case ballCollisionHard = "ball_collision_hard"
        case cushionHit = "cushion_hit"
        case pocketDrop = "pocket_drop"
        case success = "success"
        case fail = "fail"
        case combo = "combo"
        case countdown = "countdown"
        case buttonTap = "button_tap"
    }

    // MARK: - Initialization

    private init() {
        setupAudioSession()
        preloadSounds()
    }

    // MARK: - Setup

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .ambient,
                mode: .default,
                options: [.mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AudioManager: Failed to setup audio session: \(error)")
        }
    }

    private func preloadSounds() {
        // 预加载常用音效
        // 注意：实际音效文件需要添加到项目中
        // 目前使用系统音效作为临时方案
    }

    // MARK: - Public Methods

    /// 播放音效
    func playSound(_ type: SoundType) {
        guard isSoundEnabled else { return }

        // 使用系统音效作为临时方案
        playSystemSound(for: type)
    }

    /// 播放击球音效（根据力度）
    func playCueHit(power: Float) {
        guard isSoundEnabled else { return }

        let type: SoundType
        if power < 0.3 {
            type = .cueHitSoft
        } else if power < 0.7 {
            type = .cueHitMedium
        } else {
            type = .cueHitHard
        }

        playSystemSound(for: type)
        playHaptic(for: type)
    }

    /// 播放球碰撞音效（根据冲量）
    func playBallCollision(impulse: Float) {
        guard isSoundEnabled else { return }

        let type: SoundType
        if impulse < 0.5 {
            type = .ballCollisionLight
        } else if impulse < 2.0 {
            type = .ballCollisionMedium
        } else {
            type = .ballCollisionHard
        }

        playSystemSound(for: type)
    }

    /// 播放库边碰撞音效（根据冲量）
    func playCushionHit(impulse: Float) {
        guard isSoundEnabled else { return }
        playSystemSound(for: .cushionHit)
    }

    /// 播放进袋音效
    func playPocketDrop() {
        guard isSoundEnabled else { return }
        playSystemSound(for: .pocketDrop)
        playHaptic(for: .pocketDrop)
    }

    /// 播放成功音效
    func playSuccess() {
        guard isSoundEnabled else { return }
        playSystemSound(for: .success)
        playHaptic(for: .success)
    }

    /// 播放失败音效
    func playFail() {
        guard isSoundEnabled else { return }
        playSystemSound(for: .fail)
    }

    /// 播放连击音效
    func playCombo() {
        guard isSoundEnabled else { return }
        playSystemSound(for: .combo)
        playHaptic(for: .combo)
    }

    // MARK: - System Sounds

    private func playSystemSound(for type: SoundType) {
        let soundID: SystemSoundID

        switch type {
        case .cueHitSoft:
            soundID = 1104  // 轻敲音
        case .cueHitMedium:
            soundID = 1103  // 中等敲击
        case .cueHitHard:
            soundID = 1105  // 重敲击
        case .ballCollisionLight:
            soundID = 1104
        case .ballCollisionMedium:
            soundID = 1103
        case .ballCollisionHard:
            soundID = 1105
        case .cushionHit:
            soundID = 1104
        case .pocketDrop:
            soundID = 1057  // 落袋音效
        case .success:
            soundID = 1025  // 成功音效
        case .fail:
            soundID = 1073  // 失败音效
        case .combo:
            soundID = 1054  // 连击音效
        case .countdown:
            soundID = 1113  // 倒计时
        case .buttonTap:
            soundID = 1104  // 按钮点击
        }

        AudioServicesPlaySystemSound(soundID)
    }

    // MARK: - Haptic Feedback

    private func playHaptic(for type: SoundType) {
        guard isHapticEnabled else { return }

        switch type {
        case .cueHitSoft, .ballCollisionLight:
            let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
            feedbackGenerator.impactOccurred()
        case .cueHitMedium, .ballCollisionMedium, .cushionHit:
            let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
            feedbackGenerator.impactOccurred()
        case .cueHitHard, .ballCollisionHard:
            let feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
            feedbackGenerator.impactOccurred()
        case .pocketDrop:
            let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
            feedbackGenerator.impactOccurred()
        case .success, .combo:
            let notificationGenerator = UINotificationFeedbackGenerator()
            notificationGenerator.notificationOccurred(.success)
        case .fail:
            let notificationGenerator = UINotificationFeedbackGenerator()
            notificationGenerator.notificationOccurred(.error)
        case .countdown, .buttonTap:
            let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
            feedbackGenerator.impactOccurred()
        }
    }

    // MARK: - Custom Sound Loading

    /// 加载自定义音效文件
    func loadCustomSound(named name: String, type: SoundType) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") ??
                        Bundle.main.url(forResource: name, withExtension: "wav") else {
            print("AudioManager: Sound file not found: \(name)")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.volume = volume
            audioPlayers[type] = player
        } catch {
            print("AudioManager: Failed to load sound: \(error)")
        }
    }

    /// 播放自定义音效
    func playCustomSound(_ type: SoundType) {
        guard isSoundEnabled else { return }

        if let player = audioPlayers[type] {
            player.currentTime = 0
            player.play()
        } else {
            // 回退到系统音效
            playSystemSound(for: type)
        }
    }

    // MARK: - Settings Sync

    /// 从用户设置同步音效状态
    func syncWithUserSettings(_ profile: UserProfile?) {
        isSoundEnabled = profile?.soundEnabled ?? true
        isHapticEnabled = profile?.hapticEnabled ?? true
    }
}

// MARK: - Audio Manager Extension for BilliardSceneViewModel
extension AudioManager {

    /// 快捷方法：播放碰撞音效
    func playCollision(impulse: Float) {
        playBallCollision(impulse: impulse)
    }

    /// 快捷方法：播放库边音效
    func playCushion(impulse: Float) {
        playCushionHit(impulse: impulse)
    }

    /// 快捷方法：播放击球音效
    func playStroke(power: Float) {
        playCueHit(power: power)
    }

    /// 快捷方法：播放进袋音效
    func playPocket() {
        playPocketDrop()
    }
}
