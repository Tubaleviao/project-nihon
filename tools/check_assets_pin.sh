#!/usr/bin/env bash
# A release ships the production art at its `assets-prod` pin (the `assets.pck` players get is built from
# that commit), so a `v*` tag must pin the newest art: the pointer must equal the private assets repo's
# `main` HEAD. release.yml runs this on a pushed tag, before any build.
#
#   ASSETS_READ_TOKEN=<read-only token> tools/check_assets_pin.sh [REF]   # default REF=HEAD
#   tools/check_assets_pin.sh --self-test
#
# Without ASSETS_READ_TOKEN it reads the assets repo with the caller's own git credentials.
set -uo pipefail

ASSETS_URL="https://github.com/Tubaleviao/project-nihon-assets.git"

pointer() { git -C "$1" ls-tree "$2" assets-prod 2>/dev/null | awk '$2=="commit"{print $3}'; }

# check <pin> <assets main HEAD>
check() {
  local pin="$1" head="$2"
  if [ -z "$pin" ]; then
    echo "check_assets_pin: no assets-prod pointer" >&2; return 1
  fi
  if [ -z "$head" ]; then
    echo "check_assets_pin: could not read the assets repo's main" >&2; return 1
  fi
  if [ "$pin" != "$head" ]; then
    echo "check_assets_pin: assets-prod is pinned at ${pin:0:7} but the assets repo's main is ${head:0:7};" \
      "bump the pointer in an 'assets-prod:' PR before tagging" >&2
    return 1
  fi
  return 0
}

remote_main() {
  if [ -n "${ASSETS_READ_TOKEN:-}" ]; then
    local auth
    auth="$(printf 'x-access-token:%s' "$ASSETS_READ_TOKEN" | base64 -w0)"
    GIT_TERMINAL_PROMPT=0 git -c credential.helper= -c "http.extraHeader=Authorization: Basic $auth" \
      ls-remote "$ASSETS_URL" refs/heads/main
  else
    GIT_TERMINAL_PROMPT=0 git ls-remote "$ASSETS_URL" refs/heads/main
  fi 2>/dev/null | awk '{print $1}'
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
  git -C "$tmp" commit -qm none
  git -C "$tmp" update-index --add --cacheinfo "160000,$a,assets-prod"
  git -C "$tmp" commit -qm pinned
  [ "$(pointer "$tmp" HEAD)" = "$a" ] || { echo "check_assets_pin self-test: pointer not read" >&2; exit 1; }
  check "$(pointer "$tmp" HEAD)" "$a" 2>/dev/null || { echo "check_assets_pin self-test: a pin at main was rejected" >&2; exit 1; }
  check "$(pointer "$tmp" HEAD)" "$b" 2>/dev/null && { echo "check_assets_pin self-test: a stale pin was accepted" >&2; exit 1; }
  check "$(pointer "$tmp" HEAD~1)" "$a" 2>/dev/null && { echo "check_assets_pin self-test: a missing pin was accepted" >&2; exit 1; }
  check "$a" "" 2>/dev/null && { echo "check_assets_pin self-test: an unreadable assets main was accepted" >&2; exit 1; }
  echo "check_assets_pin self-test: ok"
  exit 0
fi

root="$(cd "$(dirname "$0")/.." && pwd)"
check "$(pointer "$root" "${1:-HEAD}")" "$(remote_main)" || exit 1
echo "check_assets_pin: ok"
