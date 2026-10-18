#!/usr/bin/env bash
# Phase 162 — the crowd stress run.
#
# For each link profile, each walk pattern and each crowd size of the ladder this driver boots three
# processes of the real game on loopback:
#
#   • a dedicated server with the host recorder (`--server --stress-host`): fresh save directory,
#     pinned world seed, every new player placed at one anchor;
#   • a watcher, one full headless client standing in the crowd (`--net-harness client --stress-watch`);
#   • the bot process (`--stress-bots <n>`): n light clients, each its own ENet peer and identity,
#     walking the pattern.
#
# The bots create a "steady" file once they have all joined; the host and the watcher sample only
# while it exists. When the bots have walked for STRESS_SECONDS they leave and exit, the driver
# touches the "stop" file, the watcher leaves, and the host checks that it holds no record of any peer
# before writing its report. A pattern stops climbing the ladder once its host tick p95 passes the
# ceiling in StressRules (`LADDER_STOP_TICK_P95_MS`); the report records where.
#
# Then `tools/stress_report.gd` turns every run into `$STRESS_OUT/report.json` and `report.md`: per
# series the largest crowd that met every budget, and the hot spots ranked by how much of a budget
# they would take at the top of the ladder. Budgets are a report; the driver fails (exit 1) only on a
# hard failure: a crash, a host or watcher frame over 2 s, a bot dropped by the host without a reason,
# or a peer record left after everyone left.
#
# Usage:
#   GODOT=/tmp/godot/Godot_v4.7-stable_linux.x86_64 tools/stress.sh
#
# Env knobs: GODOT (binary, default `godot`), STRESS_OUT (default ./stress), STRESS_MAX (largest
# crowd to try, default 200), STRESS_PATTERNS (default "cluster spread cross pole churn"),
# STRESS_PROFILES (default "lan wan_br"), STRESS_SECONDS (steady seconds per run, default 20),
# STRESS_SEED (bot path seed, default 1).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
OUT="${STRESS_OUT:-$REPO_ROOT/stress}"
MAX_SIZE="${STRESS_MAX:-200}"
PATTERNS="${STRESS_PATTERNS:-cluster spread cross pole churn}"
PROFILES="${STRESS_PROFILES:-lan wan_br}"
STEADY_SECS="${STRESS_SECONDS:-20}"
SEED="${STRESS_SEED:-1}"
LADDER="16 32 64 128 200"
RUNS="$OUT/runs"

note() { echo "stress: $*"; }
fail() { echo "::error::stress: $*"; }

if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
  echo "::error::stress: Godot binary not found ('$GODOT'). Set GODOT=/path/to/godot." >&2
  exit 2
fi
if [ ! -f "$REPO_ROOT/project.godot" ]; then
  echo "::error::stress: $REPO_ROOT does not look like the Godot project." >&2
  exit 2
fi
port_busy() { command -v ss >/dev/null 2>&1 && ss -lnu 2>/dev/null | grep -q ':7777 '; }
if port_busy; then
  echo "::error::stress: port 7777 is already in use — a stale host would be joined instead." >&2
  exit 2
fi

mkdir -p "$RUNS"
# Old runs would be read into this report; only this driver's own runs directory is cleared.
find "$RUNS" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +

PIDS=()
cleanup() {
  for pid in "${PIDS[@]:-}"; do
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null
    fi
  done
}
trap cleanup EXIT

# wait_for <file> <pattern> <pid> <seconds>: true once the log shows the pattern.
wait_for() {
  local log="$1" pattern="$2" pid="$3" secs="$4"
  local deadline=$(( $(date +%s) + secs ))
  while ! grep -q "$pattern" "$log" 2>/dev/null; do
    if ! kill -0 "$pid" 2>/dev/null; then return 1; fi
    if [ "$(date +%s)" -gt "$deadline" ]; then return 1; fi
    sleep 0.5
  done
  return 0
}

# wait_exit <pid> <seconds>: wait for a process to end on its own, kill it past the deadline.
wait_exit() {
  local pid="$1" secs="$2"
  local deadline=$(( $(date +%s) + secs ))
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$(date +%s)" -gt "$deadline" ]; then
      kill "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null
      return 1
    fi
    sleep 0.5
  done
  wait "$pid" 2>/dev/null
  return $?
}

run_one() {
  local profile="$1" pattern="$2" size="$3"
  local dir="$RUNS/$profile/$pattern/$size"
  mkdir -p "$dir"
  local steady="$dir/steady" stop="$dir/stop"
  local common=(--stress-steady "$steady" --stress-stop "$stop" --stress-pattern "$pattern" --net-profile "$profile")
  note "run $profile/$pattern/$size"

  "$GODOT" --headless --path "$REPO_ROOT" -- --server --stress-host "$dir/host.json" "${common[@]}" >"$dir/host.log" 2>&1 &
  local host_pid=$!
  PIDS+=("$host_pid")
  if ! wait_for "$dir/host.log" 'listening on port' "$host_pid" 90; then
    fail "$profile/$pattern/$size: the host never reported a listening line"
    wait_exit "$host_pid" 1
    return
  fi

  "$GODOT" --headless --path "$REPO_ROOT" -- --net-harness client --stress-watch "$dir/watch.json" "${common[@]}" >"$dir/watch.log" 2>&1 &
  local watch_pid=$!
  PIDS+=("$watch_pid")
  if ! wait_for "$dir/watch.log" '\[Stress\] watcher ready' "$watch_pid" 120; then
    fail "$profile/$pattern/$size: the watcher never finished its join (the report counts it missing)"
  fi

  timeout $(( STEADY_SECS + 180 )) "$GODOT" --headless --path "$REPO_ROOT" -- --stress-bots "$size" \
    --stress-seed "$SEED" --stress-seconds "$STEADY_SECS" --stress-out "$dir/bots.json" "${common[@]}" \
    >"$dir/bots.log" 2>&1
  local bots_status=$?
  [ "$bots_status" -ne 0 ] && fail "$profile/$pattern/$size: the bot process exited $bots_status"

  touch "$stop"
  wait_exit "$watch_pid" 60 || fail "$profile/$pattern/$size: the watcher did not exit after the stop file"
  wait_exit "$host_pid" 90 || fail "$profile/$pattern/$size: the host did not exit after the stop file"
  # The next run's host needs the port.
  local deadline=$(( $(date +%s) + 30 ))
  while port_busy && [ "$(date +%s)" -le "$deadline" ]; do sleep 0.5; done
}

note "godot:    $GODOT"
note "out:      $OUT"
note "ladder:   $LADDER (up to $MAX_SIZE)"
note "patterns: $PATTERNS"
note "profiles: $PROFILES"
note "steady:   ${STEADY_SECS}s per run, seed $SEED"

for profile in $PROFILES; do
  for pattern in $PATTERNS; do
    for size in $LADDER; do
      [ "$size" -gt "$MAX_SIZE" ] && break
      run_one "$profile" "$pattern" "$size"
      if ! "$GODOT" --headless --path "$REPO_ROOT" -s tools/stress_report.gd -- continue "$RUNS/$profile/$pattern/$size" \
          >"$RUNS/$profile/$pattern/$size/continue.log" 2>&1; then
        note "$profile/$pattern: ladder stops at $size ($(grep -h STRESS_TICK_P95 "$RUNS/$profile/$pattern/$size/continue.log" || echo 'no host report'))"
        break
      fi
    done
  done
done

"$GODOT" --headless --path "$REPO_ROOT" -s tools/stress_report.gd -- build "$RUNS" "$OUT" \
  "seconds=$STEADY_SECS" "seed=$SEED" "max=$MAX_SIZE" "profiles=$PROFILES" 2>&1 | tee "$OUT/report.log"
status=${PIPESTATUS[0]}
if grep -qE "SCRIPT ERROR|Parse Error|Compile Error" "$OUT/report.log" "$RUNS"/*/*/*/*.log 2>/dev/null; then
  fail "script/parse/compile errors in a run log"
  status=1
fi
note "report: $OUT/report.md"
exit "$status"
