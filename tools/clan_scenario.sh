#!/usr/bin/env bash
# Phase 202 — the clan loop scenario: a dedicated server and one bot process that plays five bots.
# Writes stress/clan.{json,md}; exits non-zero when any beat fails.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
OUT="${CLAN_OUT:-$REPO_ROOT/stress}"
mkdir -p "$OUT/clan_run"
dir="$OUT/clan_run"
rm -f "$dir/steady" "$dir/stop"
"$GODOT" --headless --path "$REPO_ROOT" -- --server --stress-host "$dir/host.json" \
  --stress-steady "$dir/steady" --stress-stop "$dir/stop" --stress-pattern cluster >"$dir/host.log" 2>&1 &
host=$!
for _ in $(seq 1 120); do grep -q '\[Server\] listening on port' "$dir/host.log" 2>/dev/null && break; sleep 1; done
timeout 600 "$GODOT" --headless --path "$REPO_ROOT" -- --stress-bots 5 --stress-scenario clan \
  --stress-scenario-out "$OUT/clan" --stress-steady "$dir/steady" --stress-seconds 900 \
  >"$dir/bots.log" 2>&1
code=$?
touch "$dir/stop"
sleep 2; kill "$host" 2>/dev/null; wait "$host" 2>/dev/null
tail -5 "$dir/bots.log"
exit $code
