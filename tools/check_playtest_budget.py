#!/usr/bin/env python3
"""Phase 174 gate: median of N playtest reports against the p95 process-time budget.

usage: check_playtest_budget.py REPORT.json [REPORT.json ...]

Each report is a `--playtest-bot --playtest-no-budget` run. A step fails when the median over the runs
of its p95 process time exceeds budget * 1.25 (docs/perf/playtest-budget.json), so one noisy run on a
shared runner does not fail an unrelated PR. Also fails when the native builder was not loaded.
"""
import json
import statistics
import sys
from pathlib import Path

HEADROOM = 1.25
BUDGET = Path(__file__).resolve().parent.parent / "docs" / "perf" / "playtest-budget.json"


def check(reports, budgets):
    failures = []
    if not all(r.get("native_builder") is True for r in reports):
        failures.append("native_builder is not true in every report (the GDScript fallback ran)")
    for step, budget in budgets.items():
        p95s = [s["process_ms"]["p95"] for r in reports for s in r["steps"] if s["step"] == step]
        if not p95s:
            failures.append(f"step {step} is in no report")
            continue
        med = statistics.median(p95s)
        limit = budget * HEADROOM
        print(f"{step}: median p95 process {med:.1f} ms of {len(p95s)} runs (budget {budget} ms, limit {limit:.1f} ms)")
        if med > limit:
            failures.append(f"step {step}: median p95 process time {med:.1f} ms is over {limit:.1f} ms")
    return failures


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    reports = [json.loads(Path(a).read_text()) for a in argv]
    failures = check(reports, json.loads(BUDGET.read_text()))
    for f in failures:
        print(f"FAIL: {f}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
