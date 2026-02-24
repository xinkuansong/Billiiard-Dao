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
                material.roughness.contents = Float(0.033)
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
    static func enhanceClothMaterials(in tableNode: SCNNode) {
        let normalMap = generateFeltNormalMap(size: 512)
        var enhanced = 0

        enumerateMaterials(in: tableNode) { material, nodeName in
            guard isClothMaterial(material, nodeName: nodeName) else { return }

            material.lightingModel = .physicallyBased
            material.roughness.contents = Float(0.89)
            material.metalness.contents = Float(0.0)

            material.normal.contents = normalMap
            material.normal.intensity = 0.055
            material.normal.wrapS = .repeat
            material.normal.wrapT = .repeat
            material.normal.contentsTransform = SCNMatrix4MakeScale(14, 14, 1)

            // Darken ~8% + desaturate ~8% (remove fluorescent feel)
            if let color = material.diffuse.contents as? UIColor {
                var h: CGFloat = 0, s: CGFloat = 0, b_: CGFloat = 0, a: CGFloat = 0
                color.getHue(&h, saturation: &s, brightness: &b_, alpha: &a)
                material.diffuse.contents = UIColor(hue: h, saturation: s * 0.92, brightness: b_ * 0.92, alpha: a)
            } else if extractImage(from: material.diffuse.contents) != nil {
                material.multiply.contents = UIColor(red: 0.90, green: 0.93, blue: 0.90, alpha: 1.0)
            }

            enhanced += 1
        }
        print("[MaterialFactory] 🎱 台呢材质增强: \(enhanced) 个材质")
    }

    /// Detect cloth/felt material by node name, material name, or diffuse color analysis.
    private static func isClothMaterial(_ material: SCNMaterial, nodeName: String?) -> Bool {
        let nName = (nodeName ?? "").lowercased()
        let mName = (material.name ?? "").lowercased()
        let combined = nName + " " + mName

        // Name-based detection
        let clothKeywords = ["cloth", "felt", "surface", "taibu", "tai_ni",
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

    // MARK: - Rail / Wood Material

    /// Enhance wood rail materials with low roughness.
    static func enhanceRailMaterials(in tableNode: SCNNode) {
        let qm = RenderQualityManager.shared
        guard qm.isEnabled(.railClearcoat) else { return }

        let woodNormal = generateWoodGrainNormalMap(size: 256)

        enumerateMaterials(in: tableNode) { material, nodeName in
            guard isRailMaterial(material, nodeName: nodeName) else { return }

            material.lightingModel = .physicallyBased
            material.roughness.contents = Float(0.30)
            material.metalness.contents = Float(0.0)

            material.normal.contents = woodNormal
            material.normal.intensity = 0.35
            material.normal.wrapS = .repeat
            material.normal.wrapT = .repeat
            material.normal.contentsTransform = SCNMatrix4MakeScale(4, 4, 1)
        }
    }

    private static func isRailMaterial(_ material: SCNMaterial, nodeName: String?) -> Bool {
        let nName = (nodeName ?? "").lowercased()
        let mName = (material.name ?? "").lowercased()
        let combined = nName + " " + mName

        if combined.contains("rail") || combined.contains("wood") || combined.contains("frame")
            || combined.contains("mu") || combined.contains("框") || combined.contains("边") {
            return true
        }
        if let color = material.diffuse.contents as? UIColor {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: nil)
            if r > 0.3 && r > b && g < r && g > 0.15 { return true }
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
        let nName = (nodeName ?? "").lowercased()
        let mName = (material.name ?? "").lowercased()
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
        let baseAlpha: Float = 0.74
        let exponent: Float = 3.0

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

    // MARK: - Debug

    /// Print all materials found in a node tree (for USDZ inspection).
    static func debugPrintMaterials(in node: SCNNode, depth: Int = 0) {
        let indent = String(repeating: "  ", count: depth)
        if let geometry = node.geometry {
            for (i, mat) in geometry.materials.enumerated() {
                let diffuseType = mat.diffuse.contents.map { String(describing: type(of: $0)) } ?? "nil"
                print("\(indent)[\(node.name ?? "?")] mat[\(i)] name=\(mat.name ?? "?") diffuse=\(diffuseType)")
            }
        }
        for child in node.childNodes {
            debugPrintMaterials(in: child, depth: depth + 1)
        }
    }

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
