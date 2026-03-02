#!/usr/bin/env python3
"""状态转换时间测试数据生成。覆盖 slideToRoll、rollToSpin、spinToStationary。"""

from __future__ import annotations

import json
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[2]


def main() -> None:
    import pooltool as pt
    import pooltool.ptmath as ptmath
    import pooltool.constants as const

    params = pt.BallParams.default()
    R, G = params.R, params.g
    u_s, u_r, u_sp = params.u_s, params.u_r, params.u_sp

    output_dir = PROJECT_ROOT / "BilliardTrainerTests" / "TestData" / "transition_time"
    output_dir.mkdir(parents=True, exist_ok=True)

    test_cases = []
    # slideToRoll
    rvw_slide = pt.Ball.create("1", xy=(0.5, 0.5)).state.rvw.copy()
    rvw_slide[1] = [2.0, 0, 0]
    t_slide = ptmath.get_slide_time(rvw_slide, R, u_s, G)
    test_cases.append({"id": "tt_slideToRoll", "input": {"state": 2, "rvw": rvw_slide.tolist(), "R": R, "u_s": u_s, "g": G}, "expected": {"time": float(t_slide)}})

    # rollToSpin
    rvw_roll = rvw_slide.copy()
    rvw_roll[2] = [0, 0, 1.0 / R]
    t_roll = ptmath.get_roll_time(rvw_roll, u_r, G)
    test_cases.append({"id": "tt_rollToSpin", "input": {"state": 3, "rvw": rvw_roll.tolist(), "R": R, "u_r": u_r, "g": G}, "expected": {"time": float(t_roll)}})

    # spinToStationary
    rvw_spin = rvw_roll.copy()
    rvw_spin[1] = [0, 0, 0]
    rvw_spin[2] = [0, 0, 5.0]
    t_spin = ptmath.get_spin_time(rvw_spin, R, u_sp, G)
    test_cases.append({"id": "tt_spinToStationary", "input": {"state": 1, "rvw": rvw_spin.tolist(), "R": R, "u_sp": u_sp, "g": G}, "expected": {"time": float(t_spin)}})

    out_path = output_dir / "transition_time.json"
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump({
            "module": "transition_time",
            "source": "pooltool ptmath get_slide_time/get_roll_time/get_spin_time",
            "tolerance": {"abs": 1e-5, "rel": 1e-3},
            "test_cases": test_cases,
        }, f, indent=2, ensure_ascii=False)
    print(f"Exported {len(test_cases)} cases -> {out_path.relative_to(PROJECT_ROOT)}")


if __name__ == "__main__":
    main()
