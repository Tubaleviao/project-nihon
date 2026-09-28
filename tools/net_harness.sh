#!/usr/bin/env bash
# Phase 39 — the two-client network harness driver.
#
# Boots one HOST process and one CLIENT process of the real game on loopback, runs the
# scripted session (`--net-harness host` / `--net-harness client`), and fails when:
#
#   • a process exits non-zero, or is still running when the deadline passes;
#   • a side does not report the plan (its `HARNESS plan …` line, the step list it was
#     built with), or the two sides disagree about the plan;
#   • a side misses a step, or reports it twice;
#   • any step reports `fail` — a step whose subject is a refusal reports `refused`,
#     which is a pass, so this is not "did nothing go wrong" but "did the guard hold";
#   • the two sides' `detail` for a step disagree (the comparison channel is the log
#     line, so agreement IS the cross-process assertion).
#
# The step list is NOT duplicated here: it is read out of the plan line both processes
# print. Adding a step to `NetHarness.steps()` therefore extends what this driver
# checks, and a step one side stops reporting becomes a failure rather than a silent pass.
#
# Usage:
#   tools/net_harness.sh                # $GODOT or `godot` from PATH
#   GODOT=/tmp/godot/Godot_v4.7-stable_linux.x86_64 tools/net_harness.sh
#
# Env knobs: GODOT (binary), NET_HARNESS_TIMEOUT (seconds, default 300),
#            NET_HARNESS_LOGDIR (where the two logs land; default a fresh mktemp -d).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
TIMEOUT_SECS="${NET_HARNESS_TIMEOUT:-300}"
LOGDIR="${NET_HARNESS_LOGDIR:-$(mktemp -d)}"
HOST_LOG="$LOGDIR/net-harness-host.log"
CLIENT_LOG="$LOGDIR/net-harness-client.log"
FAILURES=0

mkdir -p "$LOGDIR"

fail() { echo "::error::net-harness: $*"; FAILURES=$((FAILURES + 1)); }
note() { echo "net-harness: $*"; }

# --- preflight -------------------------------------------------------------

if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
  echo "::error::net-harness: Godot binary not found ('$GODOT'). Set GODOT=/path/to/godot." >&2
  exit 2
fi
if [ ! -f "$REPO_ROOT/project.godot" ]; then
  echo "::error::net-harness: $REPO_ROOT does not look like the Godot project." >&2
  exit 2
fi

# A stale server on the port would be joined instead of our host, and the scenario would
# run against a process this driver does not control. Two processes, then, are what the
# port has to be free for; refuse to start otherwise.
if command -v ss >/dev/null 2>&1 && ss -ltn 2>/dev/null | grep -q ':7777 '; then
  echo "::error::net-harness: port 7777 is already in use — a stale host would be joined instead." >&2
  exit 2
fi

HOST_PID=""
CLIENT_PID=""

cleanup() {
  for pid in "$HOST_PID" "$CLIENT_PID"; do
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null
    fi
  done
}
trap cleanup EXIT

# --- boot the two peers ----------------------------------------------------

note "godot:    $GODOT"
note "logs:     $LOGDIR"
note "timeout:  ${TIMEOUT_SECS}s"

# No --quit on either side: the harness quits its own process when the scenario ends,
# which is what makes the exit-code check below mean something. --headless because
# nothing is rendered; the scenario is wire-level.
"$GODOT" --headless --path "$REPO_ROOT" -- --net-harness host >"$HOST_LOG" 2>&1 &
HOST_PID=$!

# The host has to be LISTENING before the client joins, or the client's first
# handshake races the socket.
deadline=$(( $(date +%s) + 60 ))
while ! grep -q 'listening on port' "$HOST_LOG" 2>/dev/null; do
  if ! kill -0 "$HOST_PID" 2>/dev/null; then
    fail "the host process exited before it reported a listening line"
    sed -n '1,40p' "$HOST_LOG"
    exit 1
  fi
  if [ "$(date +%s)" -gt "$deadline" ]; then
    fail "the host did not report a listening line within 60s"
    exit 1
  fi
  sleep 0.5
done
note "host listening"

"$GODOT" --headless --path "$REPO_ROOT" -- --net-harness client >"$CLIENT_LOG" 2>&1 &
CLIENT_PID=$!

# --- wait for both sides, inside the deadline ------------------------------

wait_for() {  # pid label
  local pid="$1" label="$2"
  local end=$(( $(date +%s) + TIMEOUT_SECS ))
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$(date +%s)" -gt "$end" ]; then
      fail "$label did not finish within ${TIMEOUT_SECS}s"
      return 1
    fi
    sleep 0.5
  done
  wait "$pid"
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    fail "$label exited $rc"
  fi
  return 0
}

wait_for "$HOST_PID" "host"
wait_for "$CLIENT_PID" "client"
HOST_PID=""
CLIENT_PID=""

# --- assert on the two log streams -----------------------------------------

plan_of() {  # logfile -> comma-joined plan, once
  awk '$1=="HARNESS" && $2=="plan" {print $4}' "$1" | head -n 1
}

steps_reported() {  # logfile step -> how many lines that side printed for it
  awk -v s="$2" '$1=="HARNESS" && $2==s' "$1" | wc -l | tr -d ' '
}

detail_of() {  # logfile step -> detail
  awk -v s="$2" '$1=="HARNESS" && $2==s {print $4}' "$1" | head -n 1
}

HOST_PLAN="$(plan_of "$HOST_LOG")"
CLIENT_PLAN="$(plan_of "$CLIENT_LOG")"

if [ -z "$HOST_PLAN" ] || [ -z "$CLIENT_PLAN" ]; then
  fail "a side never printed its plan line (host='$HOST_PLAN' client='$CLIENT_PLAN')"
  exit 1
fi
if [ "$HOST_PLAN" != "$CLIENT_PLAN" ]; then
  fail "the two sides ran different scenarios"
  note "host   plan: $HOST_PLAN"
  note "client plan: $CLIENT_PLAN"
  exit 1
fi

PASSED=0
while IFS=',' read -r entry; do
  [ -z "$entry" ] && continue
  # A `*` suffix in the plan marks a step whose details the two sides may legitimately
  # disagree on (see NetHarness.plan_detail): both verdicts still have to pass, but the
  # details are reported rather than compared.
  compare=1
  case "$entry" in
    *'*') compare=0; step="${entry%\*}" ;;
    *)    step="$entry" ;;
  esac

  # A step reported TWICE is not a pass with a spare line: the scenario is a sequence, so a
  # side that ran one step twice — a re-entered pump, a step table naming a step twice — has
  # not run the scenario either log describes. Checked HERE because everything below reads
  # the first matching line (`head -n 1`): without this, a second line is silently ignored
  # and the step is judged on the first one, which is how this check used to be claimed in
  # the header comment without existing in the code.
  hn="$(steps_reported "$HOST_LOG" "$step")"
  cn="$(steps_reported "$CLIENT_LOG" "$step")"
  if [ "$hn" -gt 1 ] || [ "$cn" -gt 1 ]; then
    fail "$step — reported twice (host=$hn client=$cn)"
    continue
  fi

  h="$(detail_of "$HOST_LOG" "$step")"
  c="$(detail_of "$CLIENT_LOG" "$step")"
  hv="$(awk -v s="$step" '$1=="HARNESS" && $2==s {print $3}' "$HOST_LOG" | head -n 1)"
  cv="$(awk -v s="$step" '$1=="HARNESS" && $2==s {print $3}' "$CLIENT_LOG" | head -n 1)"

  # A side that never reported the step is a failure, not a missing data point: the
  # scenario is a sequence, so a side that stopped early proves nothing about the steps
  # after it.
  if [ -z "$hv" ] || [ -z "$cv" ]; then
    fail "$step — host='${hv:-missing}($h)' client='${cv:-missing}($c)'"
    continue
  fi
  # The verdict is each side's own assertion; `ok` and `refused` are both passes
  # (`refused` is what an expected ABSENCE reports).
  case "$hv" in ok|refused) ;; *) fail "$step — host reported '$hv' ($h)"; continue ;; esac
  case "$cv" in ok|refused) ;; *) fail "$step — client reported '$cv' ($c)"; continue ;; esac
  # The only channel between the processes is the log line, so a comparing step's details
  # agreeing IS the cross-process assertion.
  if [ "$compare" = "1" ] && [ "$h" != "$c" ]; then
    fail "$step — the two sides disagree: host='$h' client='$c'"
    continue
  fi
  if [ "$compare" = "1" ]; then
    note "  ✓ $step  (host=$hv client=$cv $h)"
  else
    note "  ✓ $step  (host=$hv $h / client=$cv $c — details not compared)"
  fi
  PASSED=$((PASSED + 1))
done < <(printf '%s\n' "$HOST_PLAN" | tr ',' '\n')

PLANNED="$(printf '%s\n' "$HOST_PLAN" | tr ',' '\n' | grep -c .)"

echo
if [ "$FAILURES" -ne 0 ]; then
  echo "net-harness FAILED — $FAILURES problem(s); logs in $LOGDIR"
  exit 1
fi
echo "net-harness passed — $PASSED/$PLANNED steps agreed across both peers"
echo "  host log:   $HOST_LOG"
echo "  client log: $CLIENT_LOG"
