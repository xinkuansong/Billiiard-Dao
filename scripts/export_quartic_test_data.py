#!/usr/bin/env python3
"""
四次方程求解测试数据生成脚本

从 pooltool tests/ptmath/roots/data/*.npy 加载系数与根，导出为 Swift 可消费的 JSON。
覆盖 quartic_coeffs、hard_quartic_coeffs、1010_reference 等数据集。

用法:
  cd <project_root>
  source .venv/bin/activate
  python scripts/export_quartic_test_data.py

输出: BilliardTrainerTests/TestData/quartic/*.json
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np


# 系数顺序说明:
# - Swift QuarticSolver: ax^4 + bx^3 + cx^2 + dx + e = 0，即 [a,b,c,d,e] 降幂
# - pooltool quartic_coeffs / hard_quartic_coeffs: [c0,c1,c2,c3,c4] 升幂，需反转
# - pooltool 1010_reference_coeffs: 已为 [a,b,c,d,e] 降幂，与 C 实现一致

REAL_ROOT_TOLERANCE = 1e-10  # imag 小于此值视为实根


def extract_real_roots(roots: np.ndarray) -> list[float]:
    """从 4 个复根中提取实根，按升序排列。"""
    real_roots = []
    for z in roots:
        if abs(z.imag) < REAL_ROOT_TOLERANCE:
            real_roots.append(float(z.real))
    return sorted(real_roots)


def coeffs_to_swift_order(coeffs: np.ndarray, *, reverse: bool) -> list[float]:
    """转换为 Swift 期望的 [a,b,c,d,e] 降幂顺序。"""
    row = coeffs.tolist()
    if reverse:
        row = list(reversed(row))
    return [float(x) for x in row]


def export_dataset(
    pooltool_data_dir: Path,
    output_dir: Path,
    coeffs_file: str,
    roots_file: str,
    cases_file: str | None,
    source_name: str,
    reverse_coeffs: bool,
) -> None:
    """导出单个数据集到 JSON。"""
    coeffs_path = pooltool_data_dir / coeffs_file
    roots_path = pooltool_data_dir / roots_file

    if not coeffs_path.exists() or not roots_path.exists():
        print(f"  skip {source_name}: missing {coeffs_file} or {roots_file}")
        return

    coeffs = np.load(coeffs_path)
    roots = np.load(roots_path)
    cases_path = pooltool_data_dir / cases_file if cases_file else None
    cases = np.load(cases_path) if cases_path and cases_path.exists() else None

    test_cases = []
    for i in range(len(coeffs)):
        coeff_row = coeffs[i]
        roots_row = roots[i]

        swift_coeffs = coeffs_to_swift_order(coeff_row, reverse=reverse_coeffs)
        real_roots = extract_real_roots(roots_row)

        case_id = f"{source_name}_{i:04d}"
        tc = {
            "id": case_id,
            "input": {"a": swift_coeffs[0], "b": swift_coeffs[1], "c": swift_coeffs[2], "d": swift_coeffs[3], "e": swift_coeffs[4]},
            "expected_real_roots": real_roots,
        }
        if cases is not None:
            tc["case_label"] = int(cases[i])  # 0-5 pathological scenario
        test_cases.append(tc)

    out = {
        "module": "quartic",
        "source": source_name,
        "pooltool_files": [coeffs_file, roots_file],
        "tolerance": {"abs": 1e-5, "rel": 1e-3},
        "test_cases": test_cases,
    }

    out_name = source_name + ".json"
    out_path = output_dir / out_name
    out_path.parent.mkdir(parents=True, exist_ok=True)

    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(out, f, indent=2, ensure_ascii=False)

    print(f"  exported {len(test_cases)} cases -> {out_path.relative_to(output_dir)}")


def main() -> None:
    project_root = Path(__file__).resolve().parent.parent
    pooltool_data_dir = project_root / "pooltool-main" / "tests" / "ptmath" / "roots" / "data"
    output_dir = project_root / "BilliardTrainerTests" / "TestData" / "quartic"

    if not pooltool_data_dir.exists():
        print(f"pooltool data dir not found: {pooltool_data_dir}")
        return

    print("Exporting quartic test data from pooltool...")
    print(f"  pooltool data: {pooltool_data_dir}")
    print(f"  output:       {output_dir}")

    # quartic_coeffs: 升幂 [c0..c4]，需反转
    export_dataset(
        pooltool_data_dir,
        output_dir,
        coeffs_file="quartic_coeffs.npy",
        roots_file="quartic_coeffs.roots.npy",
        cases_file=None,
        source_name="quartic_coeffs",
        reverse_coeffs=True,
    )

    # hard_quartic_coeffs: 升幂 [c0..c4]，需反转
    export_dataset(
        pooltool_data_dir,
        output_dir,
        coeffs_file="hard_quartic_coeffs.npy",
        roots_file="hard_quartic_coeffs.roots.npy",
        cases_file="hard_quartic_coeffs.cases.npy",
        source_name="hard_quartic_coeffs",
        reverse_coeffs=True,
    )

    # 1010_reference: 已为 [a,b,c,d,e] 降幂，不反转
    export_dataset(
        pooltool_data_dir,
        output_dir,
        coeffs_file="1010_reference_coeffs.npy",
        roots_file="1010_reference_coeffs.roots.npy",
        cases_file=None,
        source_name="1010_reference",
        reverse_coeffs=False,
    )

    print("Done.")


if __name__ == "__main__":
    main()
