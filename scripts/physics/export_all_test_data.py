#!/usr/bin/env python3
"""
运行所有物理测试数据导出脚本。

用法:
  cd <project_root>
  source .venv/bin/activate
  python scripts/physics/export_all_test_data.py
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

def main() -> int:
    root = Path(__file__).resolve().parents[2]
    scripts_dir = root / "scripts"
    scripts_list = [
        scripts_dir / "export_quartic_test_data.py",
        scripts_dir / "physics" / "export_ball_ball_collision_time.py",
        scripts_dir / "physics" / "export_ball_linear_cushion_time.py",
        scripts_dir / "physics" / "export_ball_circular_cushion_time.py",
        scripts_dir / "physics" / "export_ball_ball_resolve.py",
        scripts_dir / "physics" / "export_cushion_resolve.py",
        scripts_dir / "physics" / "export_evolve.py",
        scripts_dir / "physics" / "export_transition_time.py",
        scripts_dir / "physics" / "export_cue_strike.py",
    ]
    failed = []
    for path in scripts_list:
        if not path.exists():
            print(f"[skip] {path.relative_to(root)} (not found)")
            continue
        print(f"\n--- {path.relative_to(root)} ---")
        r = subprocess.run([sys.executable, str(path)], cwd=str(root))
        if r.returncode != 0:
            failed.append(str(path.relative_to(root)))
    if failed:
        print(f"\nFailed: {failed}")
        return 1
    print("\n--- export_pooltool_baseline (CrossEngine) ---")
    r = subprocess.run([sys.executable, "scripts/physics/export_pooltool_baseline.py"], cwd=str(root))
    if r.returncode != 0:
        print("[warn] export_pooltool_baseline had issues")
    print("\nDone.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
