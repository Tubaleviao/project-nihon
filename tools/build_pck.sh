#!/usr/bin/env bash
set -euo pipefail

# Build the production asset `.pck` override from the private assets submodule.
#
# The `assets-prod/` submodule must be initialized first:
#   git submodule update --init assets-prod
#
# Output: `assets.pck` at the repo root. AssetOverlay (autoload) mounts it over
# res:// at startup, replacing the committed placeholders with production art.
# The .pck is gitignored — it must never be committed to the public repo.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT_BIN:-godot}"

if [ ! -d "$ROOT/assets-prod" ] || [ -z "$(ls -A "$ROOT/assets-prod" 2>/dev/null)" ]; then
	echo "error: assets-prod submodule empty or missing — run: git submodule update --init assets-prod" >&2
	exit 1
fi

"$GODOT" --headless --path "$ROOT" --script res://tools/pack_pck.gd
