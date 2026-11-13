#!/usr/bin/env bash
# Phase 255 — plays playtest-bot steps on an exported build and applies the export gates shared by CI's
# release-flight job and the release workflow:
#   - the export wrote playtest/report.json (no crash or boot failure),
#   - it loaded the release native library (`[Native] chunk builder: native`),
#   - its log has no SCRIPT ERROR / Parse Error / Compile Error,
#   - the bot exited 0 (skipped with --report-only, where the caller reads the report instead).
#
#   tools/run_export_playtest.sh [--report-only] <exported executable> <steps> <log file>
#
# The exported game writes res://playtest next to the executable, so it runs from the executable's
# directory and the report is <dir>/playtest/report.json. Frame budgets are off (`--playtest-no-budget`):
# a runner's speed is not the export's fault. Exits 1 when a gate fails.
set -uo pipefail

report_only=false
if [ "${1:-}" = "--report-only" ]; then
  report_only=true
  shift
fi
if [ $# -ne 3 ]; then
  echo "usage: run_export_playtest.sh [--report-only] <exported executable> <steps> <log file>" >&2
  exit 2
fi
exe="$1" steps="$2" log="$3"
dir="$(cd "$(dirname "$exe")" && pwd)"
cd "$dir" || exit 1

timeout 1500 xvfb-run -a -s "-screen 0 1280x720x24" \
  "./$(basename "$exe")" --rendering-driver opengl3 -- --playtest-bot --playtest-no-budget --playtest-only "$steps" \
  2>&1 | tee "$log"
status=${PIPESTATUS[0]}

if [ -n "${GITHUB_STEP_SUMMARY:-}" ] && [ -f playtest/report.md ] && [ "$report_only" = false ]; then
  cat playtest/report.md >> "$GITHUB_STEP_SUMMARY"
fi
if [ ! -f playtest/report.json ]; then
  echo "::error::the export wrote no playtest report (crash or boot failure)"
  exit 1
fi
if ! grep -q "\[Native\] chunk builder: native" "$log"; then
  echo "::error::the export did not load the release native library"
  exit 1
fi
if grep -qE "SCRIPT ERROR|Parse Error|Compile Error" "$log"; then
  echo "::error::script/parse/compile errors in the export"
  exit 1
fi
if [ "$report_only" = true ]; then
  echo "Export playtest ($steps) exit status: $status (report only)"
  exit 0
fi
if [ "$status" -ne 0 ]; then
  echo "::error::the playtest bot failed on the export (exit $status)"
  exit 1
fi
