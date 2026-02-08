//
//  TrainingSceneView.swift
//  BilliardTrainer
//
//  训练场景视图 - 集成SceneKit场景与HUD
//

import SwiftUI

struct TrainingSceneView: View {
    let config: TrainingConfig

    @StateObject private var viewModel: TrainingViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showPauseMenu: Bool = false
    @State private var showExitConfirm: Bool = false

    init(config: TrainingConfig) {
        self.config = config
        self._viewModel = StateObject(wrappedValue: TrainingViewModel(config: config))
    }

    var body: some View {
        ZStack {
            // 3D场景
            BilliardSceneView(viewModel: viewModel.sceneViewModel)
                .ignoresSafeArea()

            // HUD覆盖层
            VStack {
                // 顶部HUD
                TopHUD(
                    viewModel: viewModel,
                    onPause: pauseTraining,
                    onToggleView: { viewModel.sceneViewModel.toggleViewMode() }
                )

                Spacer()

                // 中间区域：打点选择器 + 力度条
                HStack {
                    // 左下角：打点选择器
                    if showGameControls {
                        CuePointSelectorView(
                            cuePoint: Binding(
                                get: { viewModel.sceneViewModel.selectedCuePoint },
                                set: { viewModel.sceneViewModel.selectedCuePoint = $0 }
                            )
                        )
                        .padding(.leading, 16)
                    }
                    
                    Spacer()
                    
                    // 右侧：力度条
                    if showGameControls {
                        PowerGaugeView(
                            power: viewModel.sceneViewModel.currentPower,
                            isCharging: viewModel.sceneViewModel.gameState == .charging
                        )
                        .padding(.trailing, 16)
                    }
                }
                .padding(.bottom, 8)

                // 底部控制提示
                BottomHint(gameState: viewModel.sceneViewModel.gameState)
            }
            .padding()

            // 2D俯视模式提示标签
            if viewModel.sceneViewModel.isTopDownView {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("2D 俯视模式")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                        Spacer()
                    }
                    .padding(.bottom, 60)
                }
            }

            // 暂停菜单
            if showPauseMenu {
                PauseMenuOverlay(
                    onResume: resumeTraining,
                    onRestart: restartTraining,
                    onExit: { showExitConfirm = true }
                )
            }

            // 训练结果
            if viewModel.showResult {
                TrainingResultOverlay(
                    result: viewModel.calculateFinalResult(),
                    config: config,
                    onRestart: restartTraining,
                    onExit: exitTraining
                )
            }
        }
        .onAppear {
            print("[TrainingSceneView] 📱 onAppear 触发")
            // 强制横屏
            OrientationHelper.forceLandscape()
            print("[TrainingSceneView] 📱 开始训练...")
            viewModel.startTraining()
            print("[TrainingSceneView] ✅ 训练已启动")
        }
        .onDisappear {
            // 恢复竖屏
            OrientationHelper.restorePortrait()
        }
        .alert("确定退出训练?", isPresented: $showExitConfirm) {
            Button("继续训练", role: .cancel) {
                showPauseMenu = true
            }
            Button("退出", role: .destructive) {
                exitTraining()
            }
        } message: {
            Text("退出后当前训练进度将不会保存")
        }
    }
    
    /// 是否显示游戏控件（打点选择器、力度条）
    private var showGameControls: Bool {
        let state = viewModel.sceneViewModel.gameState
        return state == .aiming || state == .charging
    }

    // MARK: - Actions

    private func pauseTraining() {
        viewModel.pauseTraining()
        showPauseMenu = true
    }

    private func resumeTraining() {
        showPauseMenu = false
        viewModel.resumeTraining()
    }

    private func restartTraining() {
        showPauseMenu = false
        viewModel.restartTraining()
    }

    private func exitTraining() {
        dismiss()
    }
}

// MARK: - Top HUD
private struct TopHUD: View {
    @ObservedObject var viewModel: TrainingViewModel
    let onPause: () -> Void
    let onToggleView: () -> Void

    var body: some View {
        HStack {
            // 暂停按钮
            Button(action: onPause) {
                Image(systemName: "pause.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }

            Spacer()

            // 得分和进度
            HStack(spacing: 20) {
                // 得分
                VStack(spacing: 2) {
                    Text("得分")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(viewModel.currentScore)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }

                // 进球数
                VStack(spacing: 2) {
                    Text("进球")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(viewModel.pocketedCount)/\(viewModel.config.goalCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }

                // 时间（如果有限时）
                if viewModel.timeRemaining != nil {
                    VStack(spacing: 2) {
                        Text("时间")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text(viewModel.formattedTimeRemaining)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(timeColor)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(12)

            Spacer()
            
            HStack(spacing: 8) {
                // 2D/3D 视角切换按钮
                Button(action: onToggleView) {
                    Image(systemName: viewModel.sceneViewModel.isTopDownView ? "cube.fill" : "square.split.1x2.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                // 连击显示
                if viewModel.comboCount > 1 {
                    ComboIndicator(combo: viewModel.comboCount)
                }
            }
        }
    }

    private var timeColor: Color {
        guard let time = viewModel.timeRemaining else { return .white }
        if time <= 10 {
            return .red
        } else if time <= 30 {
            return .orange
        }
        return .white
    }
}

// MARK: - Combo Indicator
private struct ComboIndicator: View {
    let combo: Int

    var body: some View {
        VStack(spacing: 2) {
            Text("COMBO")
                .font(.caption2)
                .fontWeight(.bold)
            Text("x\(combo)")
                .font(.title3)
                .fontWeight(.bold)
        }
        .foregroundColor(.orange)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
}

// MARK: - Bottom Hint
private struct BottomHint: View {
    let gameState: BilliardSceneViewModel.GameState

    var body: some View {
        Text(hintText)
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
    }

    private var hintText: String {
        switch gameState {
        case .idle:
            return "点击母球开始瞄准"
        case .placing:
            return "拖动放置母球 | 点击确认位置"
        case .aiming:
            return "拖动调整方向 | 长按蓄力击球"
        case .charging:
            return "松开击球"
        case .ballsMoving:
            return "等待球停止..."
        case .turnEnd:
            return "准备下一击"
        }
    }
}

// MARK: - Pause Menu Overlay
private struct PauseMenuOverlay: View {
    let onResume: () -> Void
    let onRestart: () -> Void
    let onExit: () -> Void

    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            // 菜单卡片
            VStack(spacing: 20) {
                Text("暂停")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                VStack(spacing: 12) {
                    PauseMenuButton(title: "继续训练", icon: "play.fill", color: .green, action: onResume)
                    PauseMenuButton(title: "重新开始", icon: "arrow.clockwise", color: .orange, action: onRestart)
                    PauseMenuButton(title: "退出训练", icon: "xmark", color: .red, action: onExit)
                }
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
        }
    }
}

// MARK: - Pause Menu Button
private struct PauseMenuButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(width: 200)
            .padding(.vertical, 14)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }
}

// MARK: - Training Result Overlay
private struct TrainingResultOverlay: View {
    let result: TrainingResult
    let config: TrainingConfig
    let onRestart: () -> Void
    let onExit: () -> Void

    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            // 结果卡片
            VStack(spacing: 24) {
                // 标题
                Text("训练完成")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                // 星级
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= result.stars ? "star.fill" : "star")
                            .font(.title)
                            .foregroundColor(.orange)
                    }
                }

                // 得分
                VStack(spacing: 4) {
                    Text("得分")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(result.score)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                }

                // 统计数据
                HStack(spacing: 32) {
                    ResultStatItem(title: "进球", value: "\(result.pocketedCount)")
                    ResultStatItem(title: "击球", value: "\(result.totalShots)")
                    ResultStatItem(title: "进球率", value: result.formattedAccuracy)
                    ResultStatItem(title: "用时", value: result.formattedDuration)
                }

                // 按钮
                HStack(spacing: 16) {
                    Button(action: onExit) {
                        Text("返回")
                            .fontWeight(.semibold)
                            .frame(width: 120)
                            .padding(.vertical, 14)
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }

                    Button(action: onRestart) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("再来一次")
                        }
                        .fontWeight(.semibold)
                        .frame(width: 140)
                        .padding(.vertical, 14)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
        }
    }
}

// MARK: - Result Stat Item
private struct ResultStatItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

// MARK: - Preview
#Preview {
    TrainingSceneView(config: .aimingConfig(difficulty: 1))
}
