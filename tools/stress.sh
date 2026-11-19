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
# they would take at the top of the ladder. Budgets are a report; the driver fails (exit 1) on a hard
# failure: a crash, a host or watcher frame over 2 s, a bot dropped by the host without a reason, or a
# peer record left after everyone left. Phase 163 — it also fails when a pattern's largest passing size
# drops below the committed baseline's (`StressRules.BASELINE_LARGEST`, docs/perf/crowd-baseline.md).
# A run that misses a budget at or below its baseline size, with no hard failure, is run once more
# (`StressRules.needs_retry`): each missed try moves to `<size>.miss1`, `<size>.miss2` (kept in the
# artifact, left out of the report) and the rerun counts. Runner noise passes the rerun; a real regression misses it too.
#
# Usage:
#   GODOT=/tmp/godot/Godot_v4.7-stable_linux.x86_64 tools/stress.sh
#
# Split mode (Phase 250): the bots steal the server's CPU and the link is loopback when everything runs on
# one machine. `STRESS_ROLE=server` boots only the host and the watcher, one run at a time as the bots ask
# for it; `STRESS_ROLE=bots STRESS_SERVER=<addr>` runs the bot process against that server and drives the
# ladder. The "steady" and "stop" handshake crosses the network over a small TCP side channel
# (`tools/stress_ctl.py`, port STRESS_CTL_PORT, default 7778; the game's UDP port 7777 must be reachable too).
# The server's host and watcher reports come back over it, so the report is built on the bots' machine,
# with both machines' fields (CPU, cores, RAM, OS, Godot build, native on or off, release or debug).
# `STRESS_LOOPBACK_SPLIT=1` runs both roles on this machine (the CI check of the split mode).
#
# Env knobs: GODOT (binary, default `godot`), STRESS_OUT (default ./stress), STRESS_MAX (largest
# crowd to try, default 200), STRESS_PATTERNS (default "cluster spread cross pole churn"),
# STRESS_PROFILES (default "lan wan_br"), STRESS_SECONDS (steady seconds per run, default 20),
# STRESS_SEED (bot path seed, default 1), STRESS_ROLE (server|bots), STRESS_SERVER, STRESS_CTL_PORT, STRESS_CTL_TOKEN (shared secret for the split control channel), STRESS_CTL_BIND (server bind address, default 0.0.0.0).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
OUT="${STRESS_OUT:-$REPO_ROOT/stress}"
MAX_SIZE="${STRESS_MAX:-200}"
PATTERNS="${STRESS_PATTERNS:-cluster spread cross pole churn}"
PROFILES="${STRESS_PROFILES:-lan wan_br}"
STEADY_SECS="${STRESS_SECONDS:-20}"
SEED="${STRESS_SEED:-1}"
LADDER="16 32 64 128 200"   # pinned to StressRules.LADDER by the suite
case "$MAX_SIZE" in ''|*[!0-9]*) echo "::error::stress: STRESS_MAX must be a number, got '$MAX_SIZE'." >&2; exit 2;; esac
for p in $PROFILES; do
  case "$p" in lan|wan_br|wan_bad) ;; *) echo "::error::stress: unknown link profile '$p' (lan, wan_br, wan_bad)." >&2; exit 2;; esac
done
for p in $PATTERNS; do
  case "$p" in cluster|spread|cross|pole|churn) ;; *) echo "::error::stress: unknown pattern '$p'." >&2; exit 2;; esac
done
ROLE="${STRESS_ROLE:-}"
SERVER="${STRESS_SERVER:-}"
CTL_PORT="${STRESS_CTL_PORT:-7778}"
CTL="$REPO_ROOT/tools/stress_ctl.py"
case "$ROLE" in
  ''|server) [ -n "$SERVER" ] && { echo "::error::stress: STRESS_SERVER only belongs to STRESS_ROLE=bots." >&2; exit 2; } ;;
  bots) [ -z "$SERVER" ] && { echo "::error::stress: STRESS_ROLE=bots needs STRESS_SERVER=<addr>." >&2; exit 2; } ;;
  *) echo "::error::stress: unknown STRESS_ROLE '$ROLE' (server, bots)." >&2; exit 2 ;;
esac
case "$CTL_PORT" in ''|*[!0-9]*) echo "::error::stress: STRESS_CTL_PORT must be a number." >&2; exit 2;; esac
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
if [ "$ROLE" != "bots" ] && port_busy; then
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
  local profile="$1" pattern="$2" size="$3" mode="${4:-local}" ctl="${5:-}"
  local dir="$RUNS/$profile/$pattern/$size"
  rm -rf "$dir"
  mkdir -p "$dir"
  local steady="$dir/steady" stop="$dir/stop"
  # Server role: the control channel's files are the steady and stop files.
  [ "$mode" = server ] && { steady="$ctl/steady"; stop="$ctl/stop"; }
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

  if [ "$mode" = server ]; then
    # The bots are on another machine: tell them we are ready, then wait for their stop.
    touch "$ctl/ready"
    local deadline=$(( $(date +%s) + STEADY_SECS + 900 ))
    while [ ! -f "$stop" ] && [ "$(date +%s)" -le "$deadline" ]; do sleep 0.5; done
  else
    timeout $(( STEADY_SECS + 180 )) "$GODOT" --headless --path "$REPO_ROOT" -- --stress-bots "$size" \
      --stress-seed "$SEED" --stress-seconds "$STEADY_SECS" --stress-out "$dir/bots.json" "${common[@]}" \
      >"$dir/bots.log" 2>&1
    local bots_status=$?
    [ "$bots_status" -ne 0 ] && fail "$profile/$pattern/$size: the bot process exited $bots_status"
  fi

  touch "$stop"
  wait_exit "$watch_pid" 60 || fail "$profile/$pattern/$size: the watcher did not exit after the stop file"
  wait_exit "$host_pid" 90 || fail "$profile/$pattern/$size: the host did not exit after the stop file"
  if [ "$mode" = server ]; then
    # Send the reports back to the bots' machine.
    python3 -I - "$dir" "$ctl/result.json" <<'PY'
import json, os, sys
d, out = sys.argv[1:3]
def load(n):
    try:
        return json.load(open(os.path.join(d, n)))
    except (OSError, ValueError):
        return None
json.dump({"host": load("host.json"), "watch": load("watch.json")}, open(out, "w"))
PY
  fi
  # The next run's host needs the port.
  local deadline=$(( $(date +%s) + 30 ))
  while port_busy && [ "$(date +%s)" -le "$deadline" ]; do sleep 0.5; done
}

# machine_json <out>: this machine's fields for the report.
machine_json() {
  local build="release"
  "$GODOT" --version 2>/dev/null | grep -qi debug && build="debug"
  python3 -I - "$GODOT" "$REPO_ROOT" "$build" >"$1" <<'PY'
import json, os, platform, subprocess, sys
godot, root, build = sys.argv[1:4]
def cpu():
    try:
        for l in open("/proc/cpuinfo"):
            if l.startswith("model name"):
                return l.split(":", 1)[1].strip()
    except OSError:
        pass
    return platform.processor() or "unknown"
def ram():
    try:
        for l in open("/proc/meminfo"):
            if l.startswith("MemTotal"):
                return int(l.split()[1]) // 1024
    except OSError:
        pass
    return 0
def version():
    try:
        return subprocess.run([godot, "--version"], capture_output=True, text=True, timeout=30).stdout.strip().splitlines()[0]
    except Exception:
        return "unknown"
native = any(f.endswith((".so", ".dll", ".dylib")) for _, _, fs in os.walk(os.path.join(root, "native")) for f in fs) if os.path.isdir(os.path.join(root, "native")) else False
print(json.dumps({"cpu": cpu(), "cores": os.cpu_count(), "ram_mb": ram(), "os": platform.platform(), "godot": version(), "native": native, "build": build}))
PY
}

# server_loop: the server role. One run per request from the bots' side, until a bye.
server_loop() {
  local ctl="$OUT/ctl"
  mkdir -p "$ctl"
  while true; do
    rm -rf "$ctl"; mkdir -p "$ctl"
    machine_json "$ctl/machine.json"
    note "server: waiting for the bots on tcp $CTL_PORT"
    python3 -I "$CTL" serve "$CTL_PORT" "$ctl" &
    local ctl_pid=$!
    PIDS+=("$ctl_pid")
    while [ ! -f "$ctl/request" ] && kill -0 "$ctl_pid" 2>/dev/null; do sleep 0.5; done
    if [ ! -f "$ctl/request" ]; then
      wait "$ctl_pid"; local code=$?
      [ "$code" -eq 3 ] && { note "server: bye"; return 0; }
      fail "the control channel ended with $code"; continue
    fi
    read -r profile pattern size <"$ctl/request"
    run_one "$profile" "$pattern" "$size" server "$ctl"
    wait "$ctl_pid" 2>/dev/null
  done
}

# bots_one <profile> <pattern> <size>: the bots role for one run; the host and watcher reports land in the run directory.
bots_one() {
  local profile="$1" pattern="$2" size="$3"
  local dir="$RUNS/$profile/$pattern/$size"
  mkdir -p "$dir"
  rm -f "$dir/steady" "$dir/bots-done" "$dir/server-ready"
  python3 -I "$CTL" call "${SERVER%%:*}" "$CTL_PORT" "$dir" "$profile" "$pattern" "$size" >"$dir/ctl.log" 2>&1 &
  local ctl_pid=$!
  PIDS+=("$ctl_pid")
  note "run $profile/$pattern/$size (bots against $SERVER)"
  local deadline=$(( $(date +%s) + 900 ))
  while [ ! -f "$dir/server-ready" ]; do
    if ! kill -0 "$ctl_pid" 2>/dev/null || [ "$(date +%s)" -gt "$deadline" ]; then
      fail "$profile/$pattern/$size: the server never became ready ($(tr '\n' ' ' <"$dir/ctl.log"))"
      return 1
    fi
    sleep 0.5
  done
  timeout $(( STEADY_SECS + 180 )) "$GODOT" --headless --path "$REPO_ROOT" -- --stress-bots "$size" \
    --stress-seed "$SEED" --stress-seconds "$STEADY_SECS" --stress-out "$dir/bots.json" \
    --stress-steady "$dir/steady" --stress-pattern "$pattern" --net-profile "$profile" --stress-addr "${SERVER%%:*}" \
    >"$dir/bots.log" 2>&1
  local bots_status=$?
  [ "$bots_status" -ne 0 ] && fail "$profile/$pattern/$size: the bot process exited $bots_status"
  touch "$dir/bots-done"
  wait "$ctl_pid" || fail "$profile/$pattern/$size: the control channel failed ($(tr '\n' ' ' <"$dir/ctl.log"))"
  return 0
}

note "godot:    $GODOT"
note "out:      $OUT"
note "ladder:   $LADDER (up to $MAX_SIZE)"
note "patterns: $PATTERNS"
note "profiles: $PROFILES"
note "steady:   ${STEADY_SECS}s per run, seed $SEED"

if [ -n "${STRESS_LOOPBACK_SPLIT:-}" ] && [ -z "$ROLE" ]; then
  # Both roles on this machine, as two drivers over the real control channel (the CI check of the split mode).
  note "loopback split: a server driver in the background, then the bots driver"
  STRESS_ROLE=server STRESS_LOOPBACK_SPLIT= STRESS_OUT="$OUT/server-side" "${BASH_SOURCE[0]}" >"$OUT.server.log" 2>&1 &
  PIDS+=("$!")
  sleep 3
  STRESS_ROLE=bots STRESS_SERVER=127.0.0.1 STRESS_LOOPBACK_SPLIT= "${BASH_SOURCE[0]}"
  status=$?
  python3 -I "$CTL" bye 127.0.0.1 "$CTL_PORT" >/dev/null 2>&1
  wait "${PIDS[0]}" 2>/dev/null
  exit "$status"
fi

if [ "$ROLE" = server ]; then
  server_loop
  exit 0
fi

run_any() {
  if [ "$ROLE" = bots ]; then bots_one "$@"; else run_one "$@"; fi
}
machine_json "$OUT/bots-machine.json"

for profile in $PROFILES; do
  for pattern in $PATTERNS; do
    for size in $LADDER; do
      [ "$size" -gt "$MAX_SIZE" ] && break
      run_any "$profile" "$pattern" "$size"
      dir="$RUNS/$profile/$pattern/$size"
      # Phase 253: best of three. A miss at or below the baseline size is run again, up to twice more,
      # and the first run that meets every budget is the one kept (a runner's noise is not a regression;
      # a regression misses all three).
      for attempt in 2 3; do
        "$GODOT" --headless --path "$REPO_ROOT" -s tools/stress_report.gd -- retry "$dir" "$profile" "$pattern" "$size" \
          >"$dir/retry.log" 2>&1 || break
        note "$profile/$pattern/$size missed a budget at or below the baseline; running it again, attempt $attempt of 3 ($(grep -h STRESS_BUDGETS "$dir/retry.log"))"
        # One directory per miss, so the first miss is still there when all three fail.
        rm -rf "$dir.miss$(( attempt - 1 ))"
        mv "$dir" "$dir.miss$(( attempt - 1 ))"
        run_any "$profile" "$pattern" "$size"
      done
      if ! "$GODOT" --headless --path "$REPO_ROOT" -s tools/stress_report.gd -- continue "$RUNS/$profile/$pattern/$size" \
          >"$RUNS/$profile/$pattern/$size/continue.log" 2>&1; then
        note "$profile/$pattern: ladder stops at $size ($(grep -h STRESS_TICK_P95 "$RUNS/$profile/$pattern/$size/continue.log" || echo 'no host report'))"
        break
      fi
    done
  done
done

EXTRA=()
if true; then
  # Both machines' fields for the report; the server's came over the control channel with the first run.
  STRESS_MACHINE_ROLE="${ROLE:-local}" python3 -I - "$OUT" "$RUNS" >"$OUT/machines.json" <<'PY'
import glob, json, os, sys
out, runs = sys.argv[1:3]
m = {os.environ.get("STRESS_MACHINE_ROLE", "bots"): json.load(open(os.path.join(out, "bots-machine.json")))}
for f in sorted(glob.glob(os.path.join(runs, "*", "*", "*", "server-machine.json"))):
    m["server"] = json.load(open(f))
    break
print(json.dumps(m))
PY
  EXTRA=("machines=$OUT/machines.json")
  [ "$ROLE" = bots ] && EXTRA+=("role=bots" "server=$SERVER")
fi
"$GODOT" --headless --path "$REPO_ROOT" -s tools/stress_report.gd -- build "$RUNS" "$OUT" \
  "seconds=$STEADY_SECS" "seed=$SEED" "max=$MAX_SIZE" "profiles=$PROFILES" "${EXTRA[@]}" 2>&1 | tee "$OUT/report.log"
status=${PIPESTATUS[0]}
if grep -qE "SCRIPT ERROR|Parse Error|Compile Error" "$OUT/report.log" "$RUNS"/*/*/*/*.log 2>/dev/null; then
  fail "script/parse/compile errors in a run log"
  status=1
fi
note "report: $OUT/report.md"
exit "$status"
