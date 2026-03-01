# Utilities - 设计与约束

> 对应 README：[README.md](./README.md)
> 文档最后更新：2026-02-27

## 设计目标与非目标

- **目标**：集中管理物理常量，确保单位统一（SI 单位），提供通用扩展与向量运算支持
- **非目标**：不处理业务逻辑，不管理状态，不处理错误恢复

## 不变量与约束（改动护栏）

### 单位与坐标系

- **所有物理常量必须使用 SI 单位**：长度（米 m）、质量（千克 kg）、时间（秒 s）、角度（弧度 rad）
- **重力加速度必须为 9.81 m/s²**：必须与 pooltool 参考实现保持一致
- **SceneKit 坐标系**：Y-up，与物理引擎的 Z-up 坐标系需要转换（转换逻辑在 Scene 模块）

### 数值稳定性保护

- **spinFriction 计算公式**：`spinFriction = spinFrictionProportionality * BallPhysics.radius`，必须保持此公式，不可硬编码
- **normalized() 零向量保护**：`SCNVector3.normalized()` 必须检查长度 > 0，零向量返回自身，避免除零错误
- **除法保护**：所有涉及除法的扩展（如百分比转换）应检查分母，但当前实现未完全保护（建议添加）

### 时序与状态约束

- 物理常量在编译时确定，无运行时状态依赖
- SCNVector3 扩展方法为纯函数，无副作用
- Extensions 的 View 样式方法返回新 View，不修改原 View

### 常量与阈值清单

| 常量/阈值 | 值 | 来源/理由 | 改动影响 |
|-----------|-----|----------|----------|
| BallPhysics.diameter | 0.05715m (57.15mm) | 标准台球直径 | 变更会影响所有球体计算 |
| BallPhysics.mass | 0.170kg (170g) | 标准台球质量 | 变更会影响物理计算 |
| BallPhysics.restitution | 0.95 | 球-球弹性系数 | 变更会影响碰撞反弹 |
| TablePhysics.gravity | 9.81 m/s² | 标准重力加速度，必须与 pooltool 一致 | 变更会影响物理计算，必须与参考实现对照 |
| TablePhysics.outerLength | 2.54m | 中式八球标准尺寸 | 变更会影响球台尺寸 |
| TablePhysics.outerWidth | 1.27m | 中式八球标准尺寸 | 变更会影响球台尺寸 |
| SpinPhysics.spinFrictionProportionality | 0.444 (10*2/5/9) | pooltool 参考：u_sp_proportionality | 变更会影响旋转摩擦计算，必须与参考实现对照 |
| SpinPhysics.spinFriction | 0.01269 (proportionality * radius) | 计算公式，不可硬编码 | 变更会影响旋转摩擦计算 |
| StrokePhysics.maxVelocity | 6.5 m/s | 击球最大速度 | 变更会影响击球力度 |
| StrokePhysics.powerGamma | 1.8 | 幂函数指数 | 变更会影响力度曲线 |
| StrokePhysics.deadZone | 2.0 | 力度条死区 | 变更会影响轻触检测 |

## 状态机 / 事件模型

无状态机（Utilities 模块为静态工具类）。

## 错误处理与降级策略

- **向量归一化零向量**：`normalized()` 返回自身，避免除零错误
- **数组安全下标**：`Array[safe:]` 返回可选值，避免越界崩溃
- **物理常量错误**：编译时确定，无运行时错误处理（如值错误需修复代码）

## 性能考量

- 物理常量使用 `static let`，编译时确定，无运行时开销
- SCNVector3 扩展方法为内联函数，性能开销小
- Extensions 的 View 样式方法可能触发 View 重建，但影响可控

## 参考实现对照（如适用）

| Swift 文件/函数 | pooltool 对应 | 偏离说明 |
|----------------|--------------|----------|
| TablePhysics.gravity | pooltool 物理常量 | 必须保持一致：9.81 m/s² |
| SpinPhysics.spinFrictionProportionality | pooltool: 10*2/5/9 ≈ 0.444 | 必须保持一致 |
| SpinPhysics.spinFriction | pooltool: u_sp = proportionality * R | 必须使用公式计算，不可硬编码 |
| BallPhysics.diameter/mass/restitution | pooltool 球体参数 | 建议保持一致，但允许根据实际需求调整 |

## 设计决策记录（ADR）

### 集中管理物理常量而非分散定义
- **背景**：物理引擎需要大量常量，分散定义难以维护
- **候选方案**：集中管理（当前）、分散到各模块、配置文件
- **结论**：集中管理便于维护与对照参考实现，确保单位统一
- **后果**：PhysicsConstants.swift 文件较大，但结构清晰，影响可控

### 使用 SI 单位而非 SceneKit 单位
- **背景**：物理计算需要标准单位，SceneKit 单位不明确
- **候选方案**：SI 单位（当前）、SceneKit 单位、自定义单位
- **结论**：SI 单位便于对照参考实现（pooltool），确保物理计算正确
- **后果**：需要在 SceneKit 渲染时进行单位转换，但转换逻辑集中，影响可控

### spinFriction 使用公式计算而非硬编码
- **背景**：spinFriction 依赖于球半径，硬编码不利于维护
- **候选方案**：公式计算（当前）、硬编码、配置化
- **结论**：公式计算确保值与参考实现一致，便于维护
- **后果**：每次访问都重新计算，但计算简单，性能影响可忽略

### SCNVector3 扩展提供运算符重载
- **背景**：向量运算频繁，需要简洁的语法
- **候选方案**：运算符重载（当前）、方法调用、全局函数
- **结论**：运算符重载语法最简洁，符合 Swift 习惯
- **后果**：可能与其他库冲突，但 SceneKit 场景下冲突概率低
