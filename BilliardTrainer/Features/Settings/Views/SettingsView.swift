//
//  SettingsView.swift
//  BilliardTrainer
//
//  设置视图
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("aimLineEnabled") private var aimLineEnabled = true
    @AppStorage("trajectoryEnabled") private var trajectoryEnabled = false
    
    var body: some View {
        NavigationStack {
            List {
                // 游戏设置
                Section("游戏设置") {
                    Toggle(isOn: $soundEnabled) {
                        Label("音效", systemImage: "speaker.wave.2.fill")
                    }
                    
                    Toggle(isOn: $hapticEnabled) {
                        Label("震动反馈", systemImage: "iphone.radiowaves.left.and.right")
                    }
                    
                    Toggle(isOn: $aimLineEnabled) {
                        Label("瞄准辅助线", systemImage: "line.diagonal")
                    }
                    
                    Toggle(isOn: $trajectoryEnabled) {
                        Label("轨迹预测", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    }
                }
                
                // 购买管理
                Section("购买管理") {
                    NavigationLink {
                        PurchasedContentView()
                    } label: {
                        Label("已购内容", systemImage: "bag.fill")
                    }
                    
                    Button {
                        // TODO: 恢复购买
                    } label: {
                        Label("恢复购买", systemImage: "arrow.clockwise")
                    }
                }
                
                // 关于
                Section("关于") {
                    HStack {
                        Label("版本", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://example.com/privacy")!) {
                        Label("隐私政策", systemImage: "hand.raised.fill")
                    }
                    
                    NavigationLink {
                        HelpView()
                    } label: {
                        Label("使用帮助", systemImage: "questionmark.circle")
                    }
                }
                
                // 反馈
                Section("反馈") {
                    Link(destination: URL(string: "mailto:support@example.com")!) {
                        Label("意见反馈", systemImage: "envelope.fill")
                    }
                    
                    Link(destination: URL(string: "https://apps.apple.com/app/id123456789?action=write-review")!) {
                        Label("给个好评", systemImage: "star.fill")
                    }
                }
            }
            .navigationTitle("设置")
        }
    }
}

// MARK: - Purchased Content View
struct PurchasedContentView: View {
    var body: some View {
        List {
            Section("已解锁") {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("入门课程 (L1-L3)")
                    Spacer()
                    Text("免费")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("未解锁") {
                PurchaseRow(title: "基础课程包", subtitle: "L4-L8", price: "¥18")
                PurchaseRow(title: "进阶课程包", subtitle: "L9-L14", price: "¥25")
                PurchaseRow(title: "高级课程包", subtitle: "L15-L18", price: "¥20")
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("全功能解锁")
                            .fontWeight(.medium)
                        Text("包含所有课程和训练场")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("¥48") {
                        // TODO: 购买
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            }
        }
        .navigationTitle("已购内容")
    }
}

struct PurchaseRow: View {
    let title: String
    let subtitle: String
    let price: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(price) {
                // TODO: 购买
            }
            .buttonStyle(.bordered)
        }
    }
}

// MARK: - Help View
struct HelpView: View {
    var body: some View {
        List {
            Section("基础操作") {
                HelpItem(
                    title: "如何瞄准",
                    description: "触摸屏幕拖动可调整瞄准方向，松开确认方向"
                )
                HelpItem(
                    title: "如何击球",
                    description: "确认方向后，向后拖动蓄力，松开即可击球"
                )
                HelpItem(
                    title: "如何选择打点",
                    description: "点击母球可打开打点面板，选择不同位置产生不同旋转效果"
                )
            }
            
            Section("相机控制") {
                HelpItem(
                    title: "旋转视角",
                    description: "单指拖动可环绕球台旋转视角"
                )
                HelpItem(
                    title: "缩放视角",
                    description: "双指捏合可拉近或拉远视角"
                )
                HelpItem(
                    title: "调整角度",
                    description: "双指上下滑动可调整俯仰角度"
                )
                HelpItem(
                    title: "切换视角",
                    description: "双击屏幕可快速切换预设视角"
                )
            }
        }
        .navigationTitle("使用帮助")
    }
}

struct HelpItem: View {
    let title: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .fontWeight(.medium)
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SettingsView()
}
