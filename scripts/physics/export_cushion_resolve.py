#!/usr/bin/env python3
"""库边碰撞响应测试数据生成。覆盖各入射角、速度。"""

from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np

PROJECT_ROOT = Path(__file__).resolve().parents[2]


def _compute_model_rotation(vel_in: np.ndarray, cushion_normal_2d: np.ndarray):
    """计算将全局速度映射到 Mathavan 模型坐标系的旋转角（与 solve_mathavan 完全一致）。

    模型坐标系：x 轴沿库边切线，y 轴沿库边法线（正值 = 趋近库边）。

    Returns
    -------
    (cos_angle, sin_angle) — 用于对 XY 分量做 2D 旋转
    """
    nx, ny = float(cushion_normal_2d[0]), float(cushion_normal_2d[1])
    # 确保法线与球运动方向同向（趋近 = 正 vy），与 pooltool 保持一致
    if nx * vel_in[0] + ny * vel_in[1] <= 0:
        nx, ny = -nx, -ny

    psi = math.atan2(ny, nx)
    angle = math.pi / 2 - psi
    return math.cos(angle), math.sin(angle)


def _apply_rotation(vel: np.ndarray, omega: np.ndarray, c: float, s: float):
    """对速度和角速度应用相同的 2D XY 旋转（Z 分量不变）。"""
    vx_rot = c * float(vel[0]) - s * float(vel[1])
    vy_rot = s * float(vel[0]) + c * float(vel[1])
    ox_rot = c * float(omega[0]) - s * float(omega[1])
    oy_rot = s * float(omega[0]) + c * float(omega[1])
    oz_rot = float(omega[2])
    return vx_rot, vy_rot, ox_rot, oy_rot, oz_rot


def main() -> None:
    import pooltool as pt
    from pooltool.physics.resolve.ball_cushion.mathavan_2010.model import (
        Mathavan2010Linear,
        solve as mathavan_solve,
    )

    output_dir = PROJECT_ROOT / "BilliardTrainerTests" / "TestData" / "cushion_resolve"
    output_dir.mkdir(parents=True, exist_ok=True)

    table = pt.Table.default()
    cushions = list(table.cushion_segments.linear.values())
    if not cushions:
        print("No linear cushions; skipping cushion_resolve export")
        return

    model = Mathavan2010Linear()
    test_cases = []
    for i, angle_deg in enumerate([30, 60, 80]):
        ball = pt.Ball.create("1")
        ball.state.rvw[0] = [1.0, 0.2, ball.params.R]
        v = 2.0
        angle = math.radians(angle_deg)
        ball.state.rvw[1] = [-v * math.cos(angle), -v * math.sin(angle), 0]
        ball.state.rvw[2] = [0.0, 0.0, 0.0]
        ball.state.s = 2

        rvw_before = [[float(x) for x in row] for row in ball.state.rvw.copy()]
        cushion = cushions[0]

        # 获取库边法线（2D XY 平面）
        cushion_normal = cushion.get_normal(ball.state.rvw)
        cushion_normal_2d = np.array([float(cushion_normal[0]), float(cushion_normal[1])])

        # 物理参数（与 pooltool 使用值一致）
        params = {
            "R": float(ball.params.R),
            "M": float(ball.params.m),
            "h": float(cushion.height),
            "ee": float(ball.params.e_c),
            "mu_s": float(ball.params.u_s),
            "mu_w": float(ball.params.f_c),
        }

        # 计算模型坐标系旋转矩阵（仅依赖输入速度方向，输出用同一旋转）
        vel_in = ball.state.rvw[1].copy()
        omega_in = ball.state.rvw[2].copy()
        c, s = _compute_model_rotation(vel_in, cushion_normal_2d)
        model_in = _apply_rotation(vel_in, omega_in, c, s)

        model.resolve(ball, cushion, inplace=True)
        rvw_after = [[float(x) for x in row] for row in ball.state.rvw]

        # 期望输出：直接调用 pooltool solve()（精细参数 max_steps=5000, delta_p=1e-4），
        # 与 Swift CushionCollisionModel.solve 使用相同的数值积分精度，避免因步长差异引入误差。
        # Mathavan2010Linear.resolve() 默认 max_steps=1000, delta_p=0.001（较粗糙），
        # Swift 实现使用 maxSteps=5000, deltaP=0.0001（更精细）。
        vx_exp, vy_exp, ox_exp, oy_exp, oz_exp = mathavan_solve(
            float(params["M"]), float(params["R"]), float(params["h"]),
            float(params["ee"]), float(params["mu_s"]), float(params["mu_w"]),
            model_in[0], model_in[1], model_in[2], model_in[3], model_in[4],
            max_steps=5000, delta_p=1e-4,
        )
        model_exp = (vx_exp, vy_exp, ox_exp, oy_exp, oz_exp)

        test_cases.append({
            "id": f"cr_{i+1:04d}",
            "input": {
                "rvw": rvw_before,
                "cushion_id": cushion.id,
                "cushion_normal_2d": [float(cushion_normal_2d[0]), float(cushion_normal_2d[1])],
            },
            "expected": {
                "rvw": rvw_after,
            },
            "mathavan_model": {
                "params": params,
                "input": {
                    "vx": model_in[0],
                    "vy": model_in[1],
                    "omega_x": model_in[2],
                    "omega_y": model_in[3],
                    "omega_z": model_in[4],
                },
                "expected": {
                    "vx": model_exp[0],
                    "vy": model_exp[1],
                    "omega_x": model_exp[2],
                    "omega_y": model_exp[3],
                    "omega_z": model_exp[4],
                },
            },
        })

    out_path = output_dir / "cushion_resolve.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump({
            "module": "cushion_resolve",
            "source": "pooltool physics/resolve/ball_cushion/mathavan_2010",
            "tolerance": {"abs": 1e-4, "rel": 1e-2},
            "test_cases": test_cases,
        }, f, indent=2, ensure_ascii=False)
    print(f"Exported {len(test_cases)} cases -> {out_path.relative_to(PROJECT_ROOT)}")


if __name__ == "__main__":
    main()
