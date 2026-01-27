//
//  TrainingDetailView.swift
//  BilliardTrainer
//
//  训练详情页 - 难度选择和训练入口
//

import SwiftUI

struct TrainingDetailView: View {
    let ground: TrainingGround

    @State private var selectedDifficulty: Int = 1
    @State private var showTrainingScene: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 训练场头部
                TrainingHeaderSection(ground: ground)

                // 难度选择
                DifficultySelector(
                    selectedDifficulty: $selectedDifficulty,
                    maxDifficulty: ground.maxStars
                )

                // 训练说明
                TrainingInfoSection(ground: ground, difficulty: selectedDifficulty)

                // 历史最佳
                BestRecordSection(ground: ground)

                Spacer(minLength: 20)

                // 开始训练按钮
                StartTrainingButton(action: startTraining)
            }
            .padding()
        }
        .navigationTitle(ground.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .fullScreenCover(isPresented: $showTrainingScene) {
            TrainingSceneView(config: createConfig())
        }
    }

    // MARK: - Actions

    private func startTraining() {
        showTrainingScene = true
    }

    private func createConfig() -> TrainingConfig {
        switch ground.id {
        case "aiming":
            return .aimingConfig(difficulty: selectedDifficulty)
        case "spin":
            return .spinConfig(difficulty: selectedDifficulty)
        case "bank":
            return .bankShotConfig(difficulty: selectedDifficulty)
        case "kick":
            return .kickShotConfig(difficulty: selectedDifficulty)
        case "diamond":
            return .diamondConfig(difficulty: selectedDifficulty)
        default:
            return .aimingConfig(difficulty: selectedDifficulty)
        }
    }
}

// MARK: - Training Header Section
private struct TrainingHeaderSection: View {
    let ground: TrainingGround

    var body: some View {
        VStack(spacing: 16) {
            // 图标
            Image(systemName: ground.icon)
                .font(.system(size: 50))
                .foregroundColor(.white)
                .frame(width: 100, height: 100)
                .background(ground.color)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: ground.color.opacity(0.4), radius: 10, y: 5)

            // 描述
            Text(ground.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }
}

// MARK: - Difficulty Selector
private struct DifficultySelector: View {
    @Binding var selectedDifficulty: Int
    let maxDifficulty: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择难度")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(1...maxDifficulty, id: \.self) { level in
                    DifficultyButton(
                        level: level,
                        isSelected: selectedDifficulty == level,
                        action: { selectedDifficulty = level }
                    )
                }
            }

            // 难度说明
            Text(difficultyDescription(for: selectedDifficulty))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private func difficultyDescription(for level: Int) -> String {
        switch level {
        case 1: return "入门难度：直球训练，适合初学者"
        case 2: return "基础难度：30度角度球，培养角度感"
        case 3: return "进阶难度：45度角度球，提高精准度"
        case 4: return "高级难度：60度角度球，挑战薄球"
        case 5: return "专家难度：混合角度，随机变化"
        default: return ""
        }
    }
}

// MARK: - Difficulty Button
private struct DifficultyButton: View {
    let level: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                // 星星
                HStack(spacing: 2) {
                    ForEach(1...level, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.caption2)
                    }
                }
                .foregroundColor(isSelected ? .white : .orange)

                // 难度名称
                Text(levelName(for: level))
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.orange : Color(.secondarySystemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    private func levelName(for level: Int) -> String {
        switch level {
        case 1: return "入门"
        case 2: return "基础"
        case 3: return "进阶"
        case 4: return "高级"
        case 5: return "专家"
        default: return ""
        }
    }
}

// MARK: - Training Info Section
private struct TrainingInfoSection: View {
    let ground: TrainingGround
    let difficulty: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("训练内容")
                .font(.headline)

            VStack(spacing: 8) {
                InfoRow(icon: "target", title: "目标", value: "完成10球进袋")
                InfoRow(icon: "clock", title: "时限", value: "无时间限制")
                InfoRow(icon: "chart.bar", title: "评分", value: "根据进球率和连击评分")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Info Row
private struct InfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(title)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Best Record Section
private struct BestRecordSection: View {
    let ground: TrainingGround

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("历史最佳")
                .font(.headline)

            HStack(spacing: 16) {
                RecordItem(title: "最高分", value: "\(ground.bestScore)", icon: "trophy.fill", color: .orange)
                RecordItem(title: "最佳进球率", value: "78%", icon: "percent", color: .green)
                RecordItem(title: "最快完成", value: "2:35", icon: "timer", color: .blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Record Item
private struct RecordItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Start Training Button
private struct StartTrainingButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "play.fill")
                Text("开始训练")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        TrainingDetailView(ground: TrainingGround.allGrounds[0])
    }
}
