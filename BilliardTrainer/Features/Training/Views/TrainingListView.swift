//
//  TrainingListView.swift
//  BilliardTrainer
//
//  训练场列表视图
//

import SwiftUI

struct TrainingListView: View {
    @State private var showFreePlay = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 自由练习入口
                    FreePlayEntryCard(showFreePlay: $showFreePlay)
                    
                    // 训练场列表
                    ForEach(TrainingGround.allGrounds) { ground in
                        TrainingGroundCard(ground: ground)
                    }
                    
                    // 挑战模式入口
                    ChallengeSection()
                }
                .padding()
            }
            .navigationTitle("训练")
            .background(Color(.systemGroupedBackground))
            .fullScreenCover(isPresented: $showFreePlay) {
                FreePlayView()
            }
        }
    }
}

// MARK: - Free Play Entry Card
struct FreePlayEntryCard: View {
    @Binding var showFreePlay: Bool
    
    var body: some View {
        Button {
            showFreePlay = true
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "sportscourt.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("自由练习")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("中式八球 · 完整规则 · 验证物理引擎")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.08), radius: 8)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .cyan.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Training Ground Card
struct TrainingGroundCard: View {
    let ground: TrainingGround
    
    var body: some View {
        NavigationLink {
            TrainingDetailView(ground: ground)
        } label: {
            HStack(spacing: 16) {
                // 图标
                Image(systemName: ground.icon)
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(ground.isLocked ? Color.gray : ground.color)
                    .cornerRadius(12)
                
                // 信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(ground.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if ground.isLocked {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Text(ground.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // 难度星级
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= ground.maxStars ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                        
                        Text("最高\(ground.maxStars)星")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 最佳记录
                if !ground.isLocked {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("最佳")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(ground.bestScore)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 5)
            .opacity(ground.isLocked ? 0.7 : 1)
        }
        .disabled(ground.isLocked)
    }
}

// MARK: - Challenge Section
struct ChallengeSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("挑战模式")
                .font(.headline)
            
            HStack(spacing: 12) {
                ChallengeCard(
                    title: "单球挑战",
                    subtitle: "60秒内进球数",
                    icon: "timer",
                    color: .blue,
                    isLocked: false
                )
                
                ChallengeCard(
                    title: "走位挑战",
                    subtitle: "进球+走位精度",
                    icon: "scope",
                    color: .purple,
                    isLocked: false
                )
            }
        }
        .padding(.top, 8)
    }
}

struct ChallengeCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isLocked: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

// MARK: - Training Ground Model
struct TrainingGround: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let color: Color
    let maxStars: Int
    var isLocked: Bool
    var bestScore: Int = 0
    
    static let allGrounds: [TrainingGround] = [
        TrainingGround(
            id: "aiming",
            name: "瞄准训练场",
            description: "直球、角度球进袋练习",
            icon: "target",
            color: .green,
            maxStars: 5,
            isLocked: false,
            bestScore: 78
        ),
        TrainingGround(
            id: "spin",
            name: "杆法训练场",
            description: "中杆、高杆、低杆、塞球",
            icon: "circle.circle",
            color: .blue,
            maxStars: 5,
            isLocked: true
        ),
        TrainingGround(
            id: "bank",
            name: "翻袋训练场",
            description: "库边反弹进球练习",
            icon: "arrow.triangle.swap",
            color: .orange,
            maxStars: 5,
            isLocked: true
        ),
        TrainingGround(
            id: "kick",
            name: "K球训练场",
            description: "库边解球练习",
            icon: "arrow.turn.up.right",
            color: .purple,
            maxStars: 5,
            isLocked: true
        ),
        TrainingGround(
            id: "diamond",
            name: "颗星计算器",
            description: "颗星公式练习",
            icon: "diamond",
            color: .pink,
            maxStars: 5,
            isLocked: true
        )
    ]
}

#Preview {
    TrainingListView()
}
