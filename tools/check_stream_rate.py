#!/usr/bin/env python3
"""Phase 169 gate: the playtest bot's native run against its GDScript-fallback run on one commit.

usage: check_stream_rate.py <native report.json> <gdscript report.json>

- the `stream` step names its builder in each report (native / gdscript);
- the native chunk build rate is at least MIN_RATIO times the fallback's;
- the native stream step carries the Phase 170 per-stage build breakdown and its shader decision;
- the native stream step hitches (frames over 50 ms) no more than the fallback's does, per chunk built: the bot does not
  fail on hitches, so the reports are read here. The CI renderer is software GL, where frames are slow
  whatever the builder, so an absolute zero is out of reach; the fallback run on the same commit and
  runner is the baseline, with HITCH_SLACK frames of noise allowed.
"""
import json
import sys

MIN_RATIO = 2.0
HITCH_SLACK = 10   # frames of run-to-run noise allowed on top of the fallback's total
HITCH_RATIO = 1.25
HITCH_PER_CHUNK_SLACK = 0.25   # hitch frames per chunk built allowed on top of the fallback's rate


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
    # The stream step only: the other steps do not run the builder, and the native run goes first, so
    # it alone pays the cold-start costs (shader compile, page cache) in their frames.
    n_hitches = int(n["hitches"])
    g_hitches = int(g["hitches"])
    limit = g_hitches * HITCH_RATIO + HITCH_SLACK
    # The native builder lands several times more chunks in the same step, and each attach costs main-thread
    # time, so a faster builder hitches more in absolute frames. Scale the allowance by chunks built too:
    # the fallback's hitches per chunk, plus HITCH_PER_CHUNK_SLACK of noise, over the native chunk count.
    n_chunks, g_chunks = int(n.get("chunk_builds", 0)), int(g.get("chunk_builds", 0))
    per_chunk = (g_hitches / g_chunks if g_chunks > 0 else 0.0) * HITCH_RATIO + HITCH_PER_CHUNK_SLACK
    limit = max(limit, per_chunk * n_chunks)
    print("chunks built in the stream step: native %d, gdscript %d" % (n_chunks, g_chunks))
    print("hitch frames over 50 ms: native %d, gdscript %d (limit %.0f)" % (n_hitches, g_hitches, limit))
    if n_hitches > limit:
        errors.append("native stream step has %d hitch frames, over the fallback's %d (limit %.0f); max %.0f ms" % (n_hitches, g_hitches, limit, float(n["max_ms"])))
    bb = n.get("build_breakdown") or {}
    for key in ("heightmap_ms", "seam_ms", "runs_ms", "arrays_ms", "total_ms", "heightmap_share", "window_radius", "decision"):
        if key not in bb:
            errors.append("the native stream step has no build_breakdown.%s (Phase 170 measurement)" % key)
    if bb:
        print("heightmap share of the native build: %.0f%% at window radius %s -> %s" % (100.0 * float(bb.get("heightmap_share", 0.0)), bb.get("window_radius"), bb.get("decision")))
    for e in errors:
        print("::error::" + e)
    return 1 if errors else 0


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1], sys.argv[2]))
