#!/usr/bin/env python3
"""Phase 169 gate: compare the playtest bot's two reports (GDScript fallback vs native builder).

usage: check_native_speedup.py <gdscript report.json> <native report.json> <min speedup>

Passes when the `stream` step's chunk build rate with the native builder is at least `min speedup`
times the GDScript fallback's, and the native run shows no step with a frame over the 50 ms hitch
line (the bot itself does not fail on hitches). Prints a markdown summary; exits 1 on a miss.
"""
import json
import sys


def load(path, builder):
    with open(path) as f:
        report = json.load(f)
    if report.get("builder") != builder:
        sys.exit("%s ran on the %r builder, expected %r" % (path, report.get("builder"), builder))
    return report


def stream_rate(report):
    for step in report["steps"]:
        if step["step"] == "stream":
            return float(step.get("chunk_build_rate", 0.0))
    sys.exit("no stream step in the report")


def main(argv):
    if len(argv) != 4:
        sys.exit(__doc__)
    gd = load(argv[1], "gdscript")
    native = load(argv[2], "native")
    need = float(argv[3])
    gd_rate = stream_rate(gd)
    native_rate = stream_rate(native)
    speedup = native_rate / gd_rate if gd_rate > 0.0 else 0.0
    hitchy = [(s["step"], int(s["hitches"])) for s in native["steps"] if int(s["hitches"]) > 0]
    print("## Native builder speed target\n")
    print("| Builder | `stream` chunks/s |\n|---|---|")
    print("| gdscript | %.2f |\n| native | %.2f |\n" % (gd_rate, native_rate))
    print("Speedup: **%.2fx** (need %.1fx)\n" % (speedup, need))
    print("Native steps with a hitch over 50 ms: %s" % (", ".join("%s (%d)" % h for h in hitchy) or "none"))
    ok = True
    if speedup < need:
        print("\nFAIL: speedup %.2fx is below %.1fx" % (speedup, need))
        ok = False
    if hitchy:
        print("\nFAIL: the native run has hitches over 50 ms")
        ok = False
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
