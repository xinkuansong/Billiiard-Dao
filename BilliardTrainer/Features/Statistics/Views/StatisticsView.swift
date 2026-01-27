//
//  StatisticsView.swift
//  BilliardTrainer
//
//  数据统计视图
//

import SwiftUI

struct StatisticsView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 总览卡片
                    OverviewCard()
                    
                    // 进球率统计
                    AccuracyCard()
                    
                    // 练习时长
                    PracticeTimeCard()
                    
                    // 技能雷达图（V1.2）
                    SkillRadarCard()
                }
                .padding()
            }
            .navigationTitle("统计")
            .background(Color(.systemGroupedBackground))
        }
    }
}

// MARK: - Overview Card
struct OverviewCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("总览")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 0) {
                OverviewItem(title: "总练习", value: "12.5", unit: "小时")
                Divider().frame(height: 40)
                OverviewItem(title: "总进球", value: "1,234", unit: "个")
                Divider().frame(height: 40)
                OverviewItem(title: "平均进球率", value: "62", unit: "%")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

struct OverviewItem: View {
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

// MARK: - Accuracy Card
struct AccuracyCard: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("进球率")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                AccuracyRow(title: "直球", rate: 0.85)
                AccuracyRow(title: "30°角度球", rate: 0.72)
                AccuracyRow(title: "45°角度球", rate: 0.58)
                AccuracyRow(title: "60°角度球", rate: 0.45)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

struct AccuracyRow: View {
    let title: String
    let rate: Double
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(rateColor)
                        .frame(width: geometry.size.width * rate, height: 8)
                }
            }
            .frame(width: 100, height: 8)
            
            Text("\(Int(rate * 100))%")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(rateColor)
                .frame(width: 45, alignment: .trailing)
        }
    }
    
    var rateColor: Color {
        if rate >= 0.7 { return .green }
        if rate >= 0.5 { return .orange }
        return .red
    }
}

// MARK: - Practice Time Card
struct PracticeTimeCard: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("本周练习")
                    .font(.headline)
                Spacer()
                Text("共 3.5 小时")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 简单的柱状图
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(weekData, id: \.day) { data in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(data.isToday ? Color.green : Color.green.opacity(0.3))
                            .frame(width: 30, height: CGFloat(data.minutes) * 1.5)
                        
                        Text(data.day)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 100)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
    
    var weekData: [(day: String, minutes: Int, isToday: Bool)] {
        [
            ("一", 30, false),
            ("二", 45, false),
            ("三", 20, false),
            ("四", 60, false),
            ("五", 15, false),
            ("六", 40, false),
            ("日", 25, true)
        ]
    }
}

// MARK: - Skill Radar Card
struct SkillRadarCard: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("技能雷达")
                    .font(.headline)
                
                Text("V1.2")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(4)
                
                Spacer()
            }
            
            // 占位图
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 1)
                    .frame(width: 150, height: 150)
                
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 1)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 1)
                    .frame(width: 50, height: 50)
                
                Text("即将推出")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(height: 180)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5)
    }
}

#Preview {
    StatisticsView()
}
