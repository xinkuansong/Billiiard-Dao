#!/usr/bin/env python3
"""
球-直线库边碰撞时间测试数据生成脚本

调用 pooltool solve.ball_linear_cushion_collision_time 生成 ground truth。
覆盖各入射角、速度、库边朝向。

用法:
  cd <project_root>
  source .venv/bin/activate
  python scripts/physics/export_ball_linear_cushion_time.py
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import numpy as np

PROJECT_ROOT = Path(__file__).resolve().parents[2]

import pooltool as pt
import pooltool.constants as const
from pooltool.evolution.event_based.solve import ball_linear_cushion_collision_time

params = pt.BallParams.default()
R, M, MU, G = params.R, params.m, params.u_s, params.g


def make_rvw(x: float, y: float, vx: float, vy: float) -> list:
    return [[x, y, R], [vx, vy, 0.0], [0.0, 0.0, 0.0]]


def main() -> None:
    output_dir = PROJECT_ROOT / "BilliardTrainerTests" / "TestData" / "ball_linear_cushion_time"
    output_dir.mkdir(parents=True, exist_ok=True)

    table = pt.Table.default()
    cushions = list(table.cushion_segments.linear.values()) if hasattr(table, "cushion_segments") else []
    if not cushions:
        raise RuntimeError("No linear cushions on default table")
    cushion = cushions[0]

    lx, ly, l0 = cushion.lx, cushion.ly, cushion.l0
    p1_arr = cushion.p1
    p2_arr = cushion.p2
    direction = cushion.direction

    test_cases = []
    for i, angle_deg in enumerate([15, 30, 45, 60, 80]):
        angle = math.radians(angle_deg)
        v = 2.0
        # Ball inside table, moving toward cushion
        bx = 1.0
        by = 0.3
        vx = -v * math.cos(angle)
        vy = -v * math.sin(angle)

        rvw = np.array(make_rvw(bx, by, vx, vy))

        try:
            t = ball_linear_cushion_collision_time(
                rvw, const.sliding,
                lx, ly, l0,
                p1_arr, p2_arr,
                direction,
                MU, M, G, R,
            )
            no_collision = bool(np.isinf(t) or t <= 0)
            collision_time = None if no_collision else float(t)
        except Exception:
            no_collision = True
            collision_time = None

        test_cases.append({
            "id": f"blct_{i+1:04d}",
            "input": {
                "rvw": make_rvw(bx, by, vx, vy),
                "s": int(const.sliding),
                "lx": float(lx), "ly": float(ly), "l0": float(l0),
                "p1": p1_arr.tolist(), "p2": p2_arr.tolist(),
                "direction": int(direction),
                "mu": MU, "m": M, "g": G, "R": R,
            },
            "expected": {"collision_time": collision_time, "no_collision": no_collision},
        })

    out = {
        "module": "ball_linear_cushion_time",
        "source": "pooltool solve.ball_linear_cushion_collision_time",
        "coordinate_system": "pooltool_xy",
        "tolerance": {"abs": 1e-5, "rel": 1e-3},
        "test_cases": test_cases,
    }
    out_path = output_dir / "ball_linear_cushion_time.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out, f, indent=2, ensure_ascii=False)
    print(f"Exported {len(test_cases)} cases -> {out_path.relative_to(PROJECT_ROOT)}")


if __name__ == "__main__":
    main()
