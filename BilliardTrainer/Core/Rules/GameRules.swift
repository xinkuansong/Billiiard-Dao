//
//  GameRules.swift
//  BilliardTrainer
//
//  犯规检测与规则判定
//

import Foundation

enum BallGroup {
    case solids
    case stripes
    case open
}

enum Foul: String {
    case cueBallPocketed
    case wrongFirstHit
    case noCushionAfterContact
    case noBallHit
}

enum GameEvent {
    case ballBallCollision(ball1: String, ball2: String, time: Float)
    case ballCushionCollision(ball: String, time: Float)
    case ballPocketed(ball: String, pocket: String, time: Float)
    case cueBallPocketed(time: Float)
}

struct EightBallRules {
    static func isLegalShot(events: [GameEvent], currentGroup: BallGroup) -> (legal: Bool, fouls: [Foul]) {
        var fouls: [Foul] = []
        
        if events.isEmpty {
            return (false, [.noBallHit])
        }
        
        // 1. 母球落袋
        if events.contains(where: { event in
            if case .cueBallPocketed = event { return true }
            return false
        }) {
            fouls.append(.cueBallPocketed)
        }
        
        // 2. 首碰错误
        if let firstHit = firstBallHit(events: events) {
            if currentGroup != .open {
                if let num = extractBallNumber(firstHit) {
                    let isSolid = (1...7).contains(num)
                    let isStripe = (9...15).contains(num)
                    if (currentGroup == .solids && !isSolid) || (currentGroup == .stripes && !isStripe) {
                        fouls.append(.wrongFirstHit)
                    }
                } else {
                    // Unknown ball name, treat as foul
                    fouls.append(.wrongFirstHit)
                }
            }
        } else {
            fouls.append(.noBallHit)
        }
        
        // 3. 无库边
        let hasCushion = events.contains(where: { event in
            if case .ballCushionCollision = event { return true }
            return false
        })
        let hasPocket = events.contains(where: { event in
            if case .ballPocketed = event { return true }
            return false
        })
        if !hasCushion && !hasPocket {
            fouls.append(.noCushionAfterContact)
        }
        
        return (fouls.isEmpty, fouls)
    }
    
    /// 从球名中提取球号数字
    /// 支持格式: "ball_N" (程序化球) 和 "_N" (USDZ模型球)
    private static func extractBallNumber(_ name: String) -> Int? {
        if name.hasPrefix("ball_") {
            return Int(name.dropFirst(5))
        } else if name.hasPrefix("_"), let num = Int(name.dropFirst(1)) {
            return num
        }
        return nil
    }
    
    private static func firstBallHit(events: [GameEvent]) -> String? {
        for event in events {
            if case let .ballBallCollision(ball1, ball2, _) = event {
                if ball1 == "cueBall" { return ball2 }
                if ball2 == "cueBall" { return ball1 }
            }
        }
        return nil
    }
}
