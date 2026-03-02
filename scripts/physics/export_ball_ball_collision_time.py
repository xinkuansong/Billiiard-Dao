#!/usr/bin/env python3
"""
球-球碰撞时间测试数据生成脚本

调用 pooltool.evolution.event_based.solve.ball_ball_collision_time 生成 ground truth。
覆盖各角度、速度、滚动/滑动/旋转状态组合。
坐标系：pooltool xy 平面，需标注 coordinate_system。

用法:
  cd <project_root>
  source .venv/bin/activate
  python scripts/physics/export_ball_ball_collision_time.py

输出: BilliardTrainerTests/TestData/ball_ball_collision_time/ball_ball_collision_time.json
"""

from __future__ import annotations

import json
import math
import sys
from pathlib import Path

import numpy as np

PROJECT_ROOT = Path(__file__).resolve().parents[2]
# Use pooltool from .venv (pip install pooltool-billiards). Do NOT add pooltool-main
# to path - the local copy may have extra deps like quaternion not in published package.

import pooltool.constants as const
from pooltool.evolution.event_based.solve import ball_ball_collision_time
from pooltool.objects.ball.params import BallParams

R = BallParams.default().R
M = BallParams.default().m
MU = BallParams.default().u_s
G = BallParams.default().g


def make_rvw(x: float, y: float, vx: float, vy: float, wx: float = 0, wy: float = 0, wz: float = 0) -> list:
    """Create rvw array: [[rx,ry,rz], [vx,vy,vz], [wx,wy,wz]]."""
    return [
        [x, y, R],
        [vx, vy, 0.0],
        [wx, wy, wz],
    ]


def main() -> None:
    output_dir = PROJECT_ROOT / "BilliardTrainerTests" / "TestData" / "ball_ball_collision_time"
    output_dir.mkdir(parents=True, exist_ok=True)

    test_cases = []
    case_id = 0

    # State combinations: sliding=2, rolling=3, spinning=1, stationary=0
    state_pairs = [
        (const.sliding, const.sliding),
        (const.sliding, const.rolling),
        (const.rolling, const.rolling),
        (const.rolling, const.stationary),
        (const.sliding, const.stationary),
    ]

    for s1, s2 in state_pairs:
        for angle_deg in [0, 15, 45, 90, 135]:
            angle = math.radians(angle_deg)
            v1 = 2.0
            v2 = 0.0 if s2 in (const.stationary, const.spinning) else 1.0
            dx = 0.15
            dy = 0.05 if angle_deg != 0 else 0

            rvw1 = make_rvw(0, 0, v1 * math.cos(angle), v1 * math.sin(angle))
            rvw2 = make_rvw(dx, dy, v2 * math.cos(angle + math.pi), v2 * math.sin(angle + math.pi))

            try:
                t = ball_ball_collision_time(
                    np.array(rvw1),
                    np.array(rvw2),
                    s1, s2,
                    MU, MU, M, M, G, G,
                    R,
                )
                no_collision = bool(np.isinf(t) or t <= 0)
                collision_time = None if no_collision else float(t)
            except Exception:
                no_collision = True
                collision_time = None

            case_id += 1
            test_cases.append({
                "id": f"bbct_{case_id:04d}",
                "input": {
                    "rvw1": rvw1,
                    "rvw2": rvw2,
                    "s1": int(s1),
                    "s2": int(s2),
                    "mu1": MU, "mu2": MU,
                    "m1": M, "m2": M,
                    "g1": G, "g2": G,
                    "R": R,
                },
                "expected": {
                    "collision_time": collision_time,
                    "no_collision": no_collision,
                },
            })

    out = {
        "module": "ball_ball_collision_time",
        "source": "pooltool solve.ball_ball_collision_time",
        "coordinate_system": "pooltool_xy",
        "tolerance": {"abs": 1e-5, "rel": 1e-3},
        "test_cases": test_cases,
    }

    out_path = output_dir / "ball_ball_collision_time.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out, f, indent=2, ensure_ascii=False)
    print(f"Exported {len(test_cases)} cases -> {out_path.relative_to(PROJECT_ROOT)}")


if __name__ == "__main__":
    main()
