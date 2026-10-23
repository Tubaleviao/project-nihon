#!/usr/bin/env python3
"""Phase 169 gate: the playtest bot's native run against its GDScript-fallback run on one commit.

usage: check_stream_rate.py <native report.json> <gdscript report.json>

- the `stream` step names its builder in each report (native / gdscript);
- the native chunk build rate is at least MIN_RATIO times the fallback's;
- the native run has no step with a hitch (a frame over 50 ms): the bot does not fail on hitches,
  so the report is read here.
"""
import json
import sys

MIN_RATIO = 2.0


def stream_step(report):
    for step in report["steps"]:
        if step["step"] == "stream":
            return step
    sys.exit("no stream step in the report")


def main(native_path, gd_path):
    with open(native_path) as f:
        native = json.load(f)
    with open(gd_path) as f:
        gd = json.load(f)
    n, g = stream_step(native), stream_step(gd)
    errors = []
    if n.get("builder") != "native":
        errors.append("the first run used builder %r, expected 'native'" % n.get("builder"))
    if g.get("builder") != "gdscript":
        errors.append("the second run used builder %r, expected 'gdscript'" % g.get("builder"))
    n_rate, g_rate = float(n.get("build_rate", 0.0)), float(g.get("build_rate", 0.0))
    ratio = n_rate / g_rate if g_rate > 0 else 0.0
    print("stream build rate: native %.1f chunks/s, gdscript %.1f chunks/s, ratio %.2fx (need %.1fx)" % (n_rate, g_rate, ratio, MIN_RATIO))
    if ratio < MIN_RATIO:
        errors.append("native build rate is %.2fx the fallback's, need at least %.1fx" % (ratio, MIN_RATIO))
    for step in native["steps"]:
        if int(step["hitches"]) > 0:
            errors.append("native run: step %s has %d hitch frame(s) over 50 ms (max %.0f ms)" % (step["step"], step["hitches"], step["max_ms"]))
    for e in errors:
        print("::error::" + e)
    return 1 if errors else 0


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1], sys.argv[2]))
