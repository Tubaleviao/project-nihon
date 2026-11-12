#!/usr/bin/env bash
# Phase 252 — the contributor's front door. Fails when LICENSE, CONTRIBUTING.md,
# CODE_OF_CONDUCT.md, SECURITY.md or THIRD_PARTY.md is missing or empty, when package.json has no
# "license" field, or when that field differs from the SPDX identifier of the LICENSE text.
#
#   tools/check_front_door.sh              # the repository this script lives in
#   ROOT=/some/dir tools/check_front_door.sh
#   tools/check_front_door.sh --self-test  # proves the check rejects each kind of break
set -uo pipefail

check() {
  local root="$1" bad=0 f
  for f in LICENSE CONTRIBUTING.md CODE_OF_CONDUCT.md SECURITY.md THIRD_PARTY.md; do
    if [ ! -s "$root/$f" ]; then
      echo "check_front_door: $f is missing or empty" >&2
      bad=1
    fi
  done

  local declared=""
  if [ -f "$root/package.json" ]; then
    declared="$(sed -n 's/^[[:space:]]*"license"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$root/package.json" | head -n 1)"
  fi
  if [ -z "$declared" ]; then
    echo "check_front_door: package.json has no \"license\" field" >&2
    bad=1
  fi

  if [ -s "$root/LICENSE" ]; then
    local spdx=""
    if grep -q "^MIT License" "$root/LICENSE"; then
      spdx="MIT"
    elif grep -q "Apache License" "$root/LICENSE" && grep -q "Version 2.0" "$root/LICENSE"; then
      spdx="Apache-2.0"
    fi
    if [ -z "$spdx" ]; then
      echo "check_front_door: LICENSE is not a licence this check recognises (MIT, Apache-2.0)" >&2
      bad=1
    elif [ -n "$declared" ] && [ "$declared" != "$spdx" ]; then
      echo "check_front_door: package.json license \"$declared\" differs from LICENSE ($spdx)" >&2
      bad=1
    fi
  fi
  return "$bad"
}

self_test() {
  local here fail=0
  here="$(cd "$(dirname "$0")/.." && pwd)"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT  # tmp is global so the trap can see it

  fresh() {
    rm -rf "$tmp/r" && mkdir "$tmp/r"
    local f
    for f in LICENSE CONTRIBUTING.md CODE_OF_CONDUCT.md SECURITY.md THIRD_PARTY.md; do
      cp "$here/$f" "$tmp/r/$f"
    done
    printf '{\n  "license": "MIT"\n}\n' > "$tmp/r/package.json"
  }
  expect() { # expect <pass|fail> <description>
    if check "$tmp/r" 2>/dev/null; then got=pass; else got=fail; fi
    if [ "$got" != "$1" ]; then
      echo "self-test: $2: expected $1, got $got" >&2
      fail=1
    fi
  }

  fresh;                                                    expect pass "the repository's own files"
  fresh; rm "$tmp/r/LICENSE";                               expect fail "LICENSE missing"
  fresh; rm "$tmp/r/CONTRIBUTING.md";                       expect fail "CONTRIBUTING.md missing"
  fresh; : > "$tmp/r/SECURITY.md";                          expect fail "SECURITY.md empty"
  fresh; rm "$tmp/r/CODE_OF_CONDUCT.md";                    expect fail "CODE_OF_CONDUCT.md missing"
  fresh; rm "$tmp/r/THIRD_PARTY.md";                        expect fail "THIRD_PARTY.md missing"
  fresh; printf '{}\n' > "$tmp/r/package.json";             expect fail "no license field"
  fresh; printf '{"license": "Apache-2.0"}\n' > "$tmp/r/package.json"; expect fail "license differs from LICENSE"
  fresh; printf 'All rights reserved.\n' > "$tmp/r/LICENSE"; expect fail "unrecognised LICENSE text"

  if [ "$fail" -eq 0 ]; then echo "check_front_door: self-test ok"; fi
  return "$fail"
}

if [ "${1:-}" = "--self-test" ]; then
  self_test
  exit $?
fi

root="${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
if check "$root"; then
  echo "check_front_door: ok"
else
  exit 1
fi
