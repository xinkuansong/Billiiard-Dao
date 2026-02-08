//
//  PowerGaugeView.swift
//  BilliardTrainer
//
//  力度指示条 - 竖直渐变色条显示蓄力力度
//

import SwiftUI

/// 力度指示条视图
struct PowerGaugeView: View {
    
    /// 当前力度 (0-1)
    let power: Float
    
    /// 是否正在蓄力
    let isCharging: Bool
    
    /// 控件高度
    private let gaugeHeight: CGFloat = 200
    
    /// 控件宽度
    private let gaugeWidth: CGFloat = 20
    
    /// 力度描述
    private var powerLabel: String {
        switch power {
        case 0..<0.25:
            return "轻"
        case 0.25..<0.5:
            return "中"
        case 0.5..<0.75:
            return "重"
        case 0.75...1.0:
            return "发力"
        default:
            return ""
        }
    }
    
    /// 力度颜色
    private var powerColor: Color {
        if power < 0.25 {
            return .green
        } else if power < 0.5 {
            return .yellow
        } else if power < 0.75 {
            return .orange
        } else {
            return .red
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            // 刻度标记
            VStack(spacing: 0) {
                Text("发力")
                    .font(.system(size: 8))
                Spacer()
                Text("重")
                    .font(.system(size: 8))
                Spacer()
                Text("中")
                    .font(.system(size: 8))
                Spacer()
                Text("轻")
                    .font(.system(size: 8))
            }
            .foregroundColor(.white.opacity(0.6))
            .frame(height: gaugeHeight)
            
            // 力度条
            ZStack(alignment: .bottom) {
                // 背景条
                RoundedRectangle(cornerRadius: gaugeWidth / 2)
                    .fill(.ultraThinMaterial)
                    .frame(width: gaugeWidth, height: gaugeHeight)
                
                // 渐变背景（始终显示的刻度底色）
                RoundedRectangle(cornerRadius: gaugeWidth / 2)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.green, .yellow, .orange, .red]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: gaugeWidth, height: gaugeHeight)
                    .opacity(0.15)
                
                // 填充条（实际力度）
                if isCharging {
                    RoundedRectangle(cornerRadius: gaugeWidth / 2)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.green, .yellow, .orange, .red]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(
                            width: gaugeWidth,
                            height: gaugeHeight * CGFloat(power)
                        )
                        .animation(.linear(duration: 0.05), value: power)
                }
                
                // 刻度线
                VStack(spacing: 0) {
                    ForEach(0..<4) { i in
                        if i > 0 {
                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: gaugeWidth + 4, height: 1)
                        }
                        Spacer()
                    }
                }
                .frame(width: gaugeWidth + 4, height: gaugeHeight)
            }
            
            // 百分比数字
            if isCharging {
                VStack {
                    Spacer()
                    Text("\(Int(power * 100))%")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(powerColor)
                        .frame(width: 36)
                    
                    Text(powerLabel)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 36)
                }
                .frame(height: gaugeHeight)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        HStack(spacing: 40) {
            PowerGaugeView(power: 0, isCharging: false)
            PowerGaugeView(power: 0.3, isCharging: true)
            PowerGaugeView(power: 0.7, isCharging: true)
            PowerGaugeView(power: 1.0, isCharging: true)
        }
    }
}
