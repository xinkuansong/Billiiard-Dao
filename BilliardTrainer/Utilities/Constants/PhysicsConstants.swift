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
    static let restitution: Float = 0.95
    
    /// 球体摩擦系数
    static let friction: Float = 0.2
    
    /// 球体滚动阻尼系数
    static let rollingDamping: Float = 0.10
    
    /// 球-球摩擦系数
    static let ballBallFriction: Float = 0.05
    
    /// 角速度阻尼（SceneKit）
    static let angularDamping: Float = 0.1
    
    /// 线速度阻尼（SceneKit）
    static let linearDamping: Float = 0.02
}

// MARK: - 球台物理参数（基于 CAD 图纸）
struct TablePhysics {
    /// 球台外框长度 (米) - 中式八球标准
    /// 注意：outer_size 被解释为 playfield（有效击球区域），袋口中心位于 playfield 外
    static let outerLength: Float = 2.540  // 2540mm
    
    /// 球台外框宽度 (米)
    /// 注意：outer_size 被解释为 playfield（有效击球区域），袋口中心位于 playfield 外
    static let outerWidth: Float = 1.270  // 1270mm
    
    /// 球台内部长度 (米) - playfield 尺寸（有效击球区域）
    static let innerLength: Float = outerLength  // 2.54m
    
    /// 球台内部宽度 (米) - playfield 尺寸（有效击球区域）
    static let innerWidth: Float = outerWidth  // 1.27m
    
    /// 球台高度 (米)
    static let height: Float = 0.80  // 80cm
    
    /// 库边高度 (米)
    static let cushionHeight: Float = 0.037  // 37mm
    
    /// 库边厚度 (米)
    static let cushionThickness: Float = 0.05
    
    // MARK: 袋口参数（来自 CAD）
    
    /// 角袋口直径 (米) - CAD: Ø84mm
    static let cornerPocketDiameter: Float = 0.084
    
    /// 角袋口半径 (米)
    static let cornerPocketRadius: Float = cornerPocketDiameter / 2
    
    /// 角袋圆角过渡半径 (米) - CAD: R105mm
    static let cornerPocketFilletRadius: Float = 0.105
    
    /// 中袋口直径 (米) - CAD: Ø86mm
    static let sidePocketDiameter: Float = 0.086
    
    /// 中袋口半径 (米)
    static let sidePocketRadius: Float = sidePocketDiameter / 2
    
    /// 中袋圆角过渡半径 (米) - CAD: R30mm
    static let sidePocketFilletRadius: Float = 0.030
    
    /// 中袋缺口宽度 (米) - CAD: 10mm
    static let sidePocketNotchWidth: Float = 0.010
    
    /// 兼容旧代码: 中袋直径
    static let pocketDiameter: Float = sidePocketDiameter
    
    // MARK: 袋口中心偏移量（基于 playfield 边界）
    
    /// 角袋中心 X 方向偏移量 (米) - 从 playfield 中心到角袋中心的距离
    /// 计算：innerLength/2 + cornerPocketRadius = 1.27 + 0.042 = 1.312m (符合 CAD)
    static let cornerPocketCenterOffsetX: Float = innerLength / 2 + cornerPocketRadius
    
    /// 角袋中心 Z 方向偏移量 (米) - 从 playfield 中心到角袋中心的距离
    /// 计算：innerWidth/2 + cornerPocketRadius = 0.635 + 0.042 = 0.677m (符合 CAD)
    static let cornerPocketCenterOffsetZ: Float = innerWidth / 2 + cornerPocketRadius
    
    /// 中袋中心 Z 方向偏移量 (米) - 从 playfield 中心到中袋中心的距离
    /// 使用 CAD 值：centerInnerHeight = 0.688m
    static let sidePocketCenterOffsetZ: Float = centerInnerHeight
    
    // MARK: 库边分段参数（来自 CAD）
    
    /// 角袋中心 Z 方向偏移量 (米) - CAD: left_inner_height = 677mm
    /// 注意：此值表示角袋中心在 Z 方向的偏移量，而非短边库边的直线段长度
    static let shortRailLength: Float = 0.677
    
    /// 角袋中心 X 方向偏移量 (米) - CAD: top_inner_span = 1312mm
    /// 注意：此值表示角袋中心在 X 方向的偏移量，而非完整跨度
    static let topInnerSpan: Float = 1.312
    
    /// 长边库边半段长度 (米) - 与 topInnerSpan 保持一致
    /// 注意：此值等于 topInnerSpan（角袋中心 X 方向偏移量），而非其一半
    static let longRailHalfLength: Float = topInnerSpan
    
    /// 中心处台面内部高度 (米) - CAD: 688mm
    static let centerInnerHeight: Float = 0.688
    
    // MARK: 物理系数
    
    /// 台呢摩擦系数
    static let clothFriction: Float = 0.2
    
    /// 库边弹性系数
    static let cushionRestitution: Float = 0.85
    
    /// 库边摩擦系数（球-库边接触点）
    static let cushionFriction: Float = 0.2
    
    /// 颗星数量（每边）
    static let diamondCount: Int = 4  // 每长边4颗星，每短边2颗星
    
    /// 重力加速度 (m/s^2)
    static let gravity: Float = 9.81
}

// MARK: - 旋转物理参数
struct SpinPhysics {
    /// 最大上旋速度 (rad/s)
    static let maxTopSpin: Float = 150.0
    
    /// 最大下旋速度 (rad/s)
    static let maxBackSpin: Float = 150.0
    
    /// 最大侧旋速度 (rad/s)
    static let maxSideSpin: Float = 100.0
    
    /// 自旋摩擦比例系数 (u_sp_proportionality)
    /// pooltool: 10*2/5/9 ≈ 0.444
    static let spinFrictionProportionality: Float = 10.0 * 2.0 / 5.0 / 9.0
    
    /// 旋转衰减摩擦系数 (u_sp = proportionality * R)
    /// 校准后: 0.444 * 0.028575 ≈ 0.01269
    static let spinFriction: Float = spinFrictionProportionality * BallPhysics.radius
    
    /// 滑动摩擦系数 (旋转状态)
    static let slidingFriction: Float = 0.2
    
    /// 滚动摩擦系数 (纯滚动状态)
    static let rollingFriction: Float = 0.01
    
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

// MARK: - 球杆物理参数
struct CuePhysics {
    /// 球杆质量 (kg)
    static let mass: Float = 0.567
    
    /// 皮头半径 (m)
    static let tipRadius: Float = 0.0106
    
    /// 末端等效质量 (kg) - 用于 squirt 计算
    static let endMass: Float = 0.00567
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

// MARK: - 球杆参数
struct CueStickSettings {
    /// 球杆总长度 (米)
    static let length: Float = 1.45
    
    /// 尾端半径 (米)
    static let buttRadius: Float = 0.014
    
    /// 皮头半径 (米)
    static let tipRadius: Float = 0.006
    
    /// 皮头高度 (米)
    static let tipHeight: Float = 0.012
    
    /// 皮头到母球的默认间距 (米)
    static let tipOffset: Float = 0.002
    
    /// 最大后拉距离 (米)
    static let maxPullBack: Float = 0.3
    
    /// 击球动画时长 (秒)
    static let strokeDuration: Double = 0.12
    
    /// 后拉动画时长 (秒)
    static let pullBackDuration: Double = 0.05
}

// MARK: - 第一人称相机参数
struct FirstPersonCamera {
    /// 相机到母球水平距离 (米)
    static let distance: Float = 0.6
    
    /// 相机高于台面高度 (米)
    static let height: Float = 0.45
    
    /// 最小俯仰角 (弧度，负值向下看)
    static let minPitch: Float = -0.4
    
    /// 最大俯仰角 (弧度)
    static let maxPitch: Float = -0.05
    
    /// 默认俯仰角 (弧度)
    static let defaultPitch: Float = -0.15
    
    /// 瞄准灵敏度 (弧度/像素)
    static let aimSensitivity: Float = 0.003
    
    /// 精细瞄准灵敏度 (弧度/像素)
    static let fineSensitivity: Float = 0.0006
    
    /// 相机跟随平滑系数
    static let followSmoothFactor: Float = 0.15
    
    /// 击球后相机返回第一人称的过渡时长 (秒)
    static let returnDuration: Double = 0.8
    
    /// 击球后观察视角高度 (米)
    static let postShotHeight: Float = 2.0
    
    /// 击球后观察视角与台面中心的水平距离 (米)
    static let postShotDistance: Float = 1.5
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
