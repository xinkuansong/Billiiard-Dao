//
//  Extensions.swift
//  BilliardTrainer
//
//  通用扩展
//

import SwiftUI
import SceneKit

// MARK: - Color Extensions

extension Color {
    /// 台球绿（主色调）
    static let billiardGreen = Color(red: 0.0, green: 0.45, blue: 0.3)
    
    /// 台球深绿（库边）
    static let cushionGreen = Color(red: 0.0, green: 0.35, blue: 0.25)
    
    /// 木质颜色
    static let woodBrown = Color(red: 0.4, green: 0.26, blue: 0.13)
}

// MARK: - View Extensions

extension View {
    /// 卡片样式
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5)
    }
    
    /// 主按钮样式
    func primaryButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .cornerRadius(12)
    }
    
    /// 次按钮样式
    func secondaryButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundColor(.green)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
    }
}

// MARK: - Double Extensions

extension Double {
    /// 转为角度
    var degrees: Double {
        return self * 180 / .pi
    }
    
    /// 转为弧度
    var radians: Double {
        return self * .pi / 180
    }
    
    /// 格式化为百分比
    var percentageString: String {
        return String(format: "%.0f%%", self * 100)
    }
}

// MARK: - Float Extensions

extension Float {
    /// 转为角度
    var degrees: Float {
        return self * 180 / .pi
    }
    
    /// 转为弧度
    var radians: Float {
        return self * .pi / 180
    }
}

// MARK: - Date Extensions

extension Date {
    /// 是否是今天
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    /// 格式化日期
    func formatted(style: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: self)
    }
    
    /// 相对时间描述
    var relativeDescription: String {
        let now = Date()
        let interval = now.timeIntervalSince(self)
        
        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            return "\(Int(interval / 60))分钟前"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))小时前"
        } else if interval < 604800 {
            return "\(Int(interval / 86400))天前"
        } else {
            return formatted(style: .short)
        }
    }
}

// MARK: - Array Extensions

extension Array {
    /// 安全下标访问
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - CGPoint Extensions

extension CGPoint {
    /// 计算到另一点的距离
    func distance(to point: CGPoint) -> CGFloat {
        let dx = x - point.x
        let dy = y - point.y
        return sqrt(dx * dx + dy * dy)
    }
    
    /// 归一化（用于打点，假设在0-1范围内）
    var normalized: CGPoint {
        return CGPoint(
            x: max(0, min(1, x)),
            y: max(0, min(1, y))
        )
    }
}

// MARK: - String Extensions

extension String {
    /// 本地化
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
}

// MARK: - Int Extensions

extension Int {
    /// 转为星级显示
    var starsDisplay: String {
        String(repeating: "⭐", count: Swift.min(self, 5))
    }
    
    /// 格式化大数字（如1234 -> 1.2k）
    var shortDisplay: String {
        if self >= 10000 {
            return String(format: "%.1f万", Double(self) / 10000)
        } else if self >= 1000 {
            return String(format: "%.1fk", Double(self) / 1000)
        }
        return "\(self)"
    }
}

// MARK: - TimeInterval Extensions

extension TimeInterval {
    /// 格式化为时分秒
    var formattedDuration: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - UIColor Extensions

extension UIColor {
    /// 从十六进制创建颜色
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0
        
        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}

// MARK: - Haptic Feedback

enum HapticFeedback {
    /// 轻击反馈
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    /// 中等反馈
    static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    /// 重击反馈
    static func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    /// 成功反馈
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    /// 警告反馈
    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
    
    /// 错误反馈
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
}
