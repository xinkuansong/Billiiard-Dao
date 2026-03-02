#!/usr/bin/env python3
"""球-圆弧库边碰撞时间测试数据生成。覆盖袋口附近入射场景。"""

from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np

PROJECT_ROOT = Path(__file__).resolve().parents[2]


def solve_circular_cushion_collision_time(
    rvw: np.ndarray, s: int, a: float, b: float, r: float,
    mu: float, m: float, g: float, R: float
) -> float | None:
    """用 ball_circular_cushion_collision_coeffs 求解四次方程，返回最小正实根。

    ball_circular_cushion_collision_time 在 pooltool 0.5.0 中未导出，
    故手动求解：返回 None 表示无碰撞（无正实根）。
    """
    from pooltool.evolution.event_based.solve import ball_circular_cushion_collision_coeffs
    A, B, C, D, E = ball_circular_cushion_collision_coeffs(rvw, s, a, b, r, mu, m, g, R)
    if not np.isfinite(A):
        return None
    roots = np.roots([A, B, C, D, E])
    candidates = [
        r.real for r in roots
        if abs(r.imag) < 1e-6 and r.real > 1e-9 and np.isfinite(r.real)
    ]
    return float(min(candidates)) if candidates else None


def main() -> None:
    import pooltool as pt
    import pooltool.constants as const

    params = pt.BallParams.default()
    R, M, MU, G = params.R, params.m, params.u_s, params.g

    output_dir = PROJECT_ROOT / "BilliardTrainerTests" / "TestData" / "ball_circular_cushion_time"
    output_dir.mkdir(parents=True, exist_ok=True)

    # Get circular cushion from table (pocket jaws)
    table = pt.Table.default()
    circular = list(getattr(getattr(table, "cushion_segments", None), "circular", {}).values())
    if not circular:
        a, b, r = 0.05, 0.05, 0.06
    else:
        c = circular[0]
        a, b = float(c.center[0]), float(c.center[1])
        r = float(c.radius)

    test_cases = []
    for i, angle_deg in enumerate([20, 45, 70]):
        angle = math.radians(angle_deg)
        v = 1.5
        bx = a + (r + R + 0.02) * math.cos(angle)
        by = b + (r + R + 0.02) * math.sin(angle)
        vx = -v * math.cos(angle)
        vy = -v * math.sin(angle)
        rvw = np.array([[bx, by, R], [vx, vy, 0.0], [0.0, 0.0, 0.0]])

        t = solve_circular_cushion_collision_time(rvw, int(const.sliding), a, b, r, MU, M, G, R)
        no_collision = t is None
        collision_time = t
        print(f"  bcct_{i+1:04d} angle={angle_deg}°: t={t}")

        test_cases.append({
            "id": f"bcct_{i+1:04d}",
            "input": {"rvw": rvw.tolist(), "s": int(const.sliding), "a": a, "b": b, "r": r, "mu": MU, "m": M, "g": G, "R": R},
            "expected": {"collision_time": collision_time, "no_collision": no_collision},
        })

    out_path = output_dir / "ball_circular_cushion_time.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump({
            "module": "ball_circular_cushion_time",
            "source": "pooltool solve.ball_circular_cushion_collision_time",
            "coordinate_system": "pooltool_xy",
            "tolerance": {"abs": 1e-5, "rel": 1e-3},
            "test_cases": test_cases,
        }, f, indent=2, ensure_ascii=False)
    print(f"Exported {len(test_cases)} cases -> {out_path.relative_to(PROJECT_ROOT)}")


if __name__ == "__main__":
    main()
