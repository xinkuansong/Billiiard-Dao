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

    // MARK: - Public API

    static func apply(to scene: SCNScene, tier: RenderTier) {
        let flags = RenderQualityManager.shared.featureFlags

        if flags.hdriEnabled,
           let hdrURL = Bundle.main.url(forResource: "billiard_hall", withExtension: "hdr") {
            scene.lightingEnvironment.contents = hdrURL
            scene.lightingEnvironment.intensity = 0.88
            scene.lightingEnvironment.contentsTransform = SCNMatrix4MakeRotation(.pi * 0.25, 0, 1, 0)
            scene.background.contents = generateBackgroundCubeMap(size: 256)
            return
        }

        let mapSize = max(256, flags.environmentMapSize)
        scene.lightingEnvironment.contents = generateIBLCubeMap(size: mapSize)
        scene.lightingEnvironment.intensity = 0.88
        scene.background.contents = generateBackgroundCubeMap(size: mapSize)
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

    // MARK: - Color Anchors (B > G > R, cold consistent)

    private static let C0 = SIMD3<Float>(0.028, 0.036, 0.055) // ceiling / top
    private static let C1 = SIMD3<Float>(0.050, 0.064, 0.090) // wall mid-peak
    private static let C2 = SIMD3<Float>(0.040, 0.052, 0.076) // horizon band
    private static let F0 = SIMD3<Float>(0.032, 0.042, 0.062) // floor base
    private static let F1 = SIMD3<Float>(0.026, 0.034, 0.050) // floor near camera

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

    // MARK: - IBL Cube Map (neutral, clean reflections)

    static func generateIBLCubeMap(size: Int, brightness: Float = 1.0) -> [UIImage] {
        let s = size
        let b = brightness

        let wallTop = SIMD3<Float>(0.15, 0.16, 0.18) * b
        let wallBot = SIMD3<Float>(0.07, 0.07, 0.08) * b

        let wall = renderIBLWall(size: s, top: wallTop, bot: wallBot)
        let ceiling = renderIBLCeiling(size: s, b: b)
        let floor = renderSolidFace(size: s, color: SIMD3<Float>(0.045, 0.052, 0.06) * b)

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

    private static func renderIBLCeiling(size s: Int, b: Float) -> UIImage {
        let base = SIMD3<Float>(0.06, 0.065, 0.08) * b
        var pixels = [UInt8](repeating: 0, count: s * s * 4)

        // Base fill
        let br = UInt8(clamping: Int(min(base.x, 1.0) * 255))
        let bg = UInt8(clamping: Int(min(base.y, 1.0) * 255))
        let bb = UInt8(clamping: Int(min(base.z, 1.0) * 255))
        for i in 0..<(s * s) {
            let idx = i * 4
            pixels[idx] = br; pixels[idx+1] = bg; pixels[idx+2] = bb; pixels[idx+3] = 255
        }

        // Lamp ellipse — smaller & dimmer to avoid broad gray film on balls
        let cx = Float(s) * 0.5, cy = Float(s) * 0.5
        let rx = Float(s) * 0.18, ry = Float(s) * 0.12
        let lamp = SIMD3<Float>(min(1.0, 0.60 * b), min(1.0, 0.58 * b), min(1.0, 0.55 * b))
        let core = SIMD3<Float>(min(1.0, 0.72 * b), min(1.0, 0.70 * b), min(1.0, 0.68 * b))

        for row in 0..<s {
            for col in 0..<s {
                let dx = (Float(col) - cx) / rx
                let dy = (Float(row) - cy) / ry
                let d2 = dx * dx + dy * dy
                if d2 < 1.0 {
                    let idx = (row * s + col) * 4
                    let c = d2 < 0.3 ? core : lamp
                    pixels[idx] = UInt8(clamping: Int(min(c.x, 1.0) * 255))
                    pixels[idx+1] = UInt8(clamping: Int(min(c.y, 1.0) * 255))
                    pixels[idx+2] = UInt8(clamping: Int(min(c.z, 1.0) * 255))
                }
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
