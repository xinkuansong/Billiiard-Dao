//
//  CuePointSelectorView.swift
//  BilliardTrainer
//
//  打点选择器 - 圆形母球截面 + 可拖动准心
//

import SwiftUI

/// 打点选择器视图
/// 显示母球截面，玩家拖动选择击球点位
struct CuePointSelectorView: View {
    
    /// 打点位置 (0,0)=左上 (1,1)=右下, (0.5,0.5)=中心
    @Binding var cuePoint: CGPoint
    
    /// 控件尺寸
    let size: CGFloat = 80
    
    /// 当前杆法描述
    private var spinLabel: String {
        let dx = cuePoint.x - 0.5
        let dy = cuePoint.y - 0.5
        let threshold: CGFloat = 0.15
        
        if abs(dx) < threshold && abs(dy) < threshold {
            return "中杆"
        }
        
        var labels: [String] = []
        if dy < -threshold { labels.append("高杆") }
        if dy > threshold { labels.append("低杆") }
        if dx < -threshold { labels.append("左塞") }
        if dx > threshold { labels.append("右塞") }
        
        return labels.joined(separator: "+")
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // 母球截面
            ZStack {
                // 白色球体背景
                Circle()
                    .fill(Color.white)
                    .frame(width: size, height: size)
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                
                // 十字准线
                CrosshairShape()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                    .frame(width: size - 10, height: size - 10)
                
                // 打点指示红点
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .shadow(color: .red.opacity(0.5), radius: 2)
                    .offset(
                        x: (cuePoint.x - 0.5) * (size - 16),
                        y: (cuePoint.y - 0.5) * (size - 16)
                    )
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // 将拖动位置映射到 0-1 范围
                        let center = CGPoint(x: size / 2, y: size / 2)
                        let dx = (value.location.x - center.x) / (size / 2)
                        let dy = (value.location.y - center.y) / (size / 2)
                        
                        // 限制在圆内
                        let distance = sqrt(dx * dx + dy * dy)
                        let clampedDistance = min(distance, 0.85)
                        let scale = distance > 0 ? clampedDistance / distance : 0
                        
                        cuePoint = CGPoint(
                            x: 0.5 + dx * scale / 2,
                            y: 0.5 + dy * scale / 2
                        )
                    }
            )
            
            // 杆法标签
            Text(spinLabel)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial)
                .cornerRadius(4)
        }
    }
}

// MARK: - Crosshair Shape

/// 十字准线形状
private struct CrosshairShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        
        // 水平线
        path.move(to: CGPoint(x: rect.minX, y: center.y))
        path.addLine(to: CGPoint(x: rect.maxX, y: center.y))
        
        // 垂直线
        path.move(to: CGPoint(x: center.x, y: rect.minY))
        path.addLine(to: CGPoint(x: center.x, y: rect.maxY))
        
        // 外圆
        path.addEllipse(in: rect)
        
        return path
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        CuePointSelectorView(cuePoint: .constant(CGPoint(x: 0.5, y: 0.3)))
    }
}
