//
//  PowerGaugeView.swift
//  BilliardTrainer
//
//  力度选择条 - 竖直滑条 0–100
//  点击定位 / 上下滑动 / 从底部拖拽，松手即出杆
//

import SwiftUI
import UIKit

// MARK: - PowerGaugeView

struct PowerGaugeView: View {
    
    @Binding var power: Float
    let enabled: Bool
    var onRelease: (() -> Void)?
    
    /// 本地显示值 — 直接驱动 Canvas 和文字刷新，不依赖 Binding 回传
    @State private var displayPower: Float = 0
    @State private var isTouching: Bool = false
    
    private let trackHeight: CGFloat = 220
    private let trackWidth: CGFloat = 38
    private let thumbDiameter: CGFloat = 36
    
    private var norm: CGFloat { CGFloat(min(max(displayPower, 0), 100) / 100) }
    
    private var label: String {
        switch displayPower {
        case ..<10:  return "轻推"
        case ..<30:  return "轻杆"
        case ..<55:  return "中杆"
        case ..<80:  return "重杆"
        default:     return "发力"
        }
    }
    
    private var accent: Color {
        switch displayPower {
        case ..<25:  return .green
        case ..<50:  return .yellow
        case ..<75:  return .orange
        default:     return .red
        }
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            // 左侧读数
            VStack(spacing: 2) {
                Text("\(Int(displayPower))")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundColor(isTouching ? accent : .white)
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }
            .frame(width: 38, alignment: .trailing)
            
            // 右侧滑条
            ZStack {
                Canvas { ctx, size in
                    drawTrack(ctx: ctx, size: size)
                }
                .allowsHitTesting(false)
                
                SliderTouchOverlay(
                    trackHeight: trackHeight,
                    enabled: enabled,
                    onValueChanged: { newPower, touching in
                        displayPower = newPower
                        power = newPower
                        isTouching = touching
                    },
                    onRelease: {
                        isTouching = false
                        onRelease?()
                    }
                )
            }
            .frame(width: trackWidth + 28, height: trackHeight)
        }
        .opacity(enabled ? 1.0 : 0.4)
        .onAppear { displayPower = power }
        .onChange(of: power) { _, newValue in
            if !isTouching { displayPower = newValue }
        }
    }
    
    // MARK: - Canvas Drawing
    
    private func drawTrack(ctx: GraphicsContext, size: CGSize) {
        let hw = trackWidth / 2
        let cx = size.width / 2
        
        let trackRect = CGRect(x: cx - hw, y: 0, width: trackWidth, height: trackHeight)
        let trackPath = Path(roundedRect: trackRect, cornerRadius: hw)
        ctx.fill(trackPath, with: .color(.black.opacity(0.55)))
        let bgGrad = Gradient(colors: [
            .red.opacity(0.2), .orange.opacity(0.2),
            .yellow.opacity(0.2), .green.opacity(0.2)
        ])
        ctx.fill(trackPath, with: .linearGradient(
            bgGrad, startPoint: .init(x: cx, y: 0), endPoint: .init(x: cx, y: trackHeight)
        ))
        ctx.stroke(trackPath, with: .color(.white.opacity(0.45)), lineWidth: 1.5)
        
        let fillH = trackHeight * norm
        if fillH > 1 {
            let fillRect = CGRect(x: cx - hw, y: trackHeight - fillH, width: trackWidth, height: fillH)
            let fillPath = Path(roundedRect: fillRect, cornerRadius: hw)
            let fillGrad = Gradient(colors: [.red, .orange, .yellow, .green])
            ctx.fill(fillPath, with: .linearGradient(
                fillGrad, startPoint: .init(x: cx, y: 0), endPoint: .init(x: cx, y: trackHeight)
            ))
        }
        
        for i in 1..<10 {
            let frac = CGFloat(i) / 10.0
            let y = trackHeight * (1.0 - frac)
            let isMajor = (i == 5)
            let tickW: CGFloat = isMajor ? trackWidth + 4 : trackWidth - 10
            let tickH: CGFloat = isMajor ? 1.5 : 1.0
            let alpha: CGFloat = isMajor ? 0.7 : 0.35
            let r = CGRect(x: cx - tickW / 2, y: y - tickH / 2, width: tickW, height: tickH)
            ctx.fill(Path(r), with: .color(.white.opacity(alpha)))
        }
        
        let ty = trackHeight * (1.0 - norm)
        let sr = (thumbDiameter / 2) * (isTouching ? 1.12 : 1.0)
        let thumbRect = CGRect(x: cx - sr, y: ty - sr, width: sr * 2, height: sr * 2)
        let thumbPath = Path(ellipseIn: thumbRect)
        ctx.fill(thumbPath, with: .color(accent))
        ctx.stroke(thumbPath, with: .color(.white), lineWidth: isTouching ? 3 : 2)
        if isTouching {
            ctx.fill(Path(ellipseIn: thumbRect.insetBy(dx: -5, dy: -5)),
                     with: .color(accent.opacity(0.25)))
        }
    }
}

// MARK: - UIKit Touch Overlay

private struct SliderTouchOverlay: UIViewRepresentable {
    let trackHeight: CGFloat
    let enabled: Bool
    var onValueChanged: ((_ power: Float, _ isTouching: Bool) -> Void)?
    var onRelease: (() -> Void)?
    
    func makeUIView(context: Context) -> _SliderTouchUIView {
        let view = _SliderTouchUIView()
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = false
        view.trackHeight = trackHeight
        view.onValueChanged = onValueChanged
        view.onRelease = onRelease
        view.isEnabled = enabled
        return view
    }
    
    func updateUIView(_ uiView: _SliderTouchUIView, context: Context) {
        uiView.trackHeight = trackHeight
        uiView.onValueChanged = onValueChanged
        uiView.onRelease = onRelease
        uiView.isEnabled = enabled
    }
}

private class _SliderTouchUIView: UIView {
    var trackHeight: CGFloat = 220
    var onValueChanged: ((_ power: Float, _ isTouching: Bool) -> Void)?
    var onRelease: (() -> Void)?
    var isEnabled: Bool = true
    
    private func powerFromTouch(_ touch: UITouch) -> Float {
        let y = touch.location(in: self).y
        let ratio = 1.0 - y / trackHeight
        return Float(min(max(ratio, 0), 1)) * 100
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isEnabled, let touch = touches.first else { return }
        onValueChanged?(powerFromTouch(touch), true)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isEnabled, let touch = touches.first else { return }
        onValueChanged?(powerFromTouch(touch), true)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isEnabled, let touch = touches.first else { return }
        onValueChanged?(powerFromTouch(touch), false)
        onRelease?()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        onValueChanged?(0, false)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(white: 0.1).ignoresSafeArea()
        HStack(spacing: 50) {
            PowerGaugeView(power: .constant(0), enabled: true)
            PowerGaugeView(power: .constant(50), enabled: true)
            PowerGaugeView(power: .constant(100), enabled: true)
        }
    }
}
