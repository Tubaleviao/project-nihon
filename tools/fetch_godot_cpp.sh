#!/bin/sh
# Pinned godot-cpp checkout into native/godot-cpp (gitignored). Phase 166.
# godot-cpp has no 4.7 tag; an extension built against 4.5 loads in 4.7
# (compatibility_minimum = "4.5" in native/nihon_native.gdextension).
set -eu
TAG="${GODOT_CPP_TAG:-godot-4.5-stable}"
DIR="$(cd "$(dirname "$0")/.." && pwd)/native/godot-cpp"
if [ -d "$DIR/.git" ]; then
	exit 0
fi
git clone --depth 1 --branch "$TAG" https://github.com/godotengine/godot-cpp "$DIR"
