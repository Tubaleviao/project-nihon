#!/usr/bin/env python3
"""Phase 174 gate: median of N playtest reports against the p95 process-time budget.

usage: check_playtest_budget.py REPORT.json [REPORT.json ...]
       check_playtest_budget.py --self-test   prove the flight gate accepts and rejects fixtures

Each report is a `--playtest-bot --playtest-no-budget` run. A step fails when the median over the runs
of its p95 process time exceeds budget * 1.25 (docs/perf/playtest-budget.json), so one noisy run on a
shared runner does not fail an unrelated PR. Also fails when the native builder was not loaded.

Phase 189: also fails when the median over the runs of the flight step's collision and contents ms per
attached chunk (`flight.near_ms_per_attach`, the phases the near ring removes) is over FLIGHT_MAX_SHARE of
the median of its record flight, flown in the same run with the near ring off, i.e. the Phase 187 behaviour
(`flight.record_near_ms_per_attach`). The whole chunk pump (`main_ms_per_attach`, `record_ms_per_attach`)
and its per-phase breakdown are printed, not gated: mesh upload and dispatch are not the near ring's to cut,
and their share varies with the machine.
"""
import json
import os
import statistics
import sys
from pathlib import Path

HEADROOM = 1.25
BUDGET = Path(__file__).resolve().parent.parent / "docs" / "perf" / "playtest-budget.json"
FLIGHT_MAX_SHARE = 0.5   # PlaytestBot.FLIGHT_MAX_SHARE


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


def check_flight(reports, max_share=FLIGHT_MAX_SHARE):
    flights = [s["flight"] for r in reports for s in r["steps"]
               if s["step"] == "flight" and s.get("flight", {}).get("record_attached", 0) > 0
               and s["flight"].get("attached", 0) > 0 and "record_near_ms_per_attach" in s["flight"]]
    if not flights:
        return ["no report has a flight step that attached chunks on both flights"]
    total = statistics.median(f["main_ms_per_attach"] for f in flights)
    total_record = statistics.median(f["record_ms_per_attach"] for f in flights)
    print(f"flight: median main thread {total:.1f} ms per attached chunk of {len(flights)} runs "
          f"(near ring off: {total_record:.1f} ms; report only)")
    med = statistics.median(f["near_ms_per_attach"] for f in flights)
    record = statistics.median(f["record_near_ms_per_attach"] for f in flights)
    limit = record * max_share
    line = (f"flight: median collision and contents {med:.1f} ms per attached chunk of {len(flights)} runs "
            f"(near ring off: {record:.1f} ms, limit {limit:.1f} ms)")
    print(line)
    for label, field in (("near ring on ", "phases_ms_per_attach"), ("near ring off", "record_phases_ms_per_attach")):
        phases = sorted({p for f in flights for p in f.get(field, {})})
        if phases:
            print(f"  {label}: " + ", ".join(
                f"{p} {statistics.median(f.get(field, {}).get(p, 0.0) for f in flights):.2f}" for p in phases))
    if os.environ.get("GITHUB_ACTIONS") == "true":
        print(f"::notice title=Flight collision and contents per attached chunk::{line}")
    if med > limit:
        return [f"flight: median {med:.1f} ms per attached chunk is over {limit:.1f} ms "
                f"({max_share:.0%} of the near-ring-off record's collision and contents)"]
    return []


def self_test():
    def report(ms, record, total=10.0, total_record=15.0):
        return {"steps": [{"step": "flight", "flight": {
            "attached": 20, "main_ms_per_attach": total, "near_ms_per_attach": ms,
            "record_attached": 20, "record_ms_per_attach": total_record, "record_near_ms_per_attach": record}}]}
    cases = [
        # the CI runner of PR #503: the whole pump at 62% of the record, its collision and contents far under half
        ("the whole pump over half, the near-ring phases under",
         [report(2.5, 10, 10.8, 17.4), report(2.4, 9.6, 11, 17), report(3, 11, 12, 19)], True),
        ("a report without the near-ring fields",
         [{"steps": [{"step": "flight", "flight": {"attached": 20, "main_ms_per_attach": 1, "record_attached": 20,
                                                   "record_ms_per_attach": 9}}]}], False),
        ("a third of the record", [report(7, 21), report(8, 24), report(6, 20)], True),
        ("one noisy run of three", [report(7, 21), report(30, 20), report(8, 22)], True),
        ("over half the record", [report(12, 20), report(11, 21), report(13, 22)], False),
        ("no flight step", [{"steps": []}], False),
        ("a record flight that attached nothing",
         [{"steps": [{"step": "flight", "flight": {"attached": 5, "main_ms_per_attach": 1, "record_attached": 0,
                                                   "record_ms_per_attach": 0}}]}], False),
    ]
    bad = 0
    for name, reports, ok in cases:
        if (not check_flight(reports)) != ok:
            print(f"self-test: the flight gate got '{name}' wrong")
            bad += 1
    print("self-test: ok" if not bad else f"self-test: {bad} case(s) wrong")
    return 1 if bad else 0


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    if argv == ["--self-test"]:
        return self_test()
    reports = [json.loads(Path(a).read_text()) for a in argv]
    failures = check(reports, json.loads(BUDGET.read_text()))
    failures += check_flight(reports)
    for f in failures:
        print(f"FAIL: {f}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
