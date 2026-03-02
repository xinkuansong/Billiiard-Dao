#!/usr/bin/env python3
"""运动演化测试数据生成。覆盖 sliding、rolling、spinning 各状态及多时间步。"""

from __future__ import annotations

import json
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]


def main() -> None:
    import pooltool as pt
    from pooltool.physics.evolve import evolve_ball_motion
    import pooltool.constants as const

    params = pt.BallParams.default()
    R, M, MU, G = params.R, params.m, params.u_s, params.g
    u_r, u_sp = params.u_r, params.u_sp

    output_dir = PROJECT_ROOT / "BilliardTrainerTests" / "TestData" / "evolve"
    output_dir.mkdir(parents=True, exist_ok=True)

    test_cases = []
    for state, state_name in [(const.sliding, "sliding"), (const.rolling, "rolling"), (const.spinning, "spinning")]:
        rvw = pt.Ball.create("1", xy=(0.5, 0.5)).state.rvw.copy()
        if state == const.sliding:
            rvw[1] = [1.0, 0, 0]
        elif state == const.rolling:
            rvw[1] = [1.0, 0, 0]
            rvw[2] = [0, 0, 1.0 / R]
        else:
            rvw[1] = [0, 0, 0]
            rvw[2] = [0, 0, 10.0]

        for dt in [0.01, 0.05]:
            rvw_in = [[float(x) for x in row] for row in rvw]
            rvw_out, s_out = evolve_ball_motion(state, rvw.copy(), R, M, MU, u_sp, u_r, G, float(dt))
            test_cases.append({
                "id": f"ev_{state_name}_{int(dt*1000)}",
                "input": {"state": int(state), "rvw": rvw_in, "R": R, "m": M, "u_s": MU, "u_sp": u_sp, "u_r": u_r, "g": G, "t": dt},
                "expected": {"rvw": [[float(x) for x in row] for row in rvw_out], "state": int(s_out)},
            })

    out_path = output_dir / "evolve.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump({
            "module": "evolve",
            "source": "pooltool physics.evolve.evolve_ball_motion",
            "tolerance": {"abs": 1e-4, "rel": 1e-2},
            "test_cases": test_cases,
        }, f, indent=2, ensure_ascii=False)
    print(f"Exported {len(test_cases)} cases -> {out_path.relative_to(PROJECT_ROOT)}")


if __name__ == "__main__":
    main()
