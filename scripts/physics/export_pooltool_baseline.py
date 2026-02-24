#!/usr/bin/env python3
"""Export pooltool baselines from CrossEngine fixtures.

Usage:
  python scripts/physics/export_pooltool_baseline.py
  python scripts/physics/export_pooltool_baseline.py --case "case-s1-*"
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

STATE_TO_INT = {
    "stationary": 0,
    "spinning": 1,
    "sliding": 2,
    "rolling": 3,
    "pocketed": 4,
}

INT_TO_STATE = {v: k for k, v in STATE_TO_INT.items()}


@dataclass
class FixturePaths:
    input_path: Path
    output_path: Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Export pooltool output baselines for fixtures")
    parser.add_argument(
        "--fixtures-dir",
        default="BilliardTrainerTests/Fixtures/CrossEngine",
        help="Directory containing case-*.input.json",
    )
    parser.add_argument(
        "--pooltool-root",
        default="pooltool-main",
        help="Path to pooltool source root",
    )
    parser.add_argument(
        "--case",
        default="case-*.input.json",
        help="Glob for selecting fixture inputs",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Fail if pooltool import/simulation fails",
    )
    return parser.parse_args()


def discover_cases(fixtures_dir: Path, pattern: str) -> list[FixturePaths]:
    paths: list[FixturePaths] = []
    for input_path in sorted(fixtures_dir.glob(pattern)):
        output_path = input_path.with_name(
            input_path.name.replace(".input.json", ".pooltool-output.json")
        )
        paths.append(FixturePaths(input_path=input_path, output_path=output_path))
    return paths


def to_pool_position(swift_pos: list[float], table_w: float, table_l: float, radius: float) -> list[float]:
    # Swift uses x-z plane centered at origin; pooltool uses x-y plane with [0,w]x[0,l].
    x = swift_pos[0] + table_w / 2.0
    y = swift_pos[2] + table_l / 2.0
    return [x, y, radius]


def to_pool_velocity(swift_vel: list[float]) -> list[float]:
    return [swift_vel[0], swift_vel[2], 0.0]


def to_pool_angular(swift_w: list[float]) -> list[float]:
    # Swift vertical axis is Y; pooltool vertical axis is Z.
    return [swift_w[0], swift_w[2], swift_w[1]]


def from_pool_position(pool_pos: list[float], table_w: float, table_l: float, surface_y: float) -> list[float]:
    return [float(pool_pos[0] - table_w / 2.0), float(surface_y), float(pool_pos[1] - table_l / 2.0)]


def from_pool_velocity(pool_vel: list[float]) -> list[float]:
    return [float(pool_vel[0]), 0.0, float(pool_vel[1])]


def from_pool_angular(pool_w: list[float]) -> list[float]:
    return [float(pool_w[0]), float(pool_w[2]), float(pool_w[1])]


def make_pooltool_output(case_data: dict[str, Any], pt: Any) -> dict[str, Any]:
    table = pt.Table.default()
    cue = pt.Cue.default()
    cue_ball_id = "cueBall" if any(b["id"] == "cueBall" for b in case_data["balls"]) else case_data["balls"][0]["id"]
    cue.set_state(cue_ball_id=cue_ball_id)

    balls: dict[str, Any] = {}
    for b in case_data["balls"]:
        ball = pt.Ball.create(b["id"])
        ball.state.rvw[0] = to_pool_position(
            swift_pos=b["position"],
            table_w=table.w,
            table_l=table.l,
            radius=ball.params.R,
        )
        ball.state.rvw[1] = to_pool_velocity(b["velocity"])
        ball.state.rvw[2] = to_pool_angular(b["angularVelocity"])
        ball.state.s = STATE_TO_INT.get(b["state"], 2)
        balls[b["id"]] = ball

    system = pt.System(cue=cue, table=table, balls=balls)
    simulated = pt.simulate(
        system,
        inplace=False,
        continuous=False,
        max_events=case_data["simulation"]["maxEvents"],
        t_final=case_data["simulation"]["maxTime"],
    )

    events = []
    for event in simulated.events:
        if event.event_type.name == "NONE":
            continue
        events.append(
            {
                "type": event.event_type.name,
                "time": float(event.time),
                "ids": list(event.ids),
            }
        )

    # derive surface y from input if possible
    surface_y = float(case_data["balls"][0]["position"][1]) if case_data["balls"] else 0.0
    final_state: dict[str, Any] = {}
    for ball_id, ball in simulated.balls.items():
        final_state[ball_id] = {
            "position": from_pool_position(ball.state.rvw[0], table.w, table.l, surface_y),
            "velocity": from_pool_velocity(ball.state.rvw[1]),
            "angularVelocity": from_pool_angular(ball.state.rvw[2]),
            "motionState": INT_TO_STATE.get(int(ball.state.s), "sliding"),
        }

    return {
        "metadata": {"id": case_data["metadata"]["id"], "engine": "pooltool"},
        "events": events,
        "finalState": final_state,
    }


def fallback_output(case_data: dict[str, Any]) -> dict[str, Any]:
    final_state = {}
    for b in case_data["balls"]:
        final_state[b["id"]] = {
            "position": b["position"],
            "velocity": b["velocity"],
            "angularVelocity": b["angularVelocity"],
            "motionState": b["state"],
        }
    return {
        "metadata": {"id": case_data["metadata"]["id"], "engine": "pooltool-fallback"},
        "events": [],
        "finalState": final_state,
    }


def main() -> int:
    args = parse_args()
    repo_root = Path(__file__).resolve().parents[2]
    fixtures_dir = (repo_root / args.fixtures_dir).resolve()
    pooltool_root = (repo_root / args.pooltool_root).resolve()

    if not fixtures_dir.exists():
        print(f"[error] fixtures dir not found: {fixtures_dir}")
        return 1

    case_paths = discover_cases(fixtures_dir, args.case)
    if not case_paths:
        print(f"[warn] no fixture matched: {args.case}")
        return 0

    sys.path.insert(0, str(pooltool_root))
    pooltool_import_error: Exception | None = None
    pt = None
    try:
        import pooltool as pt_mod  # type: ignore

        pt = pt_mod
    except Exception as exc:  # pragma: no cover - best effort import
        pooltool_import_error = exc

    if pt is None:
        msg = f"[warn] pooltool import failed ({pooltool_import_error}); using fallback output"
        if args.strict:
            print(msg)
            return 1
        print(msg)

    for case in case_paths:
        case_data = json.loads(case.input_path.read_text(encoding="utf-8"))
        if pt is not None:
            try:
                output = make_pooltool_output(case_data, pt)
            except Exception as exc:  # pragma: no cover
                if args.strict:
                    print(f"[error] simulation failed for {case.input_path.name}: {exc}")
                    return 1
                print(f"[warn] simulation failed for {case.input_path.name}: {exc}; fallback used")
                output = fallback_output(case_data)
        else:
            output = fallback_output(case_data)

        case.output_path.write_text(
            json.dumps(output, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        print(f"[ok] wrote {case.output_path.relative_to(repo_root)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

