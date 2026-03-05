//
//  EnvironmentLightingManager.swift
//  BilliardTrainer
//
//  摄影棚式 IBL + 背景分离
//  - lightingEnvironment: 偏中性 cube map，干净反射
//  - background: 冷灰蓝 C1 连续渐变，棚拍空间感
//

import SceneKit
import UIKit
import simd

final class EnvironmentLightingManager {

    // MARK: - Cube Map Cache (per-tier, supports prewarm)

    private static var iblCache: [RenderTier: [UIImage]] = [:]
    private static var backgroundCache: [RenderTier: [UIImage]] = [:]

    static func invalidateCache() {
        iblCache.removeAll()
        backgroundCache.removeAll()
    }

    /// 启动时在后台预热所有 Tier 的 IBL + 背景贴图，确保 Tier 切换时 100% 命中缓存
    static func prewarmAllTiers() {
        DispatchQueue.global(qos: .utility).async {
            for tier in RenderTier.allCases {
                let size = max(256, RenderQualityManager.flags(for: tier).environmentMapSize)
                let ibl = generateIBLCubeMap(size: size)
                let bg = generateBackgroundCubeMap(size: size)
                DispatchQueue.main.async {
                    if iblCache[tier] == nil { iblCache[tier] = ibl }
                    if backgroundCache[tier] == nil { backgroundCache[tier] = bg }
                }
            }
            print("[EnvironmentLighting] IBL prewarm complete for all tiers")
        }
    }

    // MARK: - Public API

    static func apply(to scene: SCNScene, tier: RenderTier) {
        let flags = RenderQualityManager.shared.featureFlags

        if flags.hdriEnabled,
           let hdrURL = Bundle.main.url(forResource: "billiard_hall", withExtension: "hdr") {
            scene.lightingEnvironment.contents = hdrURL
            scene.lightingEnvironment.intensity = iblIntensity(for: tier)
            scene.lightingEnvironment.contentsTransform = SCNMatrix4MakeRotation(.pi * 0.25, 0, 1, 0)
            let bg = cachedBackground(for: tier, size: 256)
            scene.background.contents = bg
            return
        }

        let mapSize = max(256, flags.environmentMapSize)
        scene.lightingEnvironment.contents = cachedIBL(for: tier, size: mapSize)
        scene.lightingEnvironment.intensity = iblIntensity(for: tier)
        scene.background.contents = cachedBackground(for: tier, size: mapSize)
    }

    // MARK: - IBL Intensity per Tier

    /// Per-tier IBL intensity: low=0.95, medium=1.60, high=1.80
    private static func iblIntensity(for tier: RenderTier) -> CGFloat {
        switch tier {
        case .low:    return 0.95
        case .medium: return 1.60
        case .high:   return 1.80
        }
    }

    private static func cachedIBL(for tier: RenderTier, size: Int) -> [UIImage] {
        if let cached = iblCache[tier] { return cached }
        let images = generateIBLCubeMap(size: size)
        iblCache[tier] = images
        return images
    }

    private static func cachedBackground(for tier: RenderTier, size: Int) -> [UIImage] {
        if let cached = backgroundCache[tier] { return cached }
        let images = generateBackgroundCubeMap(size: size)
        backgroundCache[tier] = images
        return images
    }

    static func switchPreset(_ preset: EnvironmentPreset, scene: SCNScene) {
        switch preset {
        case .training:
            scene.lightingEnvironment.contents = generateIBLCubeMap(size: 512)
            scene.lightingEnvironment.intensity = 0.88
            scene.background.contents = generateBackgroundCubeMap(size: 512)
        case .dark:
            scene.lightingEnvironment.contents = generateIBLCubeMap(size: 256, brightness: 0.6)
            scene.lightingEnvironment.intensity = 0.5
            scene.background.contents = generateBackgroundCubeMap(size: 256, brightness: 0.6)
        case .bright:
            scene.lightingEnvironment.contents = generateIBLCubeMap(size: 256, brightness: 1.3)
            scene.lightingEnvironment.intensity = 0.85
            scene.background.contents = generateBackgroundCubeMap(size: 256, brightness: 1.3)
        }
    }

    enum EnvironmentPreset { case training, dark, bright }

    // MARK: - Debug IBL Mode (toggle for visual verification)

    enum DebugIBLMode {
        case normal
        case showTopFaceOnly   // wall/floor → mid-gray, isolate ceiling contribution
        case exaggerated       // lamp intensity ×1.5 for verifying strip shape
    }
    private static var debugIBLMode: DebugIBLMode = .normal

    // MARK: - Color Anchors (B > G > R, cold consistent)

    private static let C0 = SIMD3<Float>(0.030, 0.040, 0.060) // ceiling / top
    private static let C1 = SIMD3<Float>(0.050, 0.060, 0.080) // wall mid-peak
    private static let C2 = SIMD3<Float>(0.040, 0.050, 0.070) // horizon band
    private static let F0 = SIMD3<Float>(0.032, 0.034, 0.044) // floor base
    private static let F1 = SIMD3<Float>(0.030, 0.030, 0.040) // floor near camera

    private static let y0: Float = 1.00
    private static let y1: Float = 0.70
    private static let y2: Float = 0.36
    private static let y3: Float = 0.16
    private static let y4: Float = 0.00

    // MARK: - Interpolation (C1-continuous)

    private static func smootherstep(_ a: Float, _ b: Float, _ x: Float) -> Float {
        let t = max(0, min(1, (x - a) / (b - a)))
        return t * t * t * (t * (t * 6 - 15) + 10)
    }

    private static func lerp3(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ t: Float) -> SIMD3<Float> {
        a + (b - a) * t
    }

    /// Sample the background color at normalized height y ∈ [0, 1]
    private static func backgroundColor(y: Float, brightness: Float = 1.0) -> SIMD3<Float> {
        let color: SIMD3<Float>
        if y >= y1 {
            let t = smootherstep(y1, y0, y)
            color = lerp3(C1, C0, t)
        } else if y >= y2 {
            let t = smootherstep(y2, y1, y)
            color = lerp3(C2, C1, t)
        } else if y >= y3 {
            let t = smootherstep(y3, y2, y)
            color = lerp3(F0, C2, t)
        } else {
            let t = smootherstep(y4, y3, y)
            color = lerp3(F1, F0, t)
        }
        return color * brightness
    }

    // MARK: - Background Cube Map (smootherstep gradient)

    static func generateBackgroundCubeMap(size: Int, brightness: Float = 1.0) -> [UIImage] {
        let s = size

        // Wall faces: full vertical gradient from C0 (top) to F1 (bottom)
        let wall = renderGradientFace(size: s, brightness: brightness)

        // Ceiling: solid C0
        let ceilColor = C0 * brightness
        let ceiling = renderSolidFace(size: s, color: ceilColor)

        // Floor: solid F1
        let floorColor = F1 * brightness
        let floor = renderSolidFace(size: s, color: floorColor)

        // +X, -X, +Y, -Y, +Z, -Z
        return [wall, wall, ceiling, floor, wall, wall]
    }

    /// Render a wall face with the full smootherstep vertical gradient
    private static func renderGradientFace(size s: Int, brightness: Float) -> UIImage {
        var pixels = [UInt8](repeating: 0, count: s * s * 4)

        for row in 0..<s {
            let y = 1.0 - Float(row) / Float(s - 1) // top of image = y=1
            let c = backgroundColor(y: y, brightness: brightness)

            let r = UInt8(clamping: Int(min(c.x, 1.0) * 255))
            let g = UInt8(clamping: Int(min(c.y, 1.0) * 255))
            let b = UInt8(clamping: Int(min(c.z, 1.0) * 255))

            for col in 0..<s {
                let idx = (row * s + col) * 4
                pixels[idx + 0] = r
                pixels[idx + 1] = g
                pixels[idx + 2] = b
                pixels[idx + 3] = 255
            }
        }

        return imageFromRGBA(pixels: pixels, width: s, height: s)
    }

    /// Render a solid-color face
    private static func renderSolidFace(size s: Int, color: SIMD3<Float>) -> UIImage {
        var pixels = [UInt8](repeating: 0, count: s * s * 4)
        let r = UInt8(clamping: Int(min(color.x, 1.0) * 255))
        let g = UInt8(clamping: Int(min(color.y, 1.0) * 255))
        let b = UInt8(clamping: Int(min(color.z, 1.0) * 255))

        for i in 0..<(s * s) {
            let idx = i * 4
            pixels[idx + 0] = r
            pixels[idx + 1] = g
            pixels[idx + 2] = b
            pixels[idx + 3] = 255
        }

        return imageFromRGBA(pixels: pixels, width: s, height: s)
    }

    // MARK: - IBL Helpers (SDF + smoothstep)

    /// Standard smoothstep (Hermite interpolation with clamped t).
    private static func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        let t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }

    /// Signed distance from point (px, py) to a rounded-rectangle centered at (cx, cy)
    /// with half-extents (hw, hh) and corner radius r.
    /// Returns negative inside, 0 on boundary, positive outside.
    private static func roundedRectSDF(px: Float, py: Float,
                                       cx: Float, cy: Float,
                                       hw: Float, hh: Float,
                                       r: Float) -> Float {
        let dx = max(abs(px - cx) - hw + r, 0)
        let dy = max(abs(py - cy) - hh + r, 0)
        return sqrt(dx * dx + dy * dy) - r
    }

    // MARK: - IBL Cube Map (neutral, clean reflections)

    static func generateIBLCubeMap(size: Int, brightness: Float = 1.0) -> [UIImage] {
        let s = size
        let b = brightness

        let ceiling = renderIBLCeiling(size: s, b: b)

        let wall: UIImage
        let floor: UIImage
        if debugIBLMode == .showTopFaceOnly {
            let debugGray = SIMD3<Float>(0.30, 0.30, 0.30) * b
            wall  = renderSolidFace(size: s, color: debugGray)
            floor = renderSolidFace(size: s, color: debugGray)
        } else {
            let wallTop = SIMD3<Float>(0.20, 0.21, 0.24) * b
            let wallBot = SIMD3<Float>(0.10, 0.10, 0.12) * b
            wall  = renderIBLWall(size: s, top: wallTop, bot: wallBot)
            floor = renderSolidFace(size: s, color: SIMD3<Float>(0.06, 0.07, 0.08) * b)
        }

        return [wall, wall, ceiling, floor, wall, wall]
    }

    private static func renderIBLWall(size s: Int, top: SIMD3<Float>, bot: SIMD3<Float>) -> UIImage {
        var pixels = [UInt8](repeating: 0, count: s * s * 4)
        for row in 0..<s {
            let t = Float(row) / Float(s - 1)
            let c = lerp3(top, bot, t)
            let r = UInt8(clamping: Int(min(c.x, 1.0) * 255))
            let g = UInt8(clamping: Int(min(c.y, 1.0) * 255))
            let b = UInt8(clamping: Int(min(c.z, 1.0) * 255))
            for col in 0..<s {
                let idx = (row * s + col) * 4
                pixels[idx + 0] = r
                pixels[idx + 1] = g
                pixels[idx + 2] = b
                pixels[idx + 3] = 255
            }
        }
        return imageFromRGBA(pixels: pixels, width: s, height: s)
    }

    /// Triple-strip softbox ceiling: 3 capsule lamps + diffusion halos + ceiling bounce.
    /// All geometry computed in UV space [0,1]. Parameters extracted as locals for easy tuning.
    private static func renderIBLCeiling(size s: Int, b: Float) -> UIImage {

        // ── Tunable parameters (UV space) ──────────────────────────────
        let ceilingBase   = SIMD3<Float>(0.10, 0.11, 0.13) * b

        // Lamp strips (3 capsules)
        let lampW: Float  = 0.72
        let lampH: Float  = 0.10
        let lampR: Float  = lampH * 0.5
        let lampOffsets: [Float] = [-0.12, 0.0, 0.12]  // y-offsets from center
        let lampColor     = SIMD3<Float>(0.86, 0.84, 0.80) * b

        // Core hot-line inside each lamp
        let coreH: Float  = lampH * 0.35
        let coreR: Float  = coreH * 0.5
        let coreColor     = SIMD3<Float>(0.98, 0.96, 0.92) * b

        // Smoothstep feather width (UV units)
        let feather: Float = 0.015

        // Diffusion halo around each lamp
        let haloWScale: Float = 1.10
        let haloHScale: Float = 1.80
        let haloW: Float  = lampW * haloWScale
        let haloH: Float  = lampH * haloHScale
        let haloR: Float  = min(haloW, haloH) * 0.5
        let haloFeather: Float = 0.04
        let haloIntensity: Float = 0.14

        // Ceiling bounce (large soft ellipse)
        let bounceRx: Float = 0.55
        let bounceRy: Float = 0.40
        let bounceIntensity: Float = 0.08
        let bounceColor   = lerp3(ceilingBase, lampColor, 0.3)

        // Debug: exaggerated mode multiplier
        let exaggerate: Float = (debugIBLMode == .exaggerated) ? 1.5 : 1.0

        // ── Pixel generation ───────────────────────────────────────────
        var pixels = [UInt8](repeating: 0, count: s * s * 4)
        let invS = 1.0 / Float(s)

        for row in 0..<s {
            let v = (Float(row) + 0.5) * invS   // UV y ∈ [0,1]
            for col in 0..<s {
                let u = (Float(col) + 0.5) * invS   // UV x ∈ [0,1]

                // Layer 0: ceiling base
                var color = ceilingBase

                // Layer 1: ceiling bounce (low-frequency warm uplighting)
                let bdu = (u - 0.5) / bounceRx
                let bdv = (v - 0.5) / bounceRy
                let bDist = sqrt(bdu * bdu + bdv * bdv)
                let bAlpha = 1.0 - smoothstep(0.0, 1.0, bDist)
                color = color + bounceColor * (bAlpha * bounceIntensity)

                // Layer 2 + 3: per-lamp halo, body, and core
                for offset in lampOffsets {
                    let cy: Float = 0.5 + offset

                    // Halo (diffusion envelope, wider feather)
                    let haloDist = roundedRectSDF(px: u, py: v,
                                                  cx: 0.5, cy: cy,
                                                  hw: haloW * 0.5, hh: haloH * 0.5,
                                                  r: haloR)
                    let haloAlpha = 1.0 - smoothstep(0, haloFeather, haloDist)
                    color = color + lampColor * (haloAlpha * haloIntensity * exaggerate)

                    // Lamp body
                    let lampDist = roundedRectSDF(px: u, py: v,
                                                  cx: 0.5, cy: cy,
                                                  hw: lampW * 0.5, hh: lampH * 0.5,
                                                  r: lampR)
                    let lampAlpha = 1.0 - smoothstep(0, feather, lampDist)
                    color = color + lampColor * (lampAlpha * exaggerate)

                    // Core strip (bright tube center)
                    let coreDist = roundedRectSDF(px: u, py: v,
                                                  cx: 0.5, cy: cy,
                                                  hw: lampW * 0.5, hh: coreH * 0.5,
                                                  r: coreR)
                    let coreAlpha = 1.0 - smoothstep(0, feather, coreDist)
                    let coreAdd = coreColor - lampColor
                    color = color + coreAdd * (coreAlpha * exaggerate)
                }

                // Clamp & write
                let idx = (row * s + col) * 4
                pixels[idx]     = UInt8(clamping: Int(min(color.x, 1.0) * 255))
                pixels[idx + 1] = UInt8(clamping: Int(min(color.y, 1.0) * 255))
                pixels[idx + 2] = UInt8(clamping: Int(min(color.z, 1.0) * 255))
                pixels[idx + 3] = 255
            }
        }

        return imageFromRGBA(pixels: pixels, width: s, height: s)
    }

    // MARK: - Pixel Buffer → UIImage

    private static func imageFromRGBA(pixels: [UInt8], width: Int, height: Int) -> UIImage {
        let data = Data(pixels)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: data as CFData),
              let cgImage = CGImage(
                width: width, height: height,
                bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil, shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            return UIImage()
        }
        return UIImage(cgImage: cgImage)
    }
}
