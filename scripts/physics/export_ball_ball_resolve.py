#!/usr/bin/env python3
"""球-球碰撞响应测试数据生成。覆盖正碰、掠碰、静止球被撞。"""

from __future__ import annotations

import json
import math
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]


def main() -> None:
    import pooltool as pt
    from pooltool.physics.resolve.ball_ball import FrictionalInelastic

    R = pt.BallParams.default().R
    resolver = FrictionalInelastic()

    output_dir = PROJECT_ROOT / "BilliardTrainerTests" / "TestData" / "ball_ball_resolve"
    output_dir.mkdir(parents=True, exist_ok=True)

    test_cases = []
    for i, (offset, v1, v2) in enumerate([
        (0.0, 2.0, 0.0),
        (0.01, 2.0, 0.0),
        (0.02, 1.5, 0.5),
    ]):
        b1 = pt.Ball.create("1", xy=(0, 0))
        b2 = pt.Ball.create("2", xy=(0.2 + offset, 0))
        b1.state.rvw[1] = [v1, 0, 0]
        b2.state.rvw[1] = [-v2, 0, 0]
        b1.state.s = 2
        b2.state.s = 0 if v2 == 0 else 2

        rvw1_before = [[float(x) for x in row] for row in b1.state.rvw]
        rvw2_before = [[float(x) for x in row] for row in b2.state.rvw]

        resolver.resolve(b1, b2, inplace=True)

        rvw1_after = [[float(x) for x in row] for row in b1.state.rvw]
        rvw2_after = [[float(x) for x in row] for row in b2.state.rvw]

        test_cases.append({
            "id": f"bbr_{i+1:04d}",
            "input": {"rvw1": rvw1_before, "rvw2": rvw2_before, "R": R},
            "expected": {"rvw1": rvw1_after, "rvw2": rvw2_after},
        })

    out_path = output_dir / "ball_ball_resolve.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump({
            "module": "ball_ball_resolve",
            "source": "pooltool physics/resolve/ball_ball",
            "tolerance": {"abs": 1e-4, "rel": 1e-2},
            "test_cases": test_cases,
        }, f, indent=2, ensure_ascii=False)
    print(f"Exported {len(test_cases)} cases -> {out_path.relative_to(PROJECT_ROOT)}")


if __name__ == "__main__":
    main()
