//
//  DiamondSystem.swift
//  BilliardTrainer
//
//  颗星公式系统 - 计算翻袋和K球的颗星数值
//

import SceneKit
import Foundation

// MARK: - Diamond System Calculator
/// 颗星公式计算器
class DiamondSystemCalculator {
    
    // MARK: - Types
    
    /// 颗星位置
    struct DiamondPosition {
        /// 边（top, bottom, left, right）
        let edge: TableEdge
        
        /// 颗星编号（从左/下开始，0-based）
        let number: Float
        
        /// 世界坐标
        var worldPosition: SCNVector3 {
            calculateWorldPosition()
        }
        
        private func calculateWorldPosition() -> SCNVector3 {
            let halfLength = TablePhysics.innerLength / 2
            let halfWidth = TablePhysics.innerWidth / 2
            let tableHeight = TablePhysics.height + BallPhysics.radius
            
            switch edge {
            case .top:
                // 上边：从左到右 0-8
                let x = -halfLength + (number / 8.0) * TablePhysics.innerLength
                return SCNVector3(x, tableHeight, halfWidth)
                
            case .bottom:
                // 下边：从左到右 0-8
                let x = -halfLength + (number / 8.0) * TablePhysics.innerLength
                return SCNVector3(x, tableHeight, -halfWidth)
                
            case .left:
                // 左边：从下到上 0-4
                let z = -halfWidth + (number / 4.0) * TablePhysics.innerWidth
                return SCNVector3(-halfLength, tableHeight, z)
                
            case .right:
                // 右边：从下到上 0-4
                let z = -halfWidth + (number / 4.0) * TablePhysics.innerWidth
                return SCNVector3(halfLength, tableHeight, z)
            }
        }
    }
    
    /// 球台边
    enum TableEdge: String {
        case top, bottom, left, right
    }
    
    /// 颗星计算结果
    struct DiamondResult {
        /// 出发点颗星
        let startDiamond: DiamondPosition
        
        /// 第一库接触点颗星
        let firstRailDiamond: DiamondPosition
        
        /// 目标点颗星（翻袋用）
        let targetDiamond: DiamondPosition?
        
        /// 需要的塞（-1左塞，0无塞，1右塞）
        let recommendedEnglish: Float
        
        /// 需要的力度（0-1）
        let recommendedPower: Float
        
        /// 计算公式说明
        let formula: String
    }
    
    // MARK: - One Rail Diamond System
    
    /// 一库颗星公式
    /// 翻袋：击球点颗星 - 目标点颗星 = 第一库颗星
    static func calculateOneRailBank(
        cueBall: SCNVector3,
        targetPocket: SCNVector3
    ) -> DiamondResult? {
        // 确定出发边和目标边
        guard let startEdge = nearestEdge(to: cueBall),
              let targetEdge = pocketEdge(pocket: targetPocket) else {
            return nil
        }
        
        // 计算出发点颗星
        let startDiamond = positionToDiamond(position: cueBall, edge: startEdge)
        
        // 计算目标点颗星
        let targetDiamond = positionToDiamond(position: targetPocket, edge: targetEdge)
        
        // 一库公式：第一库 = 出发点 - 目标点 / 2
        let firstRailNumber = (startDiamond - targetDiamond) / 2
        
        // 确定第一库边
        let firstRailEdge = oppositeEdge(edge: startEdge)
        
        let firstRailDiamond = DiamondPosition(edge: firstRailEdge, number: firstRailNumber)
        
        return DiamondResult(
            startDiamond: DiamondPosition(edge: startEdge, number: startDiamond),
            firstRailDiamond: firstRailDiamond,
            targetDiamond: DiamondPosition(edge: targetEdge, number: targetDiamond),
            recommendedEnglish: 0,
            recommendedPower: 0.5,
            formula: "一库公式：\(String(format: "%.1f", startDiamond)) - \(String(format: "%.1f", targetDiamond)) / 2 = \(String(format: "%.1f", firstRailNumber))"
        )
    }
    
    // MARK: - Two Rail Diamond System
    
    /// 两库颗星公式
    static func calculateTwoRailKick(
        cueBall: SCNVector3,
        targetBall: SCNVector3,
        firstRailEdge: TableEdge
    ) -> DiamondResult? {
        // 两库公式通常用于K球
        // 出发点 + 目标点 = 第一库点 × 2
        
        guard let startEdge = nearestEdge(to: cueBall) else {
            return nil
        }
        
        let startDiamond = positionToDiamond(position: cueBall, edge: startEdge)
        let targetDiamond = positionToDiamond(position: targetBall, edge: oppositeEdge(edge: firstRailEdge))
        
        let firstRailNumber = (startDiamond + targetDiamond) / 2
        
        let firstRailDiamond = DiamondPosition(edge: firstRailEdge, number: firstRailNumber)
        
        return DiamondResult(
            startDiamond: DiamondPosition(edge: startEdge, number: startDiamond),
            firstRailDiamond: firstRailDiamond,
            targetDiamond: nil,
            recommendedEnglish: calculateEnglishCorrection(startDiamond: startDiamond, targetDiamond: targetDiamond),
            recommendedPower: 0.6,
            formula: "两库公式：(\(String(format: "%.1f", startDiamond)) + \(String(format: "%.1f", targetDiamond))) / 2 = \(String(format: "%.1f", firstRailNumber))"
        )
    }
    
    // MARK: - Three Rail Diamond System
    
    /// 三库颗星公式
    static func calculateThreeRailPath(
        cueBall: SCNVector3,
        targetBall: SCNVector3
    ) -> DiamondResult? {
        // 三库公式更复杂，需要迭代计算
        // 简化版本：基于Mirror System
        
        guard let startEdge = nearestEdge(to: cueBall) else {
            return nil
        }
        
        let startDiamond = positionToDiamond(position: cueBall, edge: startEdge)
        
        // 三库起始通常打向短边
        let firstRailEdge: TableEdge = startEdge == .left ? .top : .top
        let firstRailNumber = startDiamond * DiamondSystem.threeRailFactor
        
        let firstRailDiamond = DiamondPosition(edge: firstRailEdge, number: firstRailNumber)
        
        return DiamondResult(
            startDiamond: DiamondPosition(edge: startEdge, number: startDiamond),
            firstRailDiamond: firstRailDiamond,
            targetDiamond: nil,
            recommendedEnglish: -0.5,  // 三库通常需要反塞
            recommendedPower: 0.7,
            formula: "三库公式：\(String(format: "%.1f", startDiamond)) × 0.33 = \(String(format: "%.1f", firstRailNumber))"
        )
    }
    
    // MARK: - English Correction
    
    /// 塞的修正
    static func calculateEnglishCorrection(startDiamond: Float, targetDiamond: Float) -> Float {
        // 根据角度判断需要的塞
        let angle = abs(startDiamond - targetDiamond)
        
        if angle > 4 {
            // 大角度需要反塞压线
            return -0.5
        } else if angle > 2 {
            // 中等角度轻微塞
            return startDiamond > targetDiamond ? 0.3 : -0.3
        }
        
        return 0
    }
    
    /// 速度对颗星的修正
    static func calculateSpeedCorrection(power: Float) -> Float {
        // 力度越大，球路越长，颗星数需要调整
        if power > 0.7 {
            return -0.5  // 大力时减少颗星
        } else if power < 0.3 {
            return 0.5   // 小力时增加颗星
        }
        return 0
    }
    
    // MARK: - Helper Functions
    
    /// 找到最近的边
    private static func nearestEdge(to position: SCNVector3) -> TableEdge? {
        let halfLength = TablePhysics.innerLength / 2
        let halfWidth = TablePhysics.innerWidth / 2
        
        let distToTop = halfWidth - position.z
        let distToBottom = position.z + halfWidth
        let distToLeft = position.x + halfLength
        let distToRight = halfLength - position.x
        
        let minDist = min(distToTop, distToBottom, distToLeft, distToRight)
        
        if minDist == distToTop { return .top }
        if minDist == distToBottom { return .bottom }
        if minDist == distToLeft { return .left }
        if minDist == distToRight { return .right }
        
        return nil
    }
    
    /// 袋口所在边
    private static func pocketEdge(pocket: SCNVector3) -> TableEdge? {
        let halfLength = TablePhysics.innerLength / 2
        let halfWidth = TablePhysics.innerWidth / 2
        
        // 角袋
        if abs(pocket.x) > halfLength * 0.9 {
            return pocket.z > 0 ? .top : .bottom
        }
        
        // 中袋
        if abs(pocket.z) > halfWidth * 0.9 {
            return pocket.z > 0 ? .top : .bottom
        }
        
        return nil
    }
    
    /// 对边
    private static func oppositeEdge(edge: TableEdge) -> TableEdge {
        switch edge {
        case .top: return .bottom
        case .bottom: return .top
        case .left: return .right
        case .right: return .left
        }
    }
    
    /// 位置转颗星数
    private static func positionToDiamond(position: SCNVector3, edge: TableEdge) -> Float {
        let halfLength = TablePhysics.innerLength / 2
        let halfWidth = TablePhysics.innerWidth / 2
        
        switch edge {
        case .top, .bottom:
            // 长边：0-8颗星
            let normalized = (position.x + halfLength) / TablePhysics.innerLength
            return normalized * 8.0
            
        case .left, .right:
            // 短边：0-4颗星
            let normalized = (position.z + halfWidth) / TablePhysics.innerWidth
            return normalized * 4.0
        }
    }
}

// MARK: - Bank Shot Calculator
/// 翻袋计算器
class BankShotCalculator {
    
    /// 计算翻袋瞄准点
    static func calculateBankShot(
        cueBall: SCNVector3,
        targetBall: SCNVector3,
        pocket: SCNVector3,
        railEdge: DiamondSystemCalculator.TableEdge
    ) -> SCNVector3? {
        // 镜像法计算翻袋点
        let mirroredPocket = mirrorPosition(position: pocket, acrossEdge: railEdge)
        
        // 目标球到镜像袋口的连线与库边的交点
        let direction = (mirroredPocket - targetBall).normalized()
        
        // 计算与库边的交点
        guard let bankPoint = lineIntersectionWithEdge(
            from: targetBall,
            direction: direction,
            edge: railEdge
        ) else {
            return nil
        }
        
        return bankPoint
    }
    
    /// 镜像位置
    private static func mirrorPosition(
        position: SCNVector3,
        acrossEdge: DiamondSystemCalculator.TableEdge
    ) -> SCNVector3 {
        let halfLength = TablePhysics.innerLength / 2
        let halfWidth = TablePhysics.innerWidth / 2
        
        var mirrored = position
        
        switch acrossEdge {
        case .top:
            mirrored.z = 2 * halfWidth - position.z
        case .bottom:
            mirrored.z = -2 * halfWidth - position.z
        case .left:
            mirrored.x = -2 * halfLength - position.x
        case .right:
            mirrored.x = 2 * halfLength - position.x
        }
        
        return mirrored
    }
    
    /// 计算直线与边的交点
    private static func lineIntersectionWithEdge(
        from start: SCNVector3,
        direction: SCNVector3,
        edge: DiamondSystemCalculator.TableEdge
    ) -> SCNVector3? {
        let halfLength = TablePhysics.innerLength / 2
        let halfWidth = TablePhysics.innerWidth / 2
        let tableHeight = TablePhysics.height + BallPhysics.radius
        
        var t: Float = 0
        
        switch edge {
        case .top:
            if direction.z == 0 { return nil }
            t = (halfWidth - start.z) / direction.z
        case .bottom:
            if direction.z == 0 { return nil }
            t = (-halfWidth - start.z) / direction.z
        case .left:
            if direction.x == 0 { return nil }
            t = (-halfLength - start.x) / direction.x
        case .right:
            if direction.x == 0 { return nil }
            t = (halfLength - start.x) / direction.x
        }
        
        if t < 0 { return nil }
        
        return SCNVector3(
            start.x + direction.x * t,
            tableHeight,
            start.z + direction.z * t
        )
    }
}
