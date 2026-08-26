#!/usr/bin/env bash
set -euo pipefail

# Build the production asset `.pck` override from the private assets submodule,
# using Godot's own exporter (`--export-pack`) rather than a custom packer.
#
# The `assets-prod/` submodule must be initialized first:
#   git submodule update --init assets-prod
#
# `assets-prod/` carries a `.gdignore`, so Godot's scanner (editor and exporter
# alike) never touches it directly — which also means `--export-pack` cannot
# source from it in place. Exporting straight from the main project is also
# out: Godot's exporter always walks the *entire* project's resource graph
# regardless of export_filter/include_filter/exclude_filter, so a preset
# living in this project's own export_presets.cfg cannot be scoped down to
# "just the assets" — it would bundle the whole game's scripts and scenes
# into what's supposed to be a small assets-only pack.
#
# So this script stages a plain copy of assets-prod/ at
# tools/pack_project/_overlay/ (gitignored, always removed on exit) and runs
# the exporter against tools/pack_project/ — a disposable, standalone Godot
# project containing nothing else. Its "AssetsPack" preset force-includes
# `_overlay/*` (needed since `.raw`-suffixed files aren't recognized/imported
# resources and are otherwise skipped) with nothing else in scope to leak in.
#
# The resulting pck stores paths as res://_overlay/<rel> — read back through
# that same namespace at runtime by AssetOverlay, not by colliding with the
# placeholder's res://assets/<rel> path (--export-pack cannot remap paths).
#
# Output: `assets.pck` at the repo root. AssetOverlay (autoload) mounts it over
# res:// at startup. The .pck is gitignored — it must never be committed to
# the public repo.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT_BIN:-godot}"
PACK_PROJECT="$ROOT/tools/pack_project"
STAGE="$PACK_PROJECT/_overlay"

if [ ! -d "$ROOT/assets-prod" ] || [ -z "$(ls -A "$ROOT/assets-prod" 2>/dev/null)" ]; then
	echo "error: assets-prod submodule empty or missing — run: git submodule update --init assets-prod" >&2
	exit 1
fi

cleanup() { rm -rf "$STAGE" "$PACK_PROJECT/.godot"; }
trap cleanup EXIT

rm -rf "$STAGE"
mkdir -p "$STAGE"
rsync -a \
	--exclude='.git' \
	--exclude='.gitattributes' \
	--exclude='.gdignore' \
	--exclude='README.md' \
	"$ROOT/assets-prod/" "$STAGE/"

if [ -z "$(ls -A "$STAGE" 2>/dev/null)" ]; then
	echo "error: nothing to pack — assets-prod contains no production files (only metadata)" >&2
	exit 1
fi

"$GODOT" --headless --path "$PACK_PROJECT" --export-pack "AssetsPack" "$ROOT/assets.pck"
