//
//  FreePlayViewModel.swift
//  BilliardTrainer
//
//  自由练习模式视图模型 — 管理完整中式八球游戏循环
//

import Foundation
import SwiftUI
import SceneKit
import Combine

@MainActor
class FreePlayViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var shotCount: Int = 0
    @Published var pocketedCount: Int = 0
    @Published var isPaused: Bool = false
    @Published var showGameOverOverlay: Bool = false
    @Published var foulFlash: Bool = false
    
    // MARK: - Properties
    
    let sceneViewModel: BilliardSceneViewModel
    let gameManager: EightBallGameManager
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var phase: GamePhase { gameManager.phase }
    var playerGroupName: String { gameManager.playerGroupName }
    var remainingSolids: Int { gameManager.remainingSolids.count }
    var remainingStripes: Int { gameManager.remainingStripes.count }
    var statusMessage: String { gameManager.statusMessage }
    var isBallInHand: Bool { gameManager.isBallInHand }
    var isGameOver: Bool { gameManager.isGameOver }
    var didWin: Bool { gameManager.didWin }
    var eightBallOnTable: Bool { gameManager.eightBallOnTable }
    
    var accuracy: String {
        guard shotCount > 0 else { return "0%" }
        return String(format: "%.0f%%", Double(pocketedCount) / Double(shotCount) * 100)
    }
    
    // MARK: - Initialization
    
    init() {
        self.sceneViewModel = BilliardSceneViewModel()
        self.gameManager = EightBallGameManager()
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        sceneViewModel.$gameState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        sceneViewModel.onTargetBallPocketed = { [weak self] _, _ in
            self?.pocketedCount += 1
        }
        
        sceneViewModel.onShotCompleted = { [weak self] _, _ in
            self?.onShotFinished()
        }
        
        sceneViewModel.ballSelectionValidator = { [weak self] ballName in
            self?.validateBallSelection(ballName) ?? (true, nil)
        }
    }
    
    private func validateBallSelection(_ ballName: String) -> (valid: Bool, message: String?) {
        guard let num = extractBallNumber(ballName) else { return (true, nil) }
        
        switch gameManager.phase {
        case .waitingBreak, .gameOver:
            return (true, nil)
        case .openTable:
            if num == 8 {
                return (false, "花色未定，不能选择8号球")
            }
            return (true, nil)
        case .playing(let group):
            let myCleared = group == .solids ? gameManager.remainingSolids.isEmpty : gameManager.remainingStripes.isEmpty
            if myCleared {
                if num != 8 { return (false, "己方花色已清台，请打8号球") }
                return (true, nil)
            }
            if num == 8 {
                return (false, "己方花色未清台，不能选择8号球")
            }
            if group == .solids && (9...15).contains(num) {
                return (false, "你是全色球方，不能选择花色球")
            }
            if group == .stripes && (1...7).contains(num) {
                return (false, "你是花色球方，不能选择全色球")
            }
            return (true, nil)
        case .eightBallStage:
            if num != 8 {
                return (false, "请打8号球")
            }
            return (true, nil)
        }
    }
    
    private func extractBallNumber(_ name: String) -> Int? {
        if name.hasPrefix("ball_") {
            return Int(name.dropFirst(5))
        } else if name.hasPrefix("_"), let num = Int(name.dropFirst(1)) {
            return num
        }
        return nil
    }
    
    // MARK: - Game Control
    
    func startNewGame() {
        sceneViewModel.scene.setCameraMode(.aim, animated: false)
        
        shotCount = 0
        pocketedCount = 0
        isPaused = false
        showGameOverOverlay = false
        foulFlash = false
        
        gameManager.reset()
        
        sceneViewModel.scene.hideGhostBall()
        sceneViewModel.scene.resetScene()
        sceneViewModel.scene.setupRackLayout()
        sceneViewModel.pitchAngle = CameraRigConfig.aimPitchRad
        sceneViewModel.currentPower = 0
        sceneViewModel.selectedCuePoint = CGPoint(x: 0.5, y: 0.5)
        
        if sceneViewModel.cueStick == nil {
            sceneViewModel.setupCueStick()
        }
        
        sceneViewModel.enterPlacingMode(behindHeadString: true)
    }
    
    func resetGame() {
        startNewGame()
    }
    
    func pauseGame() {
        isPaused = true
    }
    
    func resumeGame() {
        isPaused = false
    }
    
    // MARK: - Shot Processing
    
    private func onShotFinished() {
        shotCount += 1
        
        let events = sceneViewModel.shotEvents
        gameManager.processShot(events: events)
        // Force UI update
        objectWillChange.send()
        
        if gameManager.isGameOver {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.showGameOverOverlay = true
            }
            return
        }
        
        if gameManager.isBallInHand {
            foulFlash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.foulFlash = false
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self, !self.isGameOver else { return }
                self.sceneViewModel.enterPlacingMode(
                    behindHeadString: self.gameManager.ballInHandBehindLine
                )
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self, !self.isGameOver else { return }
                self.sceneViewModel.prepareNextShot()
            }
        }
    }
    
    // MARK: - Replay
    
    func replayLastShot() {
        sceneViewModel.playLastShotReplay(speed: 0.5)
    }
}
