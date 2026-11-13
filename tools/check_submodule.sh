#!/usr/bin/env bash
# Phase 254 — the `assets-prod` submodule pointer changes on purpose. Compares the pointer recorded
# at BASE with the one at HEAD. An unchanged pointer passes. A changed one fails unless the PR title
# carries `assets-prod:`; and when the submodule is checked out (it is not in CI), the new pointer
# must also descend from the old one, so a rewound pointer is rejected even with the marker.
#
#   PR_TITLE="feat(x): y" tools/check_submodule.sh [BASE [HEAD]]   # default BASE=HEAD^ HEAD=HEAD
#   tools/check_submodule.sh --self-test
set -uo pipefail

pointer() { git -C "$1" ls-tree "$2" assets-prod 2>/dev/null | awk '$2=="commit"{print $3}'; }

check() {
  local root="$1" base="$2" head="$3" title="$4" old new
  old="$(pointer "$root" "$base")"
  new="$(pointer "$root" "$head")"
  [ "$old" = "$new" ] && return 0
  case "$title" in
    *assets-prod:*) ;;
    *) echo "check_submodule: assets-prod moved ${old:-none} -> ${new:-none}; the PR title needs an 'assets-prod:' marker" >&2; return 1 ;;
  esac
  if [ -n "$old" ] && [ -n "$new" ] && [ -e "$root/assets-prod/.git" ]; then
    if ! git -C "$root/assets-prod" merge-base --is-ancestor "$old" "$new" 2>/dev/null; then
      echo "check_submodule: assets-prod $new does not descend from $old (rewound pointer)" >&2
      return 1
    fi
  fi
  return 0
}

if [ "${1:-}" = "--self-test" ]; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  git -C "$tmp" init -q
  git -C "$tmp" config user.email t@t; git -C "$tmp" config user.name t
  a=1111111111111111111111111111111111111111
  b=2222222222222222222222222222222222222222
  echo x > "$tmp/f"
  git -C "$tmp" add f
  git -C "$tmp" update-index --add --cacheinfo "160000,$a,assets-prod"
  git -C "$tmp" commit -qm one
  echo y > "$tmp/f"; git -C "$tmp" add f; git -C "$tmp" commit -qm same
  git -C "$tmp" update-index --add --cacheinfo "160000,$b,assets-prod"
  git -C "$tmp" commit -qm moved
  check "$tmp" HEAD~2 HEAD~1 "feat: x" 2>/dev/null || { echo "check_submodule self-test: an unchanged pointer was rejected" >&2; exit 1; }
  check "$tmp" HEAD~1 HEAD "feat: x" 2>/dev/null && { echo "check_submodule self-test: a moved pointer without the marker was accepted" >&2; exit 1; }
  check "$tmp" HEAD~1 HEAD "chore(assets-prod): bump" 2>/dev/null && { echo "check_submodule self-test: marker must be 'assets-prod:'" >&2; exit 1; }
  check "$tmp" HEAD~1 HEAD "assets-prod: bump" 2>/dev/null || { echo "check_submodule self-test: a marked move was rejected" >&2; exit 1; }
  echo "check_submodule self-test: ok"
  exit 0
fi

root="$(cd "$(dirname "$0")/.." && pwd)"
check "$root" "${1:-HEAD^}" "${2:-HEAD}" "${PR_TITLE:-}" || exit 1
echo "check_submodule: ok"
