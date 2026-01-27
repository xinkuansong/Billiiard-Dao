//
//  PhysicsConstants.swift
//  BilliardTrainer
//
//  物理引擎常量定义
//

import Foundation

// MARK: - 球体物理参数
struct BallPhysics {
    /// 球体直径 (米)
    static let diameter: Float = 0.05715  // 57.15mm
    
    /// 球体半径 (米)
    static let radius: Float = diameter / 2
    
    /// 球体质量 (千克)
    static let mass: Float = 0.170  // 170g
    
    /// 球体弹性系数 (球与球碰撞)
    static let restitution: Float = 0.92
    
    /// 球体摩擦系数
    static let friction: Float = 0.2
    
    /// 球体滚动阻尼系数
    static let rollingDamping: Float = 0.15
}

// MARK: - 球台物理参数
struct TablePhysics {
    /// 球台内部长度 (米) - 中式八球标准
    static let innerLength: Float = 2.54  // 254cm
    
    /// 球台内部宽度 (米)
    static let innerWidth: Float = 1.27  // 127cm
    
    /// 球台高度 (米)
    static let height: Float = 0.80  // 80cm
    
    /// 库边高度 (米)
    static let cushionHeight: Float = 0.037  // 37mm
    
    /// 库边厚度 (米)
    static let cushionThickness: Float = 0.05
    
    /// 袋口直径 (米)
    static let pocketDiameter: Float = 0.086  // 86mm 中袋
    
    /// 角袋口直径 (米)
    static let cornerPocketDiameter: Float = 0.083  // 83mm
    
    /// 台呢摩擦系数
    static let clothFriction: Float = 0.2
    
    /// 库边弹性系数
    static let cushionRestitution: Float = 0.75
    
    /// 颗星数量（每边）
    static let diamondCount: Int = 4  // 每长边4颗星，每短边2颗星
}

// MARK: - 旋转物理参数
struct SpinPhysics {
    /// 最大上旋速度 (rad/s)
    static let maxTopSpin: Float = 150.0
    
    /// 最大下旋速度 (rad/s)
    static let maxBackSpin: Float = 150.0
    
    /// 最大侧旋速度 (rad/s)
    static let maxSideSpin: Float = 100.0
    
    /// 旋转衰减系数
    static let spinDecayRate: Float = 0.98
    
    /// 滑动摩擦系数 (旋转状态)
    static let slidingFriction: Float = 0.3
    
    /// 滚动摩擦系数 (纯滚动状态)
    static let rollingFriction: Float = 0.015
    
    /// 旋转转化为线速度的系数
    static let spinToVelocityRatio: Float = 0.7
    
    /// 塞的库边修正系数
    static let cushionSpinCorrectionFactor: Float = 0.15
}

// MARK: - 击球力度参数
struct StrokePhysics {
    /// 最小击球速度 (m/s)
    static let minVelocity: Float = 0.5
    
    /// 最大击球速度 (m/s)
    static let maxVelocity: Float = 8.0
    
    /// 轻杆速度阈值
    static let softVelocity: Float = 2.0
    
    /// 中杆速度阈值
    static let mediumVelocity: Float = 4.5
    
    /// 重杆速度阈值
    static let hardVelocity: Float = 6.5
    
    /// 发力杆速度阈值
    static let powerVelocity: Float = 8.0
}

// MARK: - 瞄准系统参数
struct AimingSystem {
    /// 瞄准线最大长度 (米)
    static let maxAimLineLength: Float = 3.0
    
    /// 瞄准线最小长度 (米)
    static let minAimLineLength: Float = 0.05
    
    /// 预测轨迹点数
    static let trajectoryPointCount: Int = 30
    
    /// 轨迹预测时间步长 (秒)
    static let trajectoryTimeStep: Float = 0.016  // 60fps
    
    /// 分离角计算阈值 (度)
    static let separationAngleThreshold: Float = 90.0
}

// MARK: - 相机参数
struct CameraSettings {
    /// 2D俯视角度 (度)
    static let topDownAngle: Float = 90.0
    
    /// 3D默认角度 (度)
    static let perspective3DAngle: Float = 45.0
    
    /// 击球视角角度 (度)
    static let shootingAngle: Float = 15.0
    
    /// 最小相机距离 (米)
    static let minDistance: Float = 0.5
    
    /// 最大相机距离 (米)
    static let maxDistance: Float = 5.0
    
    /// 默认相机距离 (米)
    static let defaultDistance: Float = 2.5
    
    /// 相机移动平滑系数
    static let smoothFactor: Float = 0.1
    
    /// 视角切换动画时长 (秒)
    static let transitionDuration: Double = 0.5
}

// MARK: - 颗星系统参数
struct DiamondSystem {
    /// 一库颗星系数
    static let oneRailFactor: Float = 1.0
    
    /// 两库颗星系数
    static let twoRailFactor: Float = 0.5
    
    /// 三库颗星系数
    static let threeRailFactor: Float = 0.33
    
    /// 塞对颗星的影响系数
    static let spinCorrection: Float = 0.5
    
    /// 速度对颗星的影响系数
    static let speedCorrection: Float = 0.2
}

// MARK: - 分离角参数
struct SeparationAngle {
    /// 纯滚动分离角 (度)
    static let pureRolling: Float = 90.0
    
    /// 高杆分离角修正 (度)
    static let topSpinCorrection: Float = -20.0
    
    /// 低杆分离角修正 (度)
    static let backSpinCorrection: Float = 20.0
    
    /// 薄球临界厚度
    static let thinBallThreshold: Float = 0.25
    
    /// 厚球临界厚度
    static let thickBallThreshold: Float = 0.75
}

// MARK: - 球体颜色定义
struct BallColors {
    /// 母球 - 白色
    static let cueBall = (r: 1.0, g: 1.0, b: 1.0)
    
    /// 黑八 - 黑色
    static let eightBall = (r: 0.05, g: 0.05, b: 0.05)
    
    /// 全色球 1-7
    static let solidBalls: [(r: Double, g: Double, b: Double)] = [
        (1.0, 0.84, 0.0),   // 1 - 黄色
        (0.0, 0.0, 0.8),    // 2 - 蓝色
        (1.0, 0.0, 0.0),    // 3 - 红色
        (0.5, 0.0, 0.5),    // 4 - 紫色
        (1.0, 0.5, 0.0),    // 5 - 橙色
        (0.0, 0.5, 0.0),    // 6 - 绿色
        (0.5, 0.0, 0.0)     // 7 - 栗色
    ]
    
    /// 花色球 9-15 (底色白色，带条纹)
    static let stripedBalls: [(r: Double, g: Double, b: Double)] = [
        (1.0, 0.84, 0.0),   // 9 - 黄色条纹
        (0.0, 0.0, 0.8),    // 10 - 蓝色条纹
        (1.0, 0.0, 0.0),    // 11 - 红色条纹
        (0.5, 0.0, 0.5),    // 12 - 紫色条纹
        (1.0, 0.5, 0.0),    // 13 - 橙色条纹
        (0.0, 0.5, 0.0),    // 14 - 绿色条纹
        (0.5, 0.0, 0.0)     // 15 - 栗色条纹
    ]
}
