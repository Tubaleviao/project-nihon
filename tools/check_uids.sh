#!/usr/bin/env bash
# Phase 254 — Godot 4.4+ keys scripts and shaders by their `.uid` sidecar. A tracked `.gd` or
# `.gdshader` without a tracked `.uid` is regenerated differently on every clone. Fails on any, and
# on a `.uid` whose script is gone. `.tscn` files carry their uid in the header, so they have no
# sidecar and are not checked.
#
#   tools/check_uids.sh              # the repository this script lives in
#   tools/check_uids.sh --self-test  # proves the check rejects an untracked .uid
set -uo pipefail

check() {
  local root="$1" bad=0 f
  while IFS= read -r f; do
    if ! git -C "$root" ls-files --error-unmatch -- "$f.uid" >/dev/null 2>&1; then
      echo "check_uids: $f has no tracked $f.uid" >&2
      bad=1
    fi
  done < <(git -C "$root" ls-files -- '*.gd' '*.gdshader')
  while IFS= read -r f; do
    if [ ! -e "$root/${f%.uid}" ]; then
      echo "check_uids: $f has no script beside it" >&2
      bad=1
    fi
  done < <(git -C "$root" ls-files -- '*.uid')
  return $bad
}

if [ "${1:-}" = "--self-test" ]; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  git -C "$tmp" init -q
  echo "extends Node" > "$tmp/a.gd"
  echo "uid://abc" > "$tmp/a.gd.uid"
  git -C "$tmp" add -A
  check "$tmp" 2>/dev/null || { echo "check_uids self-test: a complete pair was rejected" >&2; exit 1; }
  git -C "$tmp" rm -q --cached a.gd.uid
  check "$tmp" 2>/dev/null && { echo "check_uids self-test: an untracked .uid was accepted" >&2; exit 1; }
  echo "check_uids self-test: ok"
  exit 0
fi

root="$(cd "$(dirname "$0")/.." && pwd)"
check "$root" || exit 1
echo "check_uids: ok"
