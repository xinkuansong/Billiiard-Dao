//
//  MaterialFactory.swift
//  BilliardTrainer
//
//  统一 PBR 材质工厂：球体、台呢、木边、袋口
//  只使用 SceneKit 原生属性，不使用 shaderModifiers，确保兼容性
//

import SceneKit
import UIKit

final class MaterialFactory {

    // MARK: - Texture Cache (pure functions of size, safe to cache indefinitely)

    private static var feltNormalMapCache: [Int: UIImage] = [:]
    private static var woodNormalMapCache: [Int: UIImage] = [:]

    // MARK: - Normal Intensity Constants

    /// USDZ 自带法线贴图时不主动修改强度（intensity 保持模型原始值，此常量仅作文档用）
    private static let normalIntensityUSDZCloth: CGFloat        = 1.0
    /// USDZ 自带法线贴图时显式覆盖强度（消除悬浮感的微结构增强）
    private static let normalIntensityUSDZClothOverride: CGFloat = 1.2
    /// 程序化 felt 法线兜底强度（比 USDZ 原始法线弱，避免过度凹凸）
    private static let normalIntensityFeltFallback: CGFloat = 0.055
    /// USDZ 自带木纹法线时不主动修改强度（intensity 保持模型原始值，此常量仅作文档用）
    private static let normalIntensityUSDZWood: CGFloat    = 1.0
    /// 程序化木纹法线兜底强度
    private static let normalIntensityWoodFallback: CGFloat = 0.35

    // MARK: - Roughness Override Constants

    /// 台布 USDZ roughness 贴图存在时，叠加一个标量 multiply 来整体降低光泽度
    private static let roughnessUSDZClothOverride: CGFloat = 0.88

    static func cachedFeltNormalMap(size: Int) -> UIImage {
        if let cached = feltNormalMapCache[size] { return cached }
        let image = generateFeltNormalMap(size: size)
        feltNormalMapCache[size] = image
        return image
    }

    static func cachedWoodGrainNormalMap(size: Int) -> UIImage {
        if let cached = woodNormalMapCache[size] { return cached }
        let image = generateWoodGrainNormalMap(size: size)
        woodNormalMapCache[size] = image
        return image
    }

    // MARK: - Ball Material (PBR + ClearCoat)

    /// Enhance ball materials: ultra-low roughness + clearcoat shader.
    /// Preserves original diffuse textures from the USDZ model.
    static func applyBallMaterial(to node: SCNNode) {
        let useClearcoat = RenderQualityManager.shared.isEnabled(.clearcoatFresnel)
        applyBallMaterialRecursive(node, clearcoat: useClearcoat)
    }

    private static func applyBallMaterialRecursive(_ node: SCNNode, clearcoat: Bool) {
        if let geometry = node.geometry {
            for material in geometry.materials {
                material.lightingModel = .physicallyBased
                material.roughness.contents = Float(0.045)
                material.metalness.contents = Float(0.0)

                // Remove any USDZ normal map — real billiard balls are perfectly smooth
                material.normal.contents = nil
                material.normal.intensity = 0

                if clearcoat {
                    material.shaderModifiers = [.fragment: clearcoatFragmentShader]
                } else {
                    material.shaderModifiers = nil
                }
            }
        }
        for child in node.childNodes {
            applyBallMaterialRecursive(child, clearcoat: clearcoat)
        }
    }

    /// Minimal ClearCoat fragment shader — no #pragma, no uniforms.
    /// Adds a Schlick Fresnel specular layer on top of PBR output,
    /// simulating the hard polyester clearcoat on real billiard balls.
    /// ClearCoat = 1.0, clearCoatRoughness ≈ 0.01
    /// Tight specular lobe on top of PBR base, strong Fresnel edge.
    private static let clearcoatFragmentShader = """
    float3 n = normalize(_surface.normal);
    float3 v = normalize(-_surface.position);
    float NdotV = saturate(dot(n, v));
    float ccF0 = 0.04;
    float fresnel = ccF0 + (1.0 - ccF0) * pow(1.0 - NdotV, 5.0);
    _output.color.rgb = _output.color.rgb * (1.0 - fresnel * 0.30) + float3(fresnel * 0.22);
    """

    // MARK: - Cloth / Felt Material

    /// Enhance table cloth (felt) material found in a USDZ model node tree.
    /// Uses both node name heuristics AND material name / diffuse color sampling.
    ///
    /// Strategy:
    /// - lightingModel / roughness / metalness are always set (safe PBR defaults).
    /// - normal: if the USDZ already provides a texture, keep it and do NOT replace the
    ///   contents; only apply a fallback procedural normal when none is present.
    /// - roughness / metalness: if the USDZ already baked a texture into the channel,
    ///   keep it; only write a scalar default when the channel has no texture.
    static func enhanceClothMaterials(in tableNode: SCNNode) {
        let useClothNormal = RenderQualityManager.shared.isEnabled(.clothNormal)
        let normalMap = useClothNormal ? cachedFeltNormalMap(size: 512) : nil
        var enhanced = 0

        enumerateMaterials(in: tableNode) { material, nodeName in
            guard isClothMaterial(material, nodeName: nodeName) else { return }

            #if DEBUG
            debugLogMaterialSnapshot(material, nodeName: nodeName, tag: "BEFORE cloth enhance")
            #endif

            material.lightingModel = .physicallyBased

            // --- roughness ---
            // When USDZ provides a roughness texture, override with a scalar to reduce cloth shininess.
            // When no texture is present, use the fallback scalar.
            let roughnessSource: String
            if hasTextureContents(material.roughness.contents) {
                material.roughness.contents = Float(roughnessUSDZClothOverride)
                roughnessSource = "override(\(roughnessUSDZClothOverride))"
            } else {
                material.roughness.contents = Float(0.89)
                roughnessSource = "default(0.89)"
            }

            // --- metalness ---
            let metalnessSource: String
            if !hasTextureContents(material.metalness.contents) {
                material.metalness.contents = Float(0.0)
                metalnessSource = "default(0.0)"
            } else {
                metalnessSource = "USDZ texture"
            }

            // --- normal ---
            // If USDZ already provides a normal texture, keep it untouched (contents + intensity).
            // Only install the procedural fallback when no texture is present.
            let normalSource: String
            if hasTextureContents(material.normal.contents) {
                // USDZ-sourced normal: keep contents, override intensity for controlled micro-structure.
                material.normal.intensity = normalIntensityUSDZClothOverride
                normalSource = "USDZ texture(intensity=\(normalIntensityUSDZClothOverride))"
            } else if let normalMap {
                material.normal.contents = normalMap
                material.normal.intensity = normalIntensityFeltFallback
                material.normal.wrapS = .repeat
                material.normal.wrapT = .repeat
                material.normal.contentsTransform = SCNMatrix4MakeScale(14, 14, 1)
                normalSource = "generated(felt, intensity=\(normalIntensityFeltFallback))"
            } else {
                material.normal.contents = nil
                material.normal.intensity = 0
                normalSource = "none(quality disabled)"
            }

            // Slightly desaturate / darken diffuse (~8%).
            // Always use the multiply channel so the adjustment is idempotent across
            // multiple reapplyMaterialsAndEnvironment calls — writing directly to
            // diffuse.contents would compound the darkening each call.
            if material.diffuse.contents is UIColor || extractImage(from: material.diffuse.contents) != nil {
                material.multiply.contents = UIColor(red: 0.90, green: 0.93, blue: 0.90, alpha: 1.0)
            }

            #if DEBUG
            debugLogEnhanceSummary(material, nodeName: nodeName,
                                   normalSource: normalSource,
                                   roughnessSource: roughnessSource,
                                   metalnessSource: metalnessSource)
            #endif

            enhanced += 1
        }
        print("[MaterialFactory] 🎱 台呢材质增强: \(enhanced) 个材质")
    }

    /// Detect cloth/felt material by node name, material name, or diffuse color analysis.
    private static func isClothMaterial(_ material: SCNMaterial, nodeName: String?) -> Bool {
        let nName = normalizeIdentifier(nodeName ?? "")
        let mName = normalizeIdentifier(material.name ?? "")
        let combined = nName + " " + mName

        // Name-based detection — identifiers are normalized (lowercased, stripped of _/-/spaces)
        // so TaiNi / tai_ni / tai-ni / taini all collapse to "taini"
        let clothKeywords = ["cloth", "felt", "surface", "taibu", "taini",
                             "泥", "布", "green", "baize", "playing"]
        for keyword in clothKeywords {
            if combined.contains(keyword) { return true }
        }

        // Color-based detection — works for UIColor diffuse
        if let color = material.diffuse.contents as? UIColor {
            return isGreenish(color)
        }

        // Texture-based detection — sample the diffuse texture for dominant green
        if let image = extractImage(from: material.diffuse.contents) {
            return isGreenishImage(image)
        }

        return false
    }

    /// Normalize an identifier for fuzzy keyword matching:
    /// lowercased and strips underscores, hyphens, and spaces.
    /// e.g. "TaiNi" → "taini", "tai_ni" → "taini", "White-Wood" → "whitewood"
    private static func normalizeIdentifier(_ s: String) -> String {
        s.lowercased()
         .replacingOccurrences(of: "_", with: "")
         .replacingOccurrences(of: "-", with: "")
         .replacingOccurrences(of: " ", with: "")
    }

    /// Sample image pixels to check if the dominant color is green (table cloth).
    private static func isGreenishImage(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        let width = min(cgImage.width, 32)
        let height = min(cgImage.height, 32)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixelData,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var totalR: Int = 0, totalG: Int = 0, totalB: Int = 0
        let count = width * height
        for i in 0..<count {
            totalR += Int(pixelData[i * 4])
            totalG += Int(pixelData[i * 4 + 1])
            totalB += Int(pixelData[i * 4 + 2])
        }
        let avgR = Float(totalR) / Float(count)
        let avgG = Float(totalG) / Float(count)
        let avgB = Float(totalB) / Float(count)

        // Green is dominant and significant
        return avgG > 60 && avgG > avgR * 1.2 && avgG > avgB * 1.1
    }

    private static func isGreenish(_ color: UIColor) -> Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: nil)
        return g > 0.2 && g > r && g > b * 0.8
    }

    /// Extract UIImage from various SCNMaterialProperty content types.
    private static func extractImage(from contents: Any?) -> UIImage? {
        if let image = contents as? UIImage { return image }
        // CGImage from USDZ textures
        let obj = contents as AnyObject
        if CFGetTypeID(obj) == CGImage.typeID {
            return UIImage(cgImage: obj as! CGImage)
        }
        return nil
    }

    /// Returns true when a SCNMaterialProperty.contents value represents an actual texture
    /// (CGImage, UIImage, or URL), as opposed to a plain color or scalar.
    ///
    /// Use this instead of a bare `!= nil` check to avoid mistaking a UIColor or Float
    /// contents value for a baked texture.
    private static func hasTextureContents(_ contents: Any?) -> Bool {
        guard let contents else { return false }
        if contents is UIImage { return true }
        if contents is URL     { return true }
        let obj = contents as AnyObject
        if CFGetTypeID(obj) == CGImage.typeID { return true }
        return false
    }

    // MARK: - Rail / Wood Material

    /// Enhance wood rail materials with low roughness.
    ///
    /// Strategy mirrors enhanceClothMaterials:
    /// - roughness: keep USDZ texture if present; write scalar 0.30 only as fallback.
    /// - normal: keep USDZ texture if present; install procedural wood grain only as fallback.
    static func enhanceRailMaterials(in tableNode: SCNNode) {
        let qm = RenderQualityManager.shared
        guard qm.isEnabled(.railClearcoat) else { return }

        let woodNormal = cachedWoodGrainNormalMap(size: 256)

        enumerateMaterials(in: tableNode) { material, nodeName in
            guard isRailMaterial(material, nodeName: nodeName) else { return }

            #if DEBUG
            debugLogMaterialSnapshot(material, nodeName: nodeName, tag: "BEFORE rail enhance")
            #endif

            material.lightingModel = .physicallyBased

            // --- roughness ---
            let roughnessSource: String
            if !hasTextureContents(material.roughness.contents) {
                material.roughness.contents = Float(0.30)
                roughnessSource = "default(0.30)"
            } else {
                roughnessSource = "USDZ texture"
            }

            // --- metalness ---
            let metalnessSource: String
            if !hasTextureContents(material.metalness.contents) {
                material.metalness.contents = Float(0.0)
                metalnessSource = "default(0.0)"
            } else {
                metalnessSource = "USDZ texture"
            }

            // --- normal ---
            let normalSource: String
            if hasTextureContents(material.normal.contents) {
                // USDZ-sourced normal: leave contents and intensity untouched.
                normalSource = "USDZ texture"
            } else {
                material.normal.contents = woodNormal
                material.normal.intensity = normalIntensityWoodFallback
                material.normal.wrapS = .repeat
                material.normal.wrapT = .repeat
                material.normal.contentsTransform = SCNMatrix4MakeScale(4, 4, 1)
                normalSource = "generated(wood grain, intensity=\(normalIntensityWoodFallback))"
            }

            #if DEBUG
            debugLogEnhanceSummary(material, nodeName: nodeName,
                                   normalSource: normalSource,
                                   roughnessSource: roughnessSource,
                                   metalnessSource: metalnessSource)
            #endif
        }
    }

    private static func isRailMaterial(_ material: SCNMaterial, nodeName: String?) -> Bool {
        let nName = normalizeIdentifier(nodeName ?? "")
        let mName = normalizeIdentifier(material.name ?? "")
        let combined = nName + " " + mName

        if combined.contains("rail") || combined.contains("wood") || combined.contains("frame")
            || combined.contains("mu") || combined.contains("框") || combined.contains("边") {
            return true
        }

        // Color heuristic: warm brownish tone typical of wood grain.
        // Guard: exclude high-metalness materials (Gold, copp, MG_Gold, etc.) — they share
        // a similar warm color range but must NOT have their metalness reset to 0.
        if let color = material.diffuse.contents as? UIColor {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: nil)
            if r > 0.3 && r > b && g < r && g > 0.15 {
                // Reject if the material is already configured as a metal
                let metalVal = material.metalness.contents
                if let f = metalVal as? Float, f > 0.5 { return false }
                if let n = metalVal as? NSNumber, n.floatValue > 0.5 { return false }
                return true
            }
        }
        return false
    }

    // MARK: - Pocket Material

    /// Enhance pocket materials (leather feel).
    static func enhancePocketMaterials(in tableNode: SCNNode) {
        enumerateMaterials(in: tableNode) { material, nodeName in
            guard isPocketMaterial(material, nodeName: nodeName) else { return }
            material.lightingModel = .physicallyBased
            material.roughness.contents = Float(0.85)
            material.metalness.contents = Float(0.0)
        }
    }

    private static func isPocketMaterial(_ material: SCNMaterial, nodeName: String?) -> Bool {
        let nName = normalizeIdentifier(nodeName ?? "")
        let mName = normalizeIdentifier(material.name ?? "")
        let combined = nName + " " + mName
        if combined.contains("pocket") || combined.contains("dai") || combined.contains("袋") {
            return true
        }
        if let color = material.diffuse.contents as? UIColor {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: nil)
            if r < 0.1 && g < 0.1 && b < 0.1 { return true }
        }
        return false
    }

    // MARK: - Contact Shadow Texture

    /// Generate a soft radial-gradient contact shadow image.
    /// Uses a hard dark core + soft penumbra for realistic look.
    static func generateContactShadowTexture(size: Int = 128) -> UIImage {
        let s = size
        let half = Float(s) * 0.5
        let baseAlpha: Float = 0.62
        let exponent: Float = 2.2

        var pixels = [UInt8](repeating: 0, count: s * s * 4)
        for row in 0..<s {
            for col in 0..<s {
                let dx = (Float(col) + 0.5 - half) / half
                let dy = (Float(row) + 0.5 - half) / half
                let dist = min(1.0, sqrt(dx * dx + dy * dy))
                let alpha = baseAlpha * pow(max(0, 1.0 - dist), exponent)
                let a8 = UInt8(clamping: Int(alpha * 255))
                let idx = (row * s + col) * 4
                pixels[idx + 3] = a8
            }
        }

        return imageFromRGBA(pixels: pixels, width: s, height: s)
    }

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

    // MARK: - Procedural Normal Maps

    /// Generate a high-frequency fine fiber normal map for felt.
    /// Fine directional silk-like threads, not blobby noise.
    static func generateFeltNormalMap(size: Int) -> UIImage {
        let s = size
        var pixels = [UInt8](repeating: 128, count: s * s * 4)

        for y in 0..<s {
            for x in 0..<s {
                let idx = (y * s + x) * 4
                let nx = Float(x) / Float(s)
                let ny = Float(y) / Float(s)

                // High-freq directional fibers (mostly along one axis, with cross-weave)
                let warpFiber = sin(ny * 200.0 + fbm(x: nx * 60, y: ny * 20, octaves: 2) * 2.0)
                let weftFiber = sin(nx * 180.0 + fbm(x: nx * 20, y: ny * 60, octaves: 2) * 1.5) * 0.4
                let micro = fbm(x: nx * 120, y: ny * 120, octaves: 2)

                let dx = (warpFiber * 0.6 + weftFiber + micro * 0.3) * 18.0
                let dy = (warpFiber * 0.3 + weftFiber * 0.8 + micro * 0.3) * 18.0

                pixels[idx + 0] = UInt8(clamping: Int(128 + dx))
                pixels[idx + 1] = UInt8(clamping: Int(128 + dy))
                pixels[idx + 2] = 255
                pixels[idx + 3] = 255
            }
        }

        return imageFromRGBA(pixels: pixels, width: s, height: s)
    }

    /// Generate a procedural wood grain normal map.
    static func generateWoodGrainNormalMap(size: Int) -> UIImage {
        let s = size
        var pixels = [UInt8](repeating: 128, count: s * s * 4)

        for y in 0..<s {
            for x in 0..<s {
                let idx = (y * s + x) * 4
                let nx = Float(x) / Float(s)
                let ny = Float(y) / Float(s)
                let grain = sin(ny * 40.0 + fbm(x: nx * 8, y: ny * 8, octaves: 2) * 3.0) * 15.0
                pixels[idx + 0] = 128
                pixels[idx + 1] = UInt8(clamping: Int(128 + grain))
                pixels[idx + 2] = 255
                pixels[idx + 3] = 255
            }
        }

        return imageFromRGBA(pixels: pixels, width: s, height: s)
    }

    // MARK: - Debug Logging (DEBUG only)

#if DEBUG
    /// Returns a human-readable description of a SCNMaterialProperty.contents value,
    /// distinguishing between texture types and plain scalars/colors.
    private static func materialContentsDescription(_ contents: Any?) -> String {
        guard let contents else { return "nil" }
        if contents is UIImage  { return "UIImage(texture)" }
        if contents is URL      { return "URL(texture)" }
        let obj = contents as AnyObject
        if CFGetTypeID(obj) == CGImage.typeID { return "CGImage(texture)" }
        if let color = contents as? UIColor {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            return String(format: "UIColor(r:%.2f g:%.2f b:%.2f)", r, g, b)
        }
        if let f = contents as? Float  { return "Float(\(f))" }
        if let n = contents as? NSNumber { return "NSNumber(\(n))" }
        return "\(type(of: contents))"
    }

    /// Print a full channel snapshot for one material before any enhancement is applied.
    /// Call this at the top of each enhance* closure to capture the raw USDZ state.
    private static func debugLogMaterialSnapshot(
        _ material: SCNMaterial,
        nodeName: String?,
        tag: String
    ) {
        let node = nodeName ?? "-"
        let mat  = material.name ?? "-"
        print("[MaterialFactory] 📋 \(tag) node=\(node) material=\(mat)")
        print("[MaterialFactory]   diffuse   = \(materialContentsDescription(material.diffuse.contents))")
        print("[MaterialFactory]   normal    = \(materialContentsDescription(material.normal.contents))")
        print("[MaterialFactory]   roughness = \(materialContentsDescription(material.roughness.contents))")
        print("[MaterialFactory]   metalness = \(materialContentsDescription(material.metalness.contents))")
    }

    /// Print the final per-channel decision summary after enhancement is applied.
    private static func debugLogEnhanceSummary(
        _ material: SCNMaterial,
        nodeName: String?,
        normalSource: String,
        roughnessSource: String,
        metalnessSource: String
    ) {
        let node = nodeName ?? "-"
        let mat  = material.name ?? "-"
        let diff = hasTextureContents(material.diffuse.contents) ? "texture" : materialContentsDescription(material.diffuse.contents)
        print("[MaterialFactory] ✅ summary node=\(node) material=\(mat)")
        print("[MaterialFactory]   diffuse   = \(diff)")
        print("[MaterialFactory]   normal    = \(normalSource)")
        print("[MaterialFactory]   roughness = \(roughnessSource)")
        print("[MaterialFactory]   metalness = \(metalnessSource)")
    }

    /// Print all materials found in a node tree (raw USDZ inspection, no enhancement applied).
    static func debugPrintMaterials(in node: SCNNode, depth: Int = 0) {
        let indent = String(repeating: "  ", count: depth)
        if let geometry = node.geometry {
            for (i, mat) in geometry.materials.enumerated() {
                let diffuseDesc = materialContentsDescription(mat.diffuse.contents)
                let normalDesc  = materialContentsDescription(mat.normal.contents)
                let roughDesc   = materialContentsDescription(mat.roughness.contents)
                let metalDesc   = materialContentsDescription(mat.metalness.contents)
                print("\(indent)[MaterialFactory] 🔍 [\(node.name ?? "?")] mat[\(i)] name=\(mat.name ?? "?")")
                print("\(indent)  diffuse=\(diffuseDesc)  normal=\(normalDesc)  roughness=\(roughDesc)  metalness=\(metalDesc)")
            }
        }
        for child in node.childNodes {
            debugPrintMaterials(in: child, depth: depth + 1)
        }
    }
#endif

    // MARK: - Noise Helpers

    private static func hash2D(_ x: Int, _ y: Int) -> Float {
        var h = x &* 374761393 &+ y &* 668265263
        h = (h ^ (h >> 13)) &* 1274126177
        h = h ^ (h >> 16)
        return Float(h & 0x7FFFFFFF) / Float(0x7FFFFFFF)
    }

    private static func smoothNoise(x: Float, y: Float) -> Float {
        let ix = Int(floor(x))
        let iy = Int(floor(y))
        let fx = x - Float(ix)
        let fy = y - Float(iy)
        let sx = fx * fx * (3 - 2 * fx)
        let sy = fy * fy * (3 - 2 * fy)

        let n00 = hash2D(ix, iy)
        let n10 = hash2D(ix + 1, iy)
        let n01 = hash2D(ix, iy + 1)
        let n11 = hash2D(ix + 1, iy + 1)

        let nx0 = n00 + (n10 - n00) * sx
        let nx1 = n01 + (n11 - n01) * sx
        return nx0 + (nx1 - nx0) * sy
    }

    private static func fbm(x: Float, y: Float, octaves: Int) -> Float {
        var value: Float = 0
        var amplitude: Float = 1
        var frequency: Float = 1
        var maxAmp: Float = 0
        for _ in 0..<octaves {
            value += smoothNoise(x: x * frequency, y: y * frequency) * amplitude
            maxAmp += amplitude
            amplitude *= 0.5
            frequency *= 2
        }
        return value / maxAmp - 0.5
    }

    // MARK: - Material Enumeration

    private static func enumerateMaterials(in node: SCNNode, handler: (SCNMaterial, String?) -> Void) {
        if let geometry = node.geometry {
            for material in geometry.materials {
                handler(material, node.name)
            }
        }
        for child in node.childNodes {
            enumerateMaterials(in: child, handler: handler)
        }
    }
}
