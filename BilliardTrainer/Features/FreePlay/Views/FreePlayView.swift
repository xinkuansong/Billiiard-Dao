//
//  FreePlayView.swift
//  BilliardTrainer
//
//  自由练习模式 — 中式八球全流程
//

import SwiftUI
import UIKit

struct FreePlayView: View {
    @StateObject private var viewModel = FreePlayViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var showPauseMenu: Bool = false
    @State private var showExitConfirm: Bool = false
    
    var body: some View {
        ZStack {
            // 3D Scene
            BilliardSceneView(viewModel: viewModel.sceneViewModel)
                .ignoresSafeArea()
            
            // HUD overlay
            VStack(spacing: 0) {
                // Top HUD
                FreePlayTopHUD(
                    viewModel: viewModel,
                    onPause: { showPauseMenu = true },
                    onToggleView: { viewModel.sceneViewModel.toggleViewMode() },
                    onReplay: { viewModel.replayLastShot() },
                    onReset: { viewModel.resetGame() },
                    showReplayButton: viewModel.sceneViewModel.lastShotRecorder != nil && !showGameControls
                )
                .padding(.horizontal)
                .padding(.top, 8)
                
                Spacer()
                
                // Foul banner
                if viewModel.foulFlash {
                    FoulBanner(message: viewModel.statusMessage)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.3), value: viewModel.foulFlash)
                }
                
                if let warning = viewModel.sceneViewModel.selectionWarning {
                    Text(warning)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.85))
                        .cornerRadius(10)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.25), value: viewModel.sceneViewModel.selectionWarning)
                }
                
                Spacer()
                
                // Bottom controls
                HStack(alignment: .bottom) {
                    // Cue point selector
                    if showGameControls {
                        CuePointSelectorView(
                            cuePoint: Binding(
                                get: { viewModel.sceneViewModel.selectedCuePoint },
                                set: { viewModel.sceneViewModel.selectedCuePoint = $0 }
                            )
                        )
                        .padding(.leading, 16)
                    }
                    
                    // View toggle buttons
                    if showGameControls && !viewModel.sceneViewModel.isTopDownView {
                        VStack(spacing: 8) {
                            Button {
                                viewModel.sceneViewModel.switchToObservationView()
                            } label: {
                                Image(systemName: "eye.fill")
                                    .font(.title3)
                                    .foregroundColor(viewModel.sceneViewModel.isInObservationView ? .yellow : .white)
                                    .frame(width: 40, height: 40)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                            
                            Button {
                                viewModel.sceneViewModel.switchToAimingView()
                            } label: {
                                Image(systemName: "scope")
                                    .font(.title3)
                                    .foregroundColor(!viewModel.sceneViewModel.isInObservationView ? .yellow : .white)
                                    .frame(width: 40, height: 40)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.leading, 12)
                    }
                    
                    Spacer()
                    
                    // 力度选择条（松手即出杆）
                    if showGameControls {
                        PowerGaugeView(
                            power: Binding(
                                get: { viewModel.sceneViewModel.currentPower },
                                set: { viewModel.sceneViewModel.currentPower = $0 }
                            ),
                            enabled: viewModel.sceneViewModel.gameState == .aiming,
                            onRelease: {
                                viewModel.sceneViewModel.executeStrokeFromSlider()
                            }
                        )
                        .padding(.trailing, 2)
                    }
                }
                .padding(.bottom, 8)
                
                // Bottom hint
                FreePlayBottomHint(
                    gameState: viewModel.sceneViewModel.gameState,
                    phase: viewModel.phase,
                    statusMessage: viewModel.statusMessage
                )
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            // 2D mode label
            if viewModel.sceneViewModel.isTopDownView {
                VStack {
                    Spacer()
                    Text("2D 俯视模式")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .padding(.bottom, 60)
                }
            }
            
            // Pause menu
            if showPauseMenu {
                FreePlayPauseOverlay(
                    onResume: { showPauseMenu = false },
                    onRestart: {
                        showPauseMenu = false
                        viewModel.resetGame()
                    },
                    onExit: { showExitConfirm = true }
                )
            }
            
            // Game over overlay
            if viewModel.showGameOverOverlay {
                GameOverOverlay(
                    won: viewModel.didWin,
                    shotCount: viewModel.shotCount,
                    pocketedCount: viewModel.pocketedCount,
                    accuracy: viewModel.accuracy,
                    onRestart: { viewModel.resetGame() },
                    onExit: { dismiss() }
                )
            }
        }
        .onAppear {
            OrientationHelper.forceLandscape()
            viewModel.startNewGame()
        }
        .onDisappear {
            OrientationHelper.restorePortrait()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                OrientationHelper.forceLandscape()
            }
        }
        .alert("确定退出？", isPresented: $showExitConfirm) {
            Button("继续", role: .cancel) { showPauseMenu = true }
            Button("退出", role: .destructive) { dismiss() }
        } message: {
            Text("退出后当前比赛将不会保存")
        }
    }
    
    private var showGameControls: Bool {
        viewModel.sceneViewModel.gameState == .aiming
    }
}

private struct FPSBadge: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { _ in
            let fps = Int(RenderQualityManager.shared.currentFPS.rounded())
            Text("\(fps) FPS")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
        }
    }
}

// MARK: - Top HUD

private struct FreePlayTopHUD: View {
    @ObservedObject var viewModel: FreePlayViewModel
    let onPause: () -> Void
    let onToggleView: () -> Void
    let onReplay: () -> Void
    let onReset: () -> Void
    let showReplayButton: Bool
    
    var body: some View {
        HStack {
            // Pause
            Button(action: onPause) {
                Image(systemName: "pause.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Ball info
            HStack(spacing: 16) {
                // Group indicator
                VStack(spacing: 2) {
                    Text("花色")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                    Text(viewModel.playerGroupName)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(groupColor)
                }
                
                Divider()
                    .frame(height: 30)
                    .background(Color.white.opacity(0.3))
                
                // Remaining balls
                VStack(spacing: 2) {
                    Text("全色")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                    Text("\(viewModel.remainingSolids)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 2) {
                    Text("花色")
                        .font(.caption2)
                        .foregroundColor(.cyan)
                    Text("\(viewModel.remainingStripes)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                if viewModel.eightBallOnTable {
                    Text("8")
                        .font(.subheadline)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.black)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
                }
                
                Divider()
                    .frame(height: 30)
                    .background(Color.white.opacity(0.3))
                
                // Shot count
                VStack(spacing: 2) {
                    Text("击球")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(viewModel.shotCount)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            
            Spacer()
            
            HStack(spacing: 8) {
                // 2D/3D toggle
                Button(action: onToggleView) {
                    Image(systemName: viewModel.sceneViewModel.isTopDownView ? "cube.fill" : "square.split.1x2.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                
                Button {
                    viewModel.sceneViewModel.toggleRenderQuality()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: viewModel.sceneViewModel.isHighQuality ? "sparkles" : "sparkle")
                            .font(.title3)
                        Text(viewModel.sceneViewModel.isHighQuality ? "高画质" : "低画质")
                            .font(.caption2)
                    }
                    .foregroundColor(viewModel.sceneViewModel.isHighQuality ? .yellow : .white)
                    .frame(width: 48, height: 48)
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                }
                
                if showReplayButton {
                    ActionButton(icon: "arrow.counterclockwise", label: "回放", action: onReplay)
                }
                
                ActionButton(icon: "arrow.clockwise", label: "重置", action: onReset)
                FPSBadge()
            }
        }
    }
    
    private var groupColor: Color {
        switch viewModel.phase {
        case .waitingBreak: return .gray
        case .openTable: return .white
        case .playing(let group):
            return group == .solids ? .yellow : .cyan
        case .eightBallStage: return .white
        case .gameOver: return .gray
        }
    }
}

// MARK: - Foul Banner

private struct FoulBanner: View {
    let message: String
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
            Text(message)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.red.opacity(0.85))
        .cornerRadius(12)
    }
}

// MARK: - Action Button

private struct ActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
            }
            .foregroundColor(.white)
            .frame(width: 48, height: 48)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
        }
    }
}

// MARK: - Bottom Hint

private struct FreePlayBottomHint: View {
    let gameState: BilliardSceneViewModel.GameState
    let phase: GamePhase
    let statusMessage: String
    
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
        case .placing:
            if case .waitingBreak = phase {
                return "拖动放置白球（开球线后） | 点击确认"
            }
            return "拖动放置白球（自由球） | 点击确认"
        case .aiming:
            return "拖动调整方向 | 右侧滑条选力度松手出杆"
        case .ballsMoving:
            return "等待球停止..."
        case .turnEnd:
            return statusMessage
        case .idle:
            return statusMessage
        }
    }
}

// MARK: - Pause Overlay

private struct FreePlayPauseOverlay: View {
    let onResume: () -> Void
    let onRestart: () -> Void
    let onExit: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("暂停")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                VStack(spacing: 12) {
                    PauseButton(title: "继续", icon: "play.fill", color: .green, action: onResume)
                    PauseButton(title: "重新开始", icon: "arrow.clockwise", color: .orange, action: onRestart)
                    PauseButton(title: "退出", icon: "xmark", color: .red, action: onExit)
                }
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
        }
    }
}

private struct PauseButton: View {
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

// MARK: - Game Over Overlay

private struct GameOverOverlay: View {
    let won: Bool
    let shotCount: Int
    let pocketedCount: Int
    let accuracy: String
    let onRestart: () -> Void
    let onExit: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Title
                Text(won ? "胜利！" : "失败")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(won ? .green : .red)
                
                Image(systemName: won ? "trophy.fill" : "xmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(won ? .yellow : .red)
                
                // Stats
                HStack(spacing: 32) {
                    GameOverStat(title: "击球", value: "\(shotCount)")
                    GameOverStat(title: "进球", value: "\(pocketedCount)")
                    GameOverStat(title: "进球率", value: accuracy)
                }
                
                // Buttons
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
                            Text("再来一局")
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

private struct GameOverStat: View {
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
    FreePlayView()
}
