# 全量自动化测试结果（Task 2.11）

## 执行信息

- **执行时间**: 2026-03-02 23:41 ~ 23:45 (约 4 分 30 秒)
- **设备**: iPhone 17 Pro Simulator
- **Scheme**: BilliardTrainer
- **xcodebuild 退出码**: TEST FAILED（因含已知偏差项）
- **结果 Bundle**: `test-results/automated/TestResults.xcresult`

## 汇总

| 指标 | 数值 |
|------|------|
| 总测试用例数 | 292 |
| **通过 (PASS)** | **289** |
| **失败 (FAIL)** | **3** |
| 测试套件数 | 24 |

## 失败测试用例（均为已知偏差，见 tasks.md）

| 测试用例 | 所属套件 | 耗时 | 根因（参考 tasks.md）|
|----------|----------|------|----------------------|
| `testPooltoolBallBallResolveBaseline()` | CollisionResolverTests | 0.638 s | 正碰时法向 v_rel 错误纳入摩擦计算（task 2.5）|
| `testCoreFixturesAgainstPooltoolBaselines()` | CrossEngineComparisonTests | 0.133 s | CollisionResolver 摩擦 bug 导致轨迹发散（task 2.10）|
| `testPooltoolCueStrikeBaseline()` | CueBallStrikeTests | 0.009 s | 尖端半径校正/角速度符号/squirt 质量参数不一致（task 2.9）|

## 通过套件明细

| 测试套件 | 用例数 | 状态 |
|----------|--------|------|
| AimingSystemTests | 19 | ✅ ALL PASS |
| AnalyticalMotionTests | 18 | ✅ ALL PASS（含 pooltool evolve + transition time baseline）|
| BilliardSceneCameraTests | 13 | ✅ ALL PASS |
| BilliardTrainerTests | 2 | ✅ ALL PASS |
| CameraViewModelTests | 20 | ✅ ALL PASS |
| CollisionDetectorTests | 15 | ✅ ALL PASS（含 ball-ball / linear / circular cushion baseline）|
| CollisionResolverTests | 10+1 | ⚠️ 10 PASS / 1 FAIL |
| CourseProgressTests | 4 | ✅ ALL PASS |
| CrossEngineComparisonTests | 1 | ⚠️ 1 FAIL（见 task 2.10 偏差汇总）|
| CueBallStrikeTests | 14+1 | ⚠️ 14 PASS / 1 FAIL |
| CushionCollisionModelTests | 7 | ✅ ALL PASS（含 pooltool cushion resolve baseline）|
| DiamondSystemTests | 11 | ✅ ALL PASS |
| EventDrivenEngineTests | 12 | ✅ ALL PASS |
| GameRulesTests | 13 | ✅ ALL PASS |
| PhysicsRegressionTests | 9 | ✅ ALL PASS |
| PhysicsStabilityPerformanceTests | 2 | ✅ ALL PASS |
| QuarticSolverTests | 14 | ✅ ALL PASS（含 1010_reference / quartic_coeffs / fallback baseline）|
| TableGeometryTests | 18 | ✅ ALL PASS |
| TrainingConfigTests | 24 | ✅ ALL PASS |
| TrainingSessionTests | 5 | ✅ ALL PASS |
| TrainingViewModelTests | 15 | ✅ ALL PASS |
| TrajectoryPlaybackTests | 4 | ✅ ALL PASS |
| UserProfileTests | 11 | ✅ ALL PASS |
| UserStatisticsTests | 13 | ✅ ALL PASS |

## 结论

- 全量测试 **289/292 通过（98.97%）**，3 个失败均为 task 2.5/2.9/2.10 中已明确记录的已知偏差。
- 所有新增 pooltool 基线测试（四次方程、球-球时间、直线/圆弧库边时间、运动演化、状态转换时间、库边碰撞响应）**全部通过**。
- 3 个已知失败项待 task 5.1（修复 CollisionResolver 摩擦 bug、CueBall 参数对齐）完成后重跑验证。

## 待修复项（指向 task 5.1）

1. **CollisionResolver 摩擦修复**：正碰时仅对切向 v_rel 施加摩擦，去除法向分量误纳入。
2. **CueBall 击球参数对齐**：
   - 明确是否保留尖端半径校正（tipR=0.0106 m）或改用 pooltool 原始 Q 模式
   - 确认角速度符号约定（正 a 侧方向定义）
   - Squirt 公式中 squirtMass 参数：CuePhysics.endMass vs 完整杆质量
