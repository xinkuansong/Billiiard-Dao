#!/usr/bin/env python3
"""球杆击球测试数据生成。覆盖各 tip offset、力度组合。"""

from __future__ import annotations

import json
import math
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]


def main() -> None:
    import pooltool as pt
    from pooltool.physics.resolve.stick_ball.instantaneous_point import cue_strike
    from pooltool.physics.resolve.stick_ball.squirt import get_squirt_angle

    params = pt.BallParams.default()
    R, M = params.R, params.m
    cue = pt.Cue.default()
    cue_M = cue.specs.M if hasattr(cue.specs, "M") else cue.specs.end_mass

    output_dir = PROJECT_ROOT / "BilliardTrainerTests" / "TestData" / "cue_strike"
    output_dir.mkdir(parents=True, exist_ok=True)

    test_cases = []
    for i, (a, b, c, V0) in enumerate([
        (0, 0, 1, 2.0),
        (0.1, 0, 1, 2.0),
        (0.05, 0.5, 0.8, 1.5),
    ]):
        Q = [a, c, b]
        phi_deg, theta_deg = 0, 0
        squirt = get_squirt_angle(M, cue_M, a, throttle=1.0)
        v, w = cue_strike(M, cue_M, R, V0, phi_deg, theta_deg, Q)
        rvw_after = [[0.5, 0.5, R], [float(v[0]), float(v[1]), float(v[2])], [float(w[0]), float(w[1]), float(w[2])]]
        test_cases.append({
            "id": f"cs_{i+1:04d}",
            "input": {"V0": V0, "phi": phi_deg, "theta": theta_deg, "Q": Q, "R": R, "m": M, "cue_m": cue_M},
            "expected": {"squirt": float(squirt), "rvw_after": rvw_after},
        })

    out_path = output_dir / "cue_strike.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump({
            "module": "cue_strike",
            "source": "pooltool stick_ball/instantaneous_point.cue_strike",
            "tolerance": {"abs": 1e-4, "rel": 1e-2},
            "test_cases": test_cases,
        }, f, indent=2, ensure_ascii=False)
    print(f"Exported {len(test_cases)} cases -> {out_path.relative_to(PROJECT_ROOT)}")


if __name__ == "__main__":
    main()
