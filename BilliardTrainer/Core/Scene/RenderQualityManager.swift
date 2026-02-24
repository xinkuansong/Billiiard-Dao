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

    /// Frame timing for dynamic degradation
    private var recentFrameTimes: [CFTimeInterval] = []
    private let frameHistoryCount = 60
    private var degradationCooldown: CFTimeInterval = 0

    private init() {
        currentTier = RenderQualityManager.detectTier()
        featureFlags = RenderQualityManager.flags(for: currentTier)
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
                maxFPS: 120
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

    // MARK: - Dynamic Degradation

    func recordFrameTime(_ dt: CFTimeInterval) {
        recentFrameTimes.append(dt)
        if recentFrameTimes.count > frameHistoryCount {
            recentFrameTimes.removeFirst()
        }

        guard recentFrameTimes.count >= frameHistoryCount else { return }
        let now = CACurrentMediaTime()
        guard now > degradationCooldown else { return }

        let avgFPS = 1.0 / (recentFrameTimes.reduce(0, +) / Double(recentFrameTimes.count))
        let threshold: Double = currentTier == .high ? 50.0 : 25.0

        if avgFPS < threshold && currentTier > .low {
            degradeOneTier()
            degradationCooldown = now + 5.0
            recentFrameTimes.removeAll()
        }
    }

    private func degradeOneTier() {
        guard let lower = RenderTier(rawValue: currentTier.rawValue - 1) else { return }
        print("[RenderQuality] ⚠️ Degrading from \(currentTier) to \(lower)")
        currentTier = lower
        featureFlags = RenderQualityManager.flags(for: lower)
    }

    /// Force a specific tier (for testing / settings UI)
    func setTier(_ tier: RenderTier) {
        currentTier = tier
        featureFlags = RenderQualityManager.flags(for: tier)
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
