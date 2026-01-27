//
//  HomeView.swift
//  BilliardTrainer
//
//  首页视图
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 用户信息卡片
                    UserInfoCard()
                    
                    // 快捷入口
                    QuickAccessSection()
                    
                    // 学习进度
                    LearningProgressSection()
                    
                    // 今日统计
                    TodayStatsSection()
                }
                .padding()
            }
            .navigationTitle("球道")
            .background(Color(.systemGroupedBackground))
        }
    }
}

// MARK: - User Info Card
struct UserInfoCard: View {
    var body: some View {
        HStack {
            // 头像
            Circle()
                .fill(Color.green.opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.title)
                        .foregroundColor(.green)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Lv.1 新手")
                    .font(.headline)
                
                // 经验值进度条
                ProgressView(value: 0.3)
                    .tint(.green)
                
                Text("150 / 500 经验值")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

// MARK: - Quick Access Section
struct QuickAccessSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("快捷入口")
                .font(.headline)
            
            HStack(spacing: 12) {
                QuickAccessButton(
                    title: "继续学习",
                    subtitle: "L3 第一次进球",
                    icon: "play.fill",
                    color: .green
                )
                
                QuickAccessButton(
                    title: "快速练习",
                    subtitle: "瞄准训练",
                    icon: "target",
                    color: .orange
                )
            }
        }
    }
}

struct QuickAccessButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
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

// MARK: - Learning Progress Section
struct LearningProgressSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("学习进度")
                    .font(.headline)
                Spacer()
                Text("3/18 课程")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.green)
                        .frame(width: geometry.size.width * 0.17, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

// MARK: - Today Stats Section
struct TodayStatsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日统计")
                .font(.headline)
            
            HStack(spacing: 20) {
                StatItem(title: "练习时长", value: "15", unit: "分钟")
                StatItem(title: "进球数", value: "23", unit: "个")
                StatItem(title: "进球率", value: "68", unit: "%")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}
