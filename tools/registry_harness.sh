#!/usr/bin/env bash
# Phase 298 — the server-list harness driver.
#
# Boots, on loopback, a registry (`--registry`), two public dedicated servers (`--server --public`, worlds
# "Alpha" and "Beta", each with its own save folder) and one client that opens the real main menu and plays the
# Join page's Public servers tab (`--menu-public-join`). It fails when:
#
#   • the client's list does not show both hosts with their players and ping (PUBLIC_SHOWN_LINE + one row line each);
#   • after the driver stops Alpha, Alpha does not drop out of the client's list within DROP_LIMIT_S (100 s: the
#     registry drops an entry that missed three 30 s heartbeats);
#   • the client does not then join Beta from the list (`[Menu] joining Beta`, then the joined line) and exit 0;
#   • any process exits non-zero, or a deadline passes.
#
# The client keeps its cached list and recent servers under user://registry-harness/ and each host its save there, so
# a run never touches a player's own files.
#
# Usage:
#   GODOT=/tmp/godot/Godot_v4.7-stable_linux.x86_64 tools/registry_harness.sh
#
# Env knobs: GODOT (binary), REGISTRY_HARNESS_LOGDIR (default a fresh mktemp -d), REGISTRY_HARNESS_PORT (the base
# port, default 7720: the registry on it, Alpha on +2/+3, Beta on +4/+5), REGISTRY_HARNESS_ADDRESS (127.0.0.1 or
# ::1, default 127.0.0.1; ::1 on a runner without it is skipped with a logged reason).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
BASE="${REGISTRY_HARNESS_PORT:-7720}"
ADDRESS="${REGISTRY_HARNESS_ADDRESS:-127.0.0.1}"
LOGDIR="${REGISTRY_HARNESS_LOGDIR:-$(mktemp -d)}"
DROP_LIMIT_S=100
SHOW_TIMEOUT_S=180
JOIN_TIMEOUT_S=180
FAILURES=0

fail() { echo "::error::registry-harness: $*"; FAILURES=$((FAILURES + 1)); }
note() { echo "registry-harness: $*"; }

if ! [[ "$BASE" =~ ^[0-9]+$ ]] || [ "$BASE" -lt 1 ] || [ "$BASE" -gt 65530 ]; then
  echo "::error::registry-harness: REGISTRY_HARNESS_PORT must be 1-65530 (got '$BASE')" >&2
  exit 2
fi
case "$ADDRESS" in
  127.0.0.1) REGISTRY="127.0.0.1:$BASE" ;;
  ::1)
    if ! { ip -6 addr show dev lo 2>/dev/null | grep -q '::1/128'; }; then
      echo "registry-harness: skipped — this runner has no IPv6 loopback (::1)"
      exit 0
    fi
    REGISTRY="[::1]:$BASE" ;;
  *) echo "::error::registry-harness: REGISTRY_HARNESS_ADDRESS must be 127.0.0.1 or ::1 (got '$ADDRESS')" >&2; exit 2 ;;
esac
if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
  echo "::error::registry-harness: Godot binary not found ('$GODOT'). Set GODOT=/path/to/godot." >&2
  exit 2
fi
# A stale process on one of the ports would answer instead of ours.
if command -v ss >/dev/null 2>&1; then
  if ss -ltn 2>/dev/null | grep -qE ":$BASE " || ss -lun 2>/dev/null | grep -qE ":($((BASE + 2))|$((BASE + 3))|$((BASE + 4))|$((BASE + 5))) "; then
    echo "::error::registry-harness: a port in $BASE-$((BASE + 5)) is already in use" >&2
    exit 2
  fi
fi

mkdir -p "$LOGDIR"
REG_LOG="$LOGDIR/registry.log"
A_LOG="$LOGDIR/host-alpha.log"
B_LOG="$LOGDIR/host-beta.log"
C_LOG="$LOGDIR/client.log"
REG_PID=""; A_PID=""; B_PID=""; C_PID=""

cleanup() {
  for pid in "$C_PID" "$A_PID" "$B_PID" "$REG_PID"; do
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null
    fi
  done
}
trap cleanup EXIT

wait_line() {  # log pattern pid seconds label
  local log="$1" pat="$2" pid="$3" secs="$4" label="$5"
  local end=$(( $(date +%s) + secs ))
  while ! grep -qF -- "$pat" "$log" 2>/dev/null; do
    if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
      fail "$label exited before '$pat'"
      tail -n 30 "$log"
      return 1
    fi
    if [ "$(date +%s)" -gt "$end" ]; then
      fail "$label did not print '$pat' within ${secs}s"
      tail -n 30 "$log"
      return 1
    fi
    sleep 0.5
  done
  return 0
}

note "godot:    $GODOT"
note "logs:     $LOGDIR"
note "registry: $REGISTRY"

"$GODOT" --headless --path "$REPO_ROOT" -- --registry "$BASE" >"$REG_LOG" 2>&1 &
REG_PID=$!
wait_line "$REG_LOG" "[Registry] listening on port $BASE" "$REG_PID" 60 "the registry" || exit 1

host() {  # name port save
  exec "$GODOT" --headless --path "$REPO_ROOT" -- --server --public --port "$2" --world-name "$1" --region sa \
    --registries "$REGISTRY" --save-dir "user://registry-harness/$3/"
}
host Alpha "$((BASE + 2))" alpha >"$A_LOG" 2>&1 &
A_PID=$!
host Beta "$((BASE + 4))" beta >"$B_LOG" 2>&1 &
B_PID=$!
wait_line "$A_LOG" "listening on port $((BASE + 2))" "$A_PID" 120 "host Alpha" || exit 1
wait_line "$B_LOG" "listening on port $((BASE + 4))" "$B_PID" 120 "host Beta" || exit 1
note "both hosts listening"

"$GODOT" --headless --path "$REPO_ROOT" -- --menu-public-join --registries "$REGISTRY" >"$C_LOG" 2>&1 &
C_PID=$!
wait_line "$C_LOG" "[Menu] public list shows" "$C_PID" "$SHOW_TIMEOUT_S" "the client" || exit 1
for name in Alpha Beta; do
  if ! grep -qE "^\[Menu\] public row $name players [0-9]+/[0-9]+ ping [0-9]+ ms" "$C_LOG"; then
    fail "the client's list does not show $name with its players and ping"
  fi
done
grep -E '^\[Menu\] public row' "$C_LOG" | sed 's/^/registry-harness:   /'
[ "$FAILURES" -eq 0 ] || exit 1

# The clock starts before the kill, so the measured time is never shorter than the real one. Worst case: the
# registry drops an entry 92 s after its last heartbeat (sent at most just before the stop), its sweep runs once a
# second and the harness client re-fetches every 3 s, about 96 s against the 100 s limit.
STOPPED=$(date +%s)
note "stopping Alpha"
kill "$A_PID" 2>/dev/null
wait "$A_PID" 2>/dev/null
A_PID=""
wait_line "$C_LOG" "[Menu] public list dropped Alpha" "$C_PID" "$((DROP_LIMIT_S + 20))" "the client" || exit 1
DROPPED_AFTER=$(( $(date +%s) - STOPPED ))
note "Alpha left the client's list ${DROPPED_AFTER}s after it stopped"
if [ "$DROPPED_AFTER" -gt "$DROP_LIMIT_S" ]; then
  fail "Alpha took ${DROPPED_AFTER}s to leave the list (limit ${DROP_LIMIT_S}s)"
fi
if ! grep -q "\[Registry\] dropped" "$REG_LOG"; then
  fail "the registry never logged dropping Alpha"
fi

wait_line "$C_LOG" "[Menu] joining Beta from the public list" "$C_PID" 30 "the client" || exit 1
wait_line "$C_LOG" "[Menu] joined from the main menu" "$C_PID" "$JOIN_TIMEOUT_S" "the client" || exit 1
end=$(( $(date +%s) + 60 ))
while kill -0 "$C_PID" 2>/dev/null && [ "$(date +%s)" -le "$end" ]; do sleep 0.5; done
if kill -0 "$C_PID" 2>/dev/null; then
  fail "the client did not quit after joining"
else
  wait "$C_PID"
  rc=$?
  [ "$rc" -eq 0 ] || fail "the client exited $rc"
fi
C_PID=""
if ! grep -q "^\[Server\] joined player" "$B_LOG"; then
  fail "Beta never logged the client joining"
fi

for log in "$REG_LOG" "$B_LOG" "$C_LOG"; do
  if grep -qE "SCRIPT ERROR|Parse Error|Compile Error" "$log"; then
    fail "$(basename "$log") has a script error"
    grep -nE "SCRIPT ERROR|Parse Error|Compile Error" "$log" | head -5
  fi
done

if [ "$FAILURES" -ne 0 ]; then
  echo "registry-harness: FAILED ($FAILURES)"
  exit 1
fi
echo "registry-harness: PASS"
