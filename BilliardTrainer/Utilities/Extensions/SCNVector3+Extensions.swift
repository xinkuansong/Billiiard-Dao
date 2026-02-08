//
//  SCNVector3+Extensions.swift
//  BilliardTrainer
//
//  SCNVector3 向量运算扩展（被物理引擎广泛依赖）
//

import SceneKit

extension SCNVector3 {
    /// 向量长度
    func length() -> Float {
        return sqrt(x * x + y * y + z * z)
    }
    
    /// 归一化
    func normalized() -> SCNVector3 {
        let len = length()
        guard len > 0 else { return self }
        return SCNVector3(x / len, y / len, z / len)
    }
    
    /// 点积
    func dot(_ other: SCNVector3) -> Float {
        return x * other.x + y * other.y + z * other.z
    }
    
    /// 叉积
    func cross(_ other: SCNVector3) -> SCNVector3 {
        return SCNVector3(
            y * other.z - z * other.y,
            z * other.x - x * other.z,
            x * other.y - y * other.x
        )
    }
    
    /// 向量加法
    static func + (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        return SCNVector3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }
    
    /// 向量减法
    static func - (lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
        return SCNVector3(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }
    
    /// 标量乘法
    static func * (lhs: SCNVector3, rhs: Float) -> SCNVector3 {
        return SCNVector3(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
    }
    
    /// 前缀取反
    static prefix func - (vector: SCNVector3) -> SCNVector3 {
        return SCNVector3(-vector.x, -vector.y, -vector.z)
    }
    
    /// 标量除法
    static func / (lhs: SCNVector3, rhs: Float) -> SCNVector3 {
        return SCNVector3(lhs.x / rhs, lhs.y / rhs, lhs.z / rhs)
    }
    
    /// 绕 Y 轴旋转
    func rotatedY(_ angle: Float) -> SCNVector3 {
        let cosA = cosf(angle)
        let sinA = sinf(angle)
        return SCNVector3(x * cosA - z * sinA, y, x * sinA + z * cosA)
    }
}
