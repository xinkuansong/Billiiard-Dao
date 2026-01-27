//
//  AimingSystem.swift
//  BilliardTrainer
//
//  瞄准系统 - 计算瞄准点、分离角、走位预测
//

import SceneKit
import Foundation

// MARK: - Aiming System
/// 瞄准系统
class AimingCalculator {
    
    // MARK: - Types
    
    /// 瞄准结果
    struct AimResult {
        /// 瞄准点（目标球上的接触点）
        let aimPoint: SCNVector3
        
        /// 需要击打的方向
        let aimDirection: SCNVector3
        
        /// 厚度 (0-1, 1为正撞)
        let thickness: Float
        
        /// 预计分离角（度）
        let separationAngle: Float
        
        /// 母球预计停止位置
        let cueBallEndPosition: SCNVector3?
        
        /// 是否可进袋
        let canPocket: Bool
        
        /// 难度评分 (1-5)
        let difficulty: Int
    }
    
    /// 走位区域
    struct PositionZone {
        let center: SCNVector3
        let radius: Float
        let rating: Int  // 1-5, 5为最佳
    }
    
    // MARK: - Main Calculation
    
    /// 计算从母球到目标球进袋的瞄准信息
    static func calculateAim(
        cueBall: SCNVector3,
        targetBall: SCNVector3,
        pocket: SCNVector3,
        spinX: Float = 0,  // 左右塞 (-1 to 1)
        spinY: Float = 0   // 上下打点 (-1 to 1)
    ) -> AimResult {
        // 1. 计算目标球到袋口的方向
        let ballToPocket = (pocket - targetBall).normalized()
        
        // 2. 计算瞄准点（目标球的接触点）
        // 接触点在目标球与袋口连线的反方向延伸处
        let aimPoint = targetBall - ballToPocket * (BallPhysics.radius * 2)
        
        // 3. 计算母球到瞄准点的方向
        let aimDirection = (aimPoint - cueBall).normalized()
        
        // 4. 计算厚度（切入角度）
        let cueToBall = (targetBall - cueBall).normalized()
        let thickness = calculateThickness(cueToBall: cueToBall, ballToPocket: ballToPocket)
        
        // 5. 计算分离角
        let separationAngle = calculateSeparationAngle(
            thickness: thickness,
            spinY: spinY
        )
        
        // 6. 计算母球预计停止位置（简化）
        let cueBallEndPosition = predictCueBallPosition(
            cueBall: cueBall,
            targetBall: targetBall,
            thickness: thickness,
            separationAngle: separationAngle,
            spinX: spinX,
            spinY: spinY
        )
        
        // 7. 检查是否可进袋
        let canPocket = checkCanPocket(
            targetBall: targetBall,
            pocket: pocket,
            aimDirection: ballToPocket
        )
        
        // 8. 计算难度
        let difficulty = calculateDifficulty(
            cueBall: cueBall,
            targetBall: targetBall,
            pocket: pocket,
            thickness: thickness
        )
        
        return AimResult(
            aimPoint: aimPoint,
            aimDirection: aimDirection,
            thickness: thickness,
            separationAngle: separationAngle,
            cueBallEndPosition: cueBallEndPosition,
            canPocket: canPocket,
            difficulty: difficulty
        )
    }
    
    // MARK: - Thickness Calculation
    
    /// 计算厚度
    /// - Returns: 0-1，1为正撞（全厚），0为完全擦边
    static func calculateThickness(cueToBall: SCNVector3, ballToPocket: SCNVector3) -> Float {
        // 厚度 = cos(切入角)
        let dotProduct = cueToBall.dot(ballToPocket)
        return max(0, min(1, dotProduct))
    }
    
    /// 根据厚度描述球的类型
    static func thicknessDescription(_ thickness: Float) -> String {
        switch thickness {
        case 0.9...1.0: return "全厚"
        case 0.75..<0.9: return "厚球"
        case 0.5..<0.75: return "半球"
        case 0.25..<0.5: return "薄球"
        case 0..<0.25: return "极薄"
        default: return "无效"
        }
    }
    
    // MARK: - Separation Angle
    
    /// 计算分离角
    static func calculateSeparationAngle(thickness: Float, spinY: Float) -> Float {
        // 基础分离角 = 90° - 切入角
        // 纯滚动时分离角约90°
        // 切入角 = arccos(thickness)
        let cutAngle = acos(thickness)  // 弧度
        var separationAngle = SeparationAngle.pureRolling - (cutAngle * 180 / .pi)
        
        // 杆法修正
        if spinY > 0 {
            // 高杆：分离角减小
            separationAngle += SeparationAngle.topSpinCorrection * spinY
        } else if spinY < 0 {
            // 低杆：分离角增大（定杆/拉杆）
            separationAngle += SeparationAngle.backSpinCorrection * abs(spinY)
        }
        
        return max(0, min(180, separationAngle))
    }
    
    // MARK: - Position Prediction
    
    /// 预测母球碰撞后的停止位置
    static func predictCueBallPosition(
        cueBall: SCNVector3,
        targetBall: SCNVector3,
        thickness: Float,
        separationAngle: Float,
        spinX: Float,
        spinY: Float
    ) -> SCNVector3 {
        // 碰撞方向
        let collisionDirection = (targetBall - cueBall).normalized()
        
        // 分离方向（在XZ平面旋转）
        let angleRad = separationAngle * .pi / 180
        let separationDirection = rotateVectorY(collisionDirection, angle: angleRad)
        
        // 塞的影响：侧旋会使母球弧线运动
        var finalDirection = separationDirection
        if abs(spinX) > 0.1 {
            // 左塞向右偏，右塞向左偏
            let sideOffset = rotateVectorY(separationDirection, angle: -spinX * 0.3)
            finalDirection = sideOffset
        }
        
        // 预估行进距离（基于杆法）
        var travelDistance: Float = 0.5  // 基础距离
        
        if spinY > 0 {
            // 高杆：母球跟进
            travelDistance += spinY * 0.5
        } else if spinY < 0 {
            // 低杆：母球后退或定住
            travelDistance = max(0.1, travelDistance + spinY * 0.3)
        }
        
        // 厚度影响
        travelDistance *= (1 - thickness * 0.3)
        
        return targetBall + finalDirection * travelDistance
    }
    
    // MARK: - Pocket Check
    
    /// 检查是否可进袋
    static func checkCanPocket(
        targetBall: SCNVector3,
        pocket: SCNVector3,
        aimDirection: SCNVector3
    ) -> Bool {
        let distance = (pocket - targetBall).length()
        
        // 距离过远进袋困难
        if distance > 2.0 {
            return false
        }
        
        // 检查是否有障碍球（简化版本）
        // TODO: 实现障碍检测
        
        return true
    }
    
    // MARK: - Difficulty
    
    /// 计算击球难度
    static func calculateDifficulty(
        cueBall: SCNVector3,
        targetBall: SCNVector3,
        pocket: SCNVector3,
        thickness: Float
    ) -> Int {
        var score: Float = 0
        
        // 1. 距离因素
        let cueToBallDistance = (targetBall - cueBall).length()
        let ballToPocketDistance = (pocket - targetBall).length()
        let totalDistance = cueToBallDistance + ballToPocketDistance
        
        if totalDistance > 2.0 { score += 2 }
        else if totalDistance > 1.5 { score += 1 }
        
        // 2. 厚度因素
        if thickness < 0.25 { score += 2 }  // 极薄球
        else if thickness < 0.5 { score += 1 }  // 薄球
        
        // 3. 角度因素
        // 计算母球-目标球-袋口形成的角度
        let cutAngle = acos(thickness) * 180 / .pi
        if cutAngle > 60 { score += 2 }
        else if cutAngle > 45 { score += 1 }
        
        return min(5, max(1, Int(score) + 1))
    }
    
    // MARK: - Position Zone
    
    /// 计算走位区域评分
    static func calculatePositionZones(
        currentBall: SCNVector3,
        nextTargetBall: SCNVector3,
        nextPocket: SCNVector3
    ) -> [PositionZone] {
        var zones: [PositionZone] = []
        
        // 理想位置：能以舒适角度进下一颗球
        let idealDirection = (nextPocket - nextTargetBall).normalized()
        let idealPosition = nextTargetBall - idealDirection * 0.5
        
        // 最佳区域（5分）
        zones.append(PositionZone(
            center: idealPosition,
            radius: 0.15,
            rating: 5
        ))
        
        // 良好区域（4分）
        zones.append(PositionZone(
            center: idealPosition,
            radius: 0.25,
            rating: 4
        ))
        
        // 可接受区域（3分）
        zones.append(PositionZone(
            center: idealPosition,
            radius: 0.4,
            rating: 3
        ))
        
        return zones
    }
    
    // MARK: - Helper Functions
    
    /// 绕Y轴旋转向量
    private static func rotateVectorY(_ vector: SCNVector3, angle: Float) -> SCNVector3 {
        let cosAngle = cos(angle)
        let sinAngle = sin(angle)
        
        return SCNVector3(
            vector.x * cosAngle - vector.z * sinAngle,
            vector.y,
            vector.x * sinAngle + vector.z * cosAngle
        )
    }
}

// MARK: - Ghost Ball Method
/// 虚拟球瞄准法
class GhostBallAiming {
    
    /// 计算虚拟球位置
    static func calculateGhostBallPosition(
        targetBall: SCNVector3,
        pocket: SCNVector3
    ) -> SCNVector3 {
        let direction = (pocket - targetBall).normalized()
        return targetBall - direction * (BallPhysics.radius * 2)
    }
    
    /// 检查虚拟球是否与其他球重叠
    static func isGhostBallBlocked(
        ghostBallPosition: SCNVector3,
        otherBalls: [SCNVector3]
    ) -> Bool {
        let minDistance = BallPhysics.radius * 2
        
        for ball in otherBalls {
            let distance = (ball - ghostBallPosition).length()
            if distance < minDistance {
                return true
            }
        }
        
        return false
    }
}
