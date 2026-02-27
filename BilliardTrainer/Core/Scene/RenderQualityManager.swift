//
//  RenderQualityManager.swift
//  BilliardTrainer
//
//  渲染质量分级管理 + 运行时动态降级
//

import SceneKit
import UIKit

// MARK: - Render Tier

enum RenderTier: Int, Comparable, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2

    static func < (lhs: RenderTier, rhs: RenderTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Render Feature Flags

struct RenderFeatureFlags {
    var hdriEnabled: Bool
    var clearcoatEnabled: Bool
    var ssaoEnabled: Bool
    var ssaoIntensity: CGFloat
    var ssaoRadius: CGFloat
    var bloomEnabled: Bool
    var bloomIntensity: CGFloat
    var bloomThreshold: CGFloat
    var toneMappingEnabled: Bool
    var shadowMapSize: CGFloat
    var shadowSampleCount: Int
    var shadowRadius: CGFloat
    var shadowMode: SCNShadowMode
    var antialiasingMode: SCNAntialiasingMode
    var areaLightsEnabled: Bool
    var clothNormalEnabled: Bool
    var railClearcoatEnabled: Bool
    var environmentMapSize: Int
    var maxFPS: Int
}

// MARK: - Render Quality Manager

final class RenderQualityManager {

    static let shared = RenderQualityManager()

    private(set) var currentTier: RenderTier
    private(set) var featureFlags: RenderFeatureFlags

    /// Explicit per-feature overrides (for A/B comparison screenshots)
    private var overrides: [RenderFeature: Bool] = [:]

    /// Frame timing for dynamic tier adaptation
    private var recentFrameTimes: [CFTimeInterval] = []
    private let frameHistoryCount = 60
    private let tierChangeCooldown: CFTimeInterval = 6.0
    private var tierChangeCooldownUntil: CFTimeInterval = 0
    private var consecutiveLowFPSWindows: Int = 0
    private var consecutiveHighFPSWindows: Int = 0
    private let requiredWindowsForTierChange: Int = 2
    private(set) var currentFPS: Double = 60

    private init() {
        let detectedTier = RenderQualityManager.detectTier()
        currentTier = detectedTier
        featureFlags = RenderQualityManager.flags(for: detectedTier)
    }

    // MARK: - Tier Detection

    static func detectTier() -> RenderTier {
        let memoryGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        let maxFPS = UIScreen.main.maximumFramesPerSecond

        if memoryGB >= 6 && maxFPS >= 120 {
            return .high
        } else if memoryGB >= 4 {
            return .medium
        }
        return .low
    }

    static func flags(for tier: RenderTier) -> RenderFeatureFlags {
        switch tier {
        case .low:
            return RenderFeatureFlags(
                hdriEnabled: false,
                clearcoatEnabled: false,
                ssaoEnabled: false,
                ssaoIntensity: 0,
                ssaoRadius: 0,
                bloomEnabled: false,
                bloomIntensity: 0,
                bloomThreshold: 1.0,
                toneMappingEnabled: true,
                shadowMapSize: 2048,
                shadowSampleCount: 8,
                shadowRadius: 4,
                shadowMode: .forward,
                antialiasingMode: .multisampling2X,
                areaLightsEnabled: false,
                clothNormalEnabled: false,
                railClearcoatEnabled: false,
                environmentMapSize: 128,
                maxFPS: 60
            )
        case .medium:
            return RenderFeatureFlags(
                hdriEnabled: true,
                clearcoatEnabled: true,
                ssaoEnabled: true,
                ssaoIntensity: 0.18,
                ssaoRadius: 0.12,
                bloomEnabled: false,
                bloomIntensity: 0,
                bloomThreshold: 1.0,
                toneMappingEnabled: true,
                shadowMapSize: 4096,
                shadowSampleCount: 16,
                shadowRadius: 8,
                shadowMode: .forward,
                antialiasingMode: .multisampling2X,
                areaLightsEnabled: false,
                clothNormalEnabled: true,
                railClearcoatEnabled: false,
                environmentMapSize: 256,
                maxFPS: 60
            )
        case .high:
            return RenderFeatureFlags(
                hdriEnabled: true,
                clearcoatEnabled: true,
                ssaoEnabled: true,
                ssaoIntensity: 0.18,
                ssaoRadius: 0.12,
                bloomEnabled: true,
                bloomIntensity: 0.08,
                bloomThreshold: 1.0,
                toneMappingEnabled: true,
                shadowMapSize: 4096,
                shadowSampleCount: 16,
                shadowRadius: 10,
                shadowMode: .forward,
                antialiasingMode: .multisampling4X,
                areaLightsEnabled: false,
                clothNormalEnabled: true,
                railClearcoatEnabled: true,
                environmentMapSize: 512,
                maxFPS: 60
            )
        }
    }

    // MARK: - Feature Override (for A/B screenshots)

    func setOverride(_ feature: RenderFeature, enabled: Bool?) {
        overrides[feature] = enabled
    }

    func clearAllOverrides() {
        overrides.removeAll()
    }

    func isEnabled(_ feature: RenderFeature) -> Bool {
        if let override = overrides[feature] { return override }
        switch feature {
        case .hdriEnvironment:     return featureFlags.hdriEnabled
        case .clearcoatFresnel:    return featureFlags.clearcoatEnabled
        case .ssao:                return featureFlags.ssaoEnabled
        case .highQualityShadow:   return featureFlags.shadowMode == .deferred
        case .toneMapping:         return featureFlags.toneMappingEnabled
        case .bloom:               return featureFlags.bloomEnabled
        case .areaLights:          return featureFlags.areaLightsEnabled
        case .clothNormal:         return featureFlags.clothNormalEnabled
        case .railClearcoat:       return featureFlags.railClearcoatEnabled
        }
    }

    // MARK: - Dynamic Tier Adaptation

    @discardableResult
    func recordFrameTime(_ dt: CFTimeInterval) -> Bool {
        recentFrameTimes.append(dt)
        if recentFrameTimes.count > frameHistoryCount {
            recentFrameTimes.removeFirst()
        }
        let sampleCount = max(1, recentFrameTimes.count)
        currentFPS = 1.0 / (recentFrameTimes.reduce(0, +) / Double(sampleCount))

        guard recentFrameTimes.count >= frameHistoryCount else { return false }
        let now = CACurrentMediaTime()
        let avgFPS = 1.0 / (recentFrameTimes.reduce(0, +) / Double(recentFrameTimes.count))
        recentFrameTimes.removeAll()

        guard now > tierChangeCooldownUntil else { return false }

        if avgFPS < degradeThreshold(for: currentTier), currentTier > .low {
            consecutiveLowFPSWindows += 1
            consecutiveHighFPSWindows = 0
            if consecutiveLowFPSWindows >= requiredWindowsForTierChange {
                consecutiveLowFPSWindows = 0
                tierChangeCooldownUntil = now + tierChangeCooldown
                return degradeOneTier(avgFPS: avgFPS)
            }
            return false
        }

        if avgFPS > upgradeThreshold(for: currentTier), currentTier < .high {
            consecutiveHighFPSWindows += 1
            consecutiveLowFPSWindows = 0
            if consecutiveHighFPSWindows >= requiredWindowsForTierChange {
                consecutiveHighFPSWindows = 0
                tierChangeCooldownUntil = now + tierChangeCooldown
                return upgradeOneTier(avgFPS: avgFPS)
            }
            return false
        }

        consecutiveLowFPSWindows = 0
        consecutiveHighFPSWindows = 0
        return false
    }

    private func degradeOneTier(avgFPS: Double) -> Bool {
        guard let lower = RenderTier(rawValue: currentTier.rawValue - 1) else { return false }
        applyTier(
            lower,
            logPrefix: "⚠️ Degrading",
            avgFPS: avgFPS
        )
        return true
    }

    private func upgradeOneTier(avgFPS: Double) -> Bool {
        guard let higher = RenderTier(rawValue: currentTier.rawValue + 1) else { return false }
        applyTier(
            higher,
            logPrefix: "✅ Upgrading",
            avgFPS: avgFPS
        )
        return true
    }

    private func applyTier(_ tier: RenderTier, logPrefix: String, avgFPS: Double) {
        let from = currentTier
        currentTier = tier
        featureFlags = RenderQualityManager.flags(for: tier)
        print("[RenderQuality] \(logPrefix) from \(from) to \(tier), avgFPS=\(String(format: "%.1f", avgFPS))")
    }

    private func degradeThreshold(for tier: RenderTier) -> Double {
        switch tier {
        case .high:
            return 50.0
        case .medium:
            return 35.0
        case .low:
            return 0
        }
    }

    private func upgradeThreshold(for tier: RenderTier) -> Double {
        switch tier {
        case .low:
            return 48.0
        case .medium:
            return 56.0
        case .high:
            return .greatestFiniteMagnitude
        }
    }

    /// Force a specific tier (for testing / settings UI)
    func setTier(_ tier: RenderTier) {
        currentTier = tier
        featureFlags = RenderQualityManager.flags(for: tier)
        recentFrameTimes.removeAll()
        consecutiveLowFPSWindows = 0
        consecutiveHighFPSWindows = 0
        tierChangeCooldownUntil = CACurrentMediaTime() + tierChangeCooldown
        overrides.removeAll()
    }
}

// MARK: - Render Feature Enum

enum RenderFeature: String, CaseIterable {
    case hdriEnvironment
    case clearcoatFresnel
    case ssao
    case highQualityShadow
    case toneMapping
    case bloom
    case areaLights
    case clothNormal
    case railClearcoat
}
