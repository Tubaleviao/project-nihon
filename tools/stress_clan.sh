#!/usr/bin/env bash
# Phase 202 — the clan loop, played: four bots found a clan, specialize, trade and build while a fifth
# tries what a non-member must be refused. A dedicated server with the host recorder and the clan probe,
# one bot process (5 bots, `--stress-scenario clan`), then `tools/stress_report.gd -- clan` renders
# `$STRESS_OUT/clan.{json,md}` and fails when a beat or a world-record check failed.
#
#   GODOT=/tmp/godot/Godot_v4.7-stable_linux.x86_64 tools/stress_clan.sh
# Env: GODOT (default `godot`), STRESS_OUT (default ./stress), CLAN_TIMEOUT (seconds for the scenario, default 3300).
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
OUT="${STRESS_OUT:-$REPO_ROOT/stress}"
TIMEOUT="${CLAN_TIMEOUT:-3300}"
mkdir -p "$OUT"
rm -f "$OUT"/clan_* "$OUT"/clan.json "$OUT"/clan.md "$OUT"/stop
stop="$OUT/stop"
host_json="$OUT/clan_host.json"

"$GODOT" --headless --path "$REPO_ROOT" -- --server --stress-host "$OUT/clan_recorder.json" --stress-clan "$host_json" \
  --stress-steady "$OUT/clan_steady" --stress-stop "$stop" --stress-pattern cluster >"$OUT/clan_host.log" 2>&1 &
host_pid=$!
trap 'kill "$host_pid" 2>/dev/null' EXIT
for _ in $(seq 1 180); do
  grep -q 'listening on port' "$OUT/clan_host.log" 2>/dev/null && break
  kill -0 "$host_pid" 2>/dev/null || { echo "::error::stress_clan: the host died before listening"; exit 1; }
  sleep 0.5
done

timeout "$TIMEOUT" "$GODOT" --headless --path "$REPO_ROOT" -- --stress-bots 5 --stress-pattern cluster --stress-seed 1 \
  --stress-seconds 5 --stress-scenario clan --stress-live "$host_json.live" --stress-clan-out "$OUT/clan_bots.json" \
  --stress-steady "$OUT/clan_steady" --stress-out "$OUT/clan_botsproc.json" >"$OUT/clan_bots.log" 2>&1
bots_status=$?
touch "$stop"
for _ in $(seq 1 60); do kill -0 "$host_pid" 2>/dev/null || break; sleep 1; done
[ "$bots_status" -ne 0 ] && echo "::error::stress_clan: the bot process exited $bots_status"

# Merge the bots' beats with the host's world record, then render and judge.
"$GODOT" --headless --path "$REPO_ROOT" -s tools/stress_report.gd -- clan-merge "$OUT/clan_bots.json" "$host_json" "$OUT/clan_raw.json" >"$OUT/clan_merge.log" 2>&1
"$GODOT" --headless --path "$REPO_ROOT" -s tools/stress_report.gd -- clan "$OUT/clan_raw.json" "$OUT" | tee "$OUT/clan_report.log"
status=${PIPESTATUS[0]}
if grep -qE "SCRIPT ERROR|Parse Error|Compile Error" "$OUT"/clan_*.log 2>/dev/null; then
  echo "::error::stress_clan: script/parse/compile errors in a log"
  status=1
fi
exit "$status"
