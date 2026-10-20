#!/usr/bin/env python3
"""Phase 163 — fail when a stress series' largest passing size is below docs/perf/crowd-baseline.json.

Usage: tools/check_crowd_baseline.py [stress/report.json] [docs/perf/crowd-baseline.json]
Only series present in both files are compared (a manual run may cover fewer profiles).
"""
import json
import sys

report_path = sys.argv[1] if len(sys.argv) > 1 else "stress/report.json"
baseline_path = sys.argv[2] if len(sys.argv) > 2 else "docs/perf/crowd-baseline.json"
series = json.load(open(report_path))["series"]
baseline = json.load(open(baseline_path))["largest_passing"]
bad = 0
for name, floor in sorted(baseline.items()):
    if name not in series:
        continue
    got = int(series[name].get("largest_passing", 0))
    status = "ok" if got >= floor else "BELOW BASELINE"
    print(f"{name}: largest passing size {got}, baseline {floor} — {status}")
    if got < floor:
        print(f"::error::{name}: largest passing size {got} is below the baseline {floor}")
        bad += 1
sys.exit(1 if bad else 0)
