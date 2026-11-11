#!/usr/bin/env python3
"""Phase 248: the playtest `flight` step's numbers, release export beside the editor run. Report only.

usage: flight_report.py <release report.json> [<editor report.json>]
       flight_report.py --self-test

Prints a Markdown table (one column per report) for the CI step summary and the release column of
docs/perf/playtest-baseline.md. Exits 1 only when the release report has no flight step (a crash or a
boot failure); the numbers themselves gate nothing. Phase 239 sets its targets from them.
"""
import json
import sys

# (label, path into the step record, format). A missing value prints as "-".
ROWS = [
    ("Builder (native library)", ("native_builder",), "{}"),
    ("Step verdict", ("ok",), "{}"),
    ("Speed (m/s)", ("flight", "speed_mps"), "{:.0f}"),
    ("Ground under the body built (% of samples)", ("flight", "under_cover"), "pct"),
    ("Reach ring built, mean (%)", ("flight", "ring_cover"), "pct"),
    ("Reach ring built, worst (%)", ("flight", "worst_ring"), "pct"),
    ("Chunks attached", ("flight", "attached"), "{}"),
    ("Main-thread ms per attached chunk", ("flight", "main_ms_per_attach"), "{:.2f}"),
    ("Window crossings", ("flight", "crossings"), "{}"),
    ("Worker ms per crossing", ("flight", "worker_ms_per_crossing"), "{:.1f}"),
    ("p50 process (ms)", ("process_ms", "p50"), "{:.1f}"),
    ("p95 process (ms)", ("process_ms", "p95"), "{:.1f}"),
    ("p95 render (ms)", ("render_ms", "p95"), "{:.1f}"),
    ("Chunk builds", ("chunk_builds",), "{}"),
]


def flight_step(report):
    for step in report.get("steps", []):
        if step.get("step") == "flight":
            rec = dict(step)
            rec["native_builder"] = report.get("native_builder")
            return rec
    return None


def cell(rec, path, fmt):
    v = rec
    for key in path:
        if not isinstance(v, dict) or key not in v:
            return "-"
        v = v[key]
    try:
        if fmt == "pct":
            return "{:.0f}".format(100.0 * float(v))
        return fmt.format(v)
    except (TypeError, ValueError):
        return str(v)


def table(columns):
    """columns: [(header, step record)] -> Markdown lines."""
    lines = ["| Flight step | " + " | ".join(h for h, _ in columns) + " |",
             "|---|" + "---|" * len(columns)]
    for label, path, fmt in ROWS:
        lines.append("| %s | %s |" % (label, " | ".join(cell(rec, path, fmt) for _, rec in columns)))
    return lines


def self_test():
    rel = {"native_builder": True, "steps": [{"step": "flight", "ok": True, "chunk_builds": 40,
           "process_ms": {"p50": 4.0, "p95": 9.25}, "render_ms": {"p95": 30.0},
           "flight": {"speed_mps": 270.0, "under_cover": 0.875, "attached": 12, "main_ms_per_attach": 1.5}}]}
    rec = flight_step(rel)
    assert rec is not None, "the flight step is found"
    out = "\n".join(table([("Release", rec), ("Editor", {})]))
    assert "| Speed (m/s) | 270 | - |" in out, out
    assert "| Ground under the body built (% of samples) | 88 | - |" in out, out
    assert "| p95 process (ms) | 9.2 | - |" in out or "| p95 process (ms) | 9.3 | - |" in out, out
    assert "| Builder (native library) | True | - |" in out, out
    assert flight_step({"steps": [{"step": "walk"}]}) is None, "no flight step is reported as missing"
    print("flight_report self-test ok")


def main(argv):
    if argv[1:] == ["--self-test"]:
        self_test()
        return 0
    if len(argv) not in (2, 3):
        print(__doc__)
        return 2
    with open(argv[1]) as f:
        release = flight_step(json.load(f))
    if release is None:
        print("::error::the release report has no flight step")
        return 1
    columns = [("Release export (template_release)", release)]
    if len(argv) == 3:
        with open(argv[2]) as f:
            editor = flight_step(json.load(f))
        columns.append(("Editor (template_debug)", editor or {}))
    print("\n".join(table(columns)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
