#!/usr/bin/env python3
"""Phase 163 — fail when a stress series' largest passing size is below docs/perf/crowd-baseline.json.

Usage: tools/check_crowd_baseline.py [stress/report.json] [docs/perf/crowd-baseline.json]
Also fails when `lan/cluster` at 64 bots misses `cluster_64_limits` (half the baseline tick, 60% of its bytes).
Series absent from the report are skipped (a manual run may cover fewer profiles), but a run that
compares nothing fails.
"""
import json
import sys

report_path = sys.argv[1] if len(sys.argv) > 1 else "stress/report.json"
baseline_path = sys.argv[2] if len(sys.argv) > 2 else "docs/perf/crowd-baseline.json"
series = json.load(open(report_path))["series"]
base = json.load(open(baseline_path))
baseline = base["largest_passing"]
bad = 0
compared = 0
for name, floor in sorted(baseline.items()):
    if name not in series:
        continue
    compared += 1
    got = int(series[name].get("largest_passing", 0))
    status = "ok" if got >= floor else "BELOW BASELINE"
    print(f"{name}: largest passing size {got}, baseline {floor} — {status}")
    if got < floor:
        print(f"::error::{name}: largest passing size {got} is below the baseline {floor}")
        bad += 1
if compared == 0:
    print("::error::no series in the report matches the baseline")
    bad += 1
for run in series.get("lan/cluster", {}).get("runs", []):
    if int(run.get("size", 0)) != 64:
        continue
    for key, limit in base.get("cluster_64_limits", {}).items():
        value = float(run.get(key, float("inf")))
        status = "ok" if value <= limit else "OVER LIMIT"
        print(f"lan/cluster @64 {key}: {value:.2f}, limit {limit} — {status}")
        if value > limit:
            print(f"::error::lan/cluster @64 {key} {value:.2f} is over the limit {limit}")
            bad += 1
sys.exit(1 if bad else 0)
