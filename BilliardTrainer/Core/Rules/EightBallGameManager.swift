//
//  EightBallGameManager.swift
//  BilliardTrainer
//
//  中式八球完整规则状态机
//

import Foundation

// MARK: - Game Phase

enum GamePhase: Equatable {
    case waitingBreak
    case openTable
    case playing(group: BallGroup)
    case eightBallStage
    case gameOver(won: Bool)
}

// MARK: - Shot Result

struct ShotResult {
    let legal: Bool
    let fouls: [Foul]
    let pocketedBalls: [String]
    let cueBallPocketed: Bool
    let eightBallPocketed: Bool
    let firstHitBall: String?
    let cushionHitAfterContact: Bool
}

// MARK: - Eight Ball Game Manager

class EightBallGameManager {
    
    // MARK: - Properties
    
    private(set) var phase: GamePhase = .waitingBreak
    private(set) var playerGroup: BallGroup = .open
    
    /// Remaining solid balls on table (1-7)
    private(set) var remainingSolids: Set<Int> = Set(1...7)
    
    /// Remaining stripe balls on table (9-15)
    private(set) var remainingStripes: Set<Int> = Set(9...15)
    
    /// Whether the 8-ball is still on table
    private(set) var eightBallOnTable: Bool = true
    
    /// Last shot fouls for display
    private(set) var lastFouls: [Foul] = []
    
    /// Whether the last shot was a foul (triggers ball-in-hand)
    private(set) var isBallInHand: Bool = false
    
    /// Whether ball-in-hand is restricted to behind head string (break only)
    private(set) var ballInHandBehindLine: Bool = true
    
    /// Message to display after a shot
    private(set) var statusMessage: String = "摆放白球，准备开球"
    
    // MARK: - Initialization
    
    func reset() {
        phase = .waitingBreak
        playerGroup = .open
        remainingSolids = Set(1...7)
        remainingStripes = Set(9...15)
        eightBallOnTable = true
        lastFouls = []
        isBallInHand = false
        ballInHandBehindLine = true
        statusMessage = "摆放白球，准备开球"
    }
    
    // MARK: - Process Shot
    
    /// Process shot events and advance game state.
    /// Returns whether the player should continue shooting (no foul, pocketed correct ball).
    @discardableResult
    func processShot(events: [GameEvent]) -> Bool {
        let result = analyzeShotEvents(events)
        lastFouls = result.fouls
        
        // Track pocketed balls
        for ballName in result.pocketedBalls {
            if let num = extractBallNumber(ballName) {
                if (1...7).contains(num) {
                    remainingSolids.remove(num)
                } else if (9...15).contains(num) {
                    remainingStripes.remove(num)
                } else if num == 8 {
                    eightBallOnTable = false
                }
            }
        }
        
        switch phase {
        case .waitingBreak:
            return processBreakShot(result)
        case .openTable:
            return processOpenTableShot(result)
        case .playing(let group):
            return processPlayingShot(result, group: group)
        case .eightBallStage:
            return processEightBallShot(result)
        case .gameOver:
            return false
        }
    }
    
    // MARK: - Break Shot
    
    private func processBreakShot(_ result: ShotResult) -> Bool {
        if result.cueBallPocketed {
            isBallInHand = true
            ballInHandBehindLine = true
            statusMessage = "开球犯规：白球落袋，重新放置白球"
            phase = .openTable
            return false
        }
        
        if result.eightBallPocketed {
            // 8-ball pocketed on break: re-rack
            statusMessage = "开球打进8号球，重新开球"
            reset()
            return false
        }
        
        if result.pocketedBalls.isEmpty && !result.cushionHitAfterContact {
            isBallInHand = true
            ballInHandBehindLine = false
            statusMessage = "开球犯规：未碰到球或未过4库"
            phase = .openTable
            return false
        }
        
        // Legal break
        isBallInHand = false
        ballInHandBehindLine = false
        
        if !result.pocketedBalls.isEmpty {
            // Pocketed balls on break — try to assign group
            if let group = tryAssignGroup(pocketed: result.pocketedBalls) {
                playerGroup = group
                phase = checkPhaseAfterGroupAssign()
                statusMessage = groupAssignMessage()
                return true
            }
        }
        
        phase = .openTable
        statusMessage = "花色未定，继续击球"
        return !result.pocketedBalls.isEmpty
    }
    
    // MARK: - Open Table Shot
    
    private func processOpenTableShot(_ result: ShotResult) -> Bool {
        if result.cueBallPocketed || !result.legal {
            isBallInHand = true
            ballInHandBehindLine = false
            lastFouls = result.fouls
            statusMessage = foulMessage(result.fouls)
            return false
        }
        
        isBallInHand = false
        
        if result.eightBallPocketed {
            phase = .gameOver(won: false)
            statusMessage = "花色未定时打进8号球，输了"
            return false
        }
        
        if !result.pocketedBalls.isEmpty {
            if let group = tryAssignGroup(pocketed: result.pocketedBalls) {
                playerGroup = group
                phase = checkPhaseAfterGroupAssign()
                statusMessage = groupAssignMessage()
                return true
            }
        }
        
        statusMessage = "花色未定，继续击球"
        return !result.pocketedBalls.isEmpty
    }
    
    // MARK: - Playing Shot
    
    private func processPlayingShot(_ result: ShotResult, group: BallGroup) -> Bool {
        if result.cueBallPocketed || !result.legal {
            isBallInHand = true
            ballInHandBehindLine = false
            lastFouls = result.fouls
            statusMessage = foulMessage(result.fouls)
            return false
        }
        
        isBallInHand = false
        
        if result.eightBallPocketed {
            let myBallsCleared = group == .solids ? remainingSolids.isEmpty : remainingStripes.isEmpty
            if myBallsCleared {
                phase = .gameOver(won: true)
                statusMessage = "打进8号球，赢了！"
            } else {
                phase = .gameOver(won: false)
                statusMessage = "己方花色未清台就打进8号球，输了"
            }
            return false
        }
        
        // Check if player's group is now cleared → move to 8-ball stage
        let myBallsCleared = group == .solids ? remainingSolids.isEmpty : remainingStripes.isEmpty
        if myBallsCleared {
            phase = .eightBallStage
            statusMessage = "己方花色全部清台，打8号球"
        }
        
        let pocketedOwnBalls = result.pocketedBalls.filter { name in
            guard let num = extractBallNumber(name) else { return false }
            return group == .solids ? (1...7).contains(num) : (9...15).contains(num)
        }
        
        return !pocketedOwnBalls.isEmpty
    }
    
    // MARK: - Eight Ball Shot
    
    private func processEightBallShot(_ result: ShotResult) -> Bool {
        if result.cueBallPocketed {
            if result.eightBallPocketed {
                phase = .gameOver(won: false)
                statusMessage = "白球和8号球同时落袋，输了"
            } else {
                isBallInHand = true
                ballInHandBehindLine = false
                statusMessage = "犯规：白球落袋"
            }
            return false
        }
        
        if !result.legal {
            isBallInHand = true
            ballInHandBehindLine = false
            lastFouls = result.fouls
            if result.eightBallPocketed {
                phase = .gameOver(won: false)
                statusMessage = "犯规时打进8号球，输了"
            } else {
                statusMessage = foulMessage(result.fouls)
            }
            return false
        }
        
        if result.eightBallPocketed {
            phase = .gameOver(won: true)
            statusMessage = "打进8号球，赢了！"
            return false
        }
        
        isBallInHand = false
        statusMessage = "继续打8号球"
        return false
    }
    
    // MARK: - Helpers
    
    private func analyzeShotEvents(_ events: [GameEvent]) -> ShotResult {
        var pocketed: [String] = []
        var cueBallPocketed = false
        var eightBallPocketed = false
        var firstHit: String? = nil
        var hasCushion = false
        var hasBallHit = false
        
        for event in events {
            switch event {
            case .ballBallCollision(let b1, let b2, _):
                hasBallHit = true
                if firstHit == nil {
                    if b1 == "cueBall" { firstHit = b2 }
                    else if b2 == "cueBall" { firstHit = b1 }
                }
            case .ballCushionCollision:
                hasCushion = true
            case .ballPocketed(let ball, _, _):
                pocketed.append(ball)
                if let num = extractBallNumber(ball), num == 8 {
                    eightBallPocketed = true
                }
            case .cueBallPocketed:
                cueBallPocketed = true
            }
        }
        
        // Determine fouls
        var fouls: [Foul] = []
        
        if cueBallPocketed {
            fouls.append(.cueBallPocketed)
        }
        
        if !hasBallHit {
            fouls.append(.noBallHit)
        } else {
            // Check first-hit legality based on phase
            if let firstHitBall = firstHit {
                if case .playing(let group) = phase {
                    if let num = extractBallNumber(firstHitBall) {
                        let isSolid = (1...7).contains(num)
                        let isStripe = (9...15).contains(num)
                        let isEight = num == 8
                        
                        let myBallsCleared = group == .solids ? remainingSolids.isEmpty : remainingStripes.isEmpty
                        if myBallsCleared {
                            // Must hit 8-ball first
                            if !isEight {
                                fouls.append(.wrongFirstHit)
                            }
                        } else {
                            if (group == .solids && !isSolid) || (group == .stripes && !isStripe) {
                                fouls.append(.wrongFirstHit)
                            }
                        }
                    }
                } else if case .eightBallStage = phase {
                    if let num = extractBallNumber(firstHitBall), num != 8 {
                        fouls.append(.wrongFirstHit)
                    }
                }
            }
            
            // No cushion after contact and no pocket
            if !hasCushion && pocketed.isEmpty {
                fouls.append(.noCushionAfterContact)
            }
        }
        
        return ShotResult(
            legal: fouls.isEmpty,
            fouls: fouls,
            pocketedBalls: pocketed,
            cueBallPocketed: cueBallPocketed,
            eightBallPocketed: eightBallPocketed,
            firstHitBall: firstHit,
            cushionHitAfterContact: hasCushion
        )
    }
    
    /// Try to assign ball group based on pocketed balls (only non-8 balls count)
    private func tryAssignGroup(pocketed: [String]) -> BallGroup? {
        var hasSolid = false
        var hasStripe = false
        
        for name in pocketed {
            guard let num = extractBallNumber(name) else { continue }
            if (1...7).contains(num) { hasSolid = true }
            if (9...15).contains(num) { hasStripe = true }
        }
        
        if hasSolid && !hasStripe { return .solids }
        if hasStripe && !hasSolid { return .stripes }
        // Both or neither → stays open
        return nil
    }
    
    private func checkPhaseAfterGroupAssign() -> GamePhase {
        let myBallsCleared = playerGroup == .solids ? remainingSolids.isEmpty : remainingStripes.isEmpty
        return myBallsCleared ? .eightBallStage : .playing(group: playerGroup)
    }
    
    private func groupAssignMessage() -> String {
        let groupName = playerGroup == .solids ? "全色球 (1-7)" : "花色球 (9-15)"
        return "你的花色：\(groupName)"
    }
    
    private func foulMessage(_ fouls: [Foul]) -> String {
        let descriptions = fouls.map { foul -> String in
            switch foul {
            case .cueBallPocketed: return "白球落袋"
            case .wrongFirstHit: return "首碰错误"
            case .noCushionAfterContact: return "无库边"
            case .noBallHit: return "空杆"
            }
        }
        return "犯规：" + descriptions.joined(separator: "、")
    }
    
    private func extractBallNumber(_ name: String) -> Int? {
        if name.hasPrefix("ball_") {
            return Int(name.dropFirst(5))
        } else if name.hasPrefix("_"), let num = Int(name.dropFirst(1)) {
            return num
        }
        return nil
    }
    
    // MARK: - Query Helpers
    
    /// Number of remaining balls in player's assigned group
    var remainingPlayerBalls: Int {
        switch playerGroup {
        case .solids: return remainingSolids.count
        case .stripes: return remainingStripes.count
        case .open: return remainingSolids.count + remainingStripes.count
        }
    }
    
    /// Human-readable group name
    var playerGroupName: String {
        switch playerGroup {
        case .solids: return "全色"
        case .stripes: return "花色"
        case .open: return "未定"
        }
    }
    
    var isGameOver: Bool {
        if case .gameOver = phase { return true }
        return false
    }
    
    var didWin: Bool {
        if case .gameOver(let won) = phase { return won }
        return false
    }
}
