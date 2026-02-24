# 任务列表：瞄准系统 (Aiming System)

**输入**：`/specs/3-aiming-system/` 设计文档  
**状态**：已完成 (回溯记录)

## 格式说明

- **[P]**：可并行执行（不同文件、无依赖）
- **[Story]**：所属用户故事（US1, US2, US3, US4）
- 任务格式：`[x] 已完成`

---

## Phase 1：瞄准核心

- [x] T001 [US1] 创建 AimingCalculator，实现 calculateAim(cueBall, targetBall, pocket)
- [x] T002 [US1] 实现幽灵球位置计算 ghostBallCenter(objectBall, pocket)
- [x] T003 [US1] 实现厚度计算 calculateThickness(cueToBall, ballToPocket)
- [x] T004 [US2] 实现分离角计算 calculateSeparationAngle(thickness, spinY)
- [x] T005 [US2] 实现母球停止位置预测 predictCueBallPosition

---

## Phase 2：瞄准结果与辅助

- [x] T006 [US1] 定义 AimResult 结构体（aimPoint, aimDirection, thickness, separationAngle, canPocket, difficulty）
- [x] T007 [US2] 实现可进袋判断 checkCanPocket
- [x] T008 [US2] 实现难度评分 calculateDifficulty
- [x] T009 [US1] 实现路径遮挡检测 isPathOccluded

---

## Phase 3：塞与 Squirt 修正

- [x] T010 [US4] 集成 CueBallStrike.squirtAngle，在 calculateAim 中应用 squirt 角修正
- [x] T011 [US4] 对 aimDirection 绕 Y 轴旋转以补偿 squirt

---

## Phase 4：颗星公式

- [x] T012 [US3] 创建 DiamondSystemCalculator，定义 DiamondPosition、TableEdge、DiamondResult
- [x] T013 [US3] 实现 positionToDiamond、nearestEdge、pocketEdge、oppositeEdge 辅助函数
- [x] T014 [US3] 实现一库翻袋 calculateOneRailBank
- [x] T015 [US3] 实现两库 K 球 calculateTwoRailKick
- [x] T016 [US3] 实现三库路径 calculateThreeRailPath（简化版）

---

## Phase 5：颗星修正

- [x] T017 [US4] 实现塞修正 calculateEnglishCorrection(startDiamond, targetDiamond)
- [x] T018 [US4] 实现速度修正 calculateSpeedCorrection(power)

---

## 验收检查点

- [x] 幽灵球与瞄准线计算正确
- [x] 分离角与走位预测可用
- [x] 一库、两库颗星公式可用
- [x] 塞与速度修正已集成
