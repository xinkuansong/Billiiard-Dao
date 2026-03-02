# 验证需求文档

## 验证描述 (Input)

验证并修复现有的物理引擎。将 BilliardTrainer (Swift) 物理引擎与 pooltool-main (Python) 参考实现进行系统性对照，通过自动化测试与真机测试双通道覆盖所有物理模块，发现偏差并修复，确保两者行为一致。

## 验证范围
<!-- Will be analyzed in /kiro/spec-requirements phase -->

### 目标物理模块
<!-- Swift 文件 → pooltool 参考 映射 -->

| Swift 模块 | 文件 | pooltool 参考 |
|------------|------|---------------|
| 四次方程求解 | QuarticSolver.swift | ptmath/roots/quartic.py |
| 碰撞检测 | CollisionDetector.swift | evolution/event_based/solve.py |
| 碰撞响应 | CollisionResolver.swift | physics/resolve/ball_ball/ |
| 库边碰撞 | CushionCollisionModel.swift | physics/resolve/ball_cushion/ |
| 解析运动 | AnalyticalMotion.swift | 状态公式 |
| 事件驱动 | EventDrivenEngine.swift | evolution/event_based/simulate.py |
| 球杆击球 | CueBallStrike.swift | physics/resolve/ball_stick/ |

### 测试通道规划
<!-- 自动化 / 真机 分类 -->

- **自动化**: 纯计算函数（碰撞时间、四次方程、碰撞响应、运动演化）、数值输出与 Python 比对
- **真机**: 轨迹渲染、碰撞视觉效果、库边反弹、袋口行为、旋转弧线、帧率

## Requirements
<!-- Will be generated in /kiro/spec-requirements phase -->
