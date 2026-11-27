#!/usr/bin/env bash
# Phase 245 / 302 — bake the planet for the fabric seed and check the output.
# Shared by release.yml (publishes the bake) and ci.yml (pull requests), so both run the same command.
#
#   GODOT=/path/to/godot tools/bake_planet.sh [outdir]     # outdir defaults to build/bake
#
# Runs `--bake-planet <outdir>` (a user arg, after `--`), then requires: the `BAKE ` line in the log,
# exactly one planet_*.bin and its .sha256, and the .sha256 equal to the SHA-256 of the .bin
# (the hash format PlanetBake.hash_hex writes). Exit 1 on any failure.
set -euo pipefail

cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT="${1:-build/bake}"
LOG="${BAKE_LOG:-$(mktemp)}"

mkdir -p "$OUT"
"$GODOT" --headless --path . --quit-after 5 -- --bake-planet "$OUT" | tee "$LOG"

if ! grep -q '^BAKE ' "$LOG"; then
	echo "::error::--bake-planet did not print a BAKE line" >&2
	exit 1
fi

shopt -s nullglob
bins=("$OUT"/planet_*.bin)
if [ "${#bins[@]}" -ne 1 ]; then
	echo "::error::expected one planet_*.bin in $OUT, found ${#bins[@]}" >&2
	exit 1
fi
bin="${bins[0]}"
hashfile="$bin.sha256"
if [ ! -s "$bin" ] || [ ! -s "$hashfile" ]; then
	echo "::error::$bin or $hashfile is missing or empty" >&2
	exit 1
fi

expected="$(tr -d '[:space:]' < "$hashfile")"
actual="$(sha256sum "$bin" | cut -d' ' -f1)"
if [ "$expected" != "$actual" ]; then
	echo "::error::$hashfile ($expected) does not match the SHA-256 of $bin ($actual)" >&2
	exit 1
fi
if ! grep -q "$actual" "$LOG"; then
	echo "::error::the BAKE line does not report the baked hash $actual" >&2
	exit 1
fi
echo "bake ok: $bin sha256=$actual"
