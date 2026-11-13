#!/usr/bin/env bash
# Phase 255 — the version in project.godot (`application/config/version`, the `config/version` key of
# its [application] section) must have a `## v<version>` entry in CHANGELOG.md, so a release is never
# tagged without its notes. Fails on a missing version, one that is not major.minor.patch, or no entry.
#
#   tools/check_changelog.sh                          # the repository this script lives in
#   tools/check_changelog.sh <project.godot> <CHANGELOG.md>
#   tools/check_changelog.sh --self-test              # proves the check rejects a version with no entry
set -uo pipefail

# The `config/version` value of project.godot's [application] section, or "".
version_of() {
  awk '/^\[/{ app = ($0 == "[application]") } app && /^config\/version=/{ sub(/^config\/version="/, ""); sub(/"$/, ""); print; exit }' "$1"
}

check() {
  local godot="$1" changelog="$2" v
  v="$(version_of "$godot")"
  if [ -z "$v" ]; then
    echo "check_changelog: $godot has no application/config/version" >&2
    return 1
  fi
  if ! [[ "$v" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    echo "check_changelog: version '$v' is not major.minor.patch" >&2
    return 1
  fi
  if [ ! -f "$changelog" ] || ! grep -qE "^## v${v//./\\.}([[:space:]]|$)" "$changelog"; then
    echo "check_changelog: $changelog has no '## v$v' entry for the version in $godot" >&2
    return 1
  fi
  echo "check_changelog: v$v has an entry"
}

if [ "${1:-}" = "--self-test" ]; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  printf '[application]\n\nconfig/name="x"\nconfig/version="1.2.3"\n\n[autoload]\n' > "$tmp/project.godot"
  printf '# Changelog\n\n## v1.2.3\n\nNotes.\n' > "$tmp/CHANGELOG.md"
  check "$tmp/project.godot" "$tmp/CHANGELOG.md" >/dev/null 2>&1 || { echo "check_changelog self-test: a version with an entry was rejected" >&2; exit 1; }
  printf '# Changelog\n\n## v1.2.30\n\n## v1.2.2\n' > "$tmp/CHANGELOG.md"
  check "$tmp/project.godot" "$tmp/CHANGELOG.md" >/dev/null 2>&1 && { echo "check_changelog self-test: a version with no entry was accepted" >&2; exit 1; }
  rm "$tmp/CHANGELOG.md"
  check "$tmp/project.godot" "$tmp/CHANGELOG.md" >/dev/null 2>&1 && { echo "check_changelog self-test: a missing changelog was accepted" >&2; exit 1; }
  printf '# Changelog\n\n## v1.2\n' > "$tmp/CHANGELOG.md"
  printf '[application]\nconfig/version="1.2"\n' > "$tmp/project.godot"
  check "$tmp/project.godot" "$tmp/CHANGELOG.md" >/dev/null 2>&1 && { echo "check_changelog self-test: a two-part version was accepted" >&2; exit 1; }
  printf '[application]\nconfig/name="x"\n[export]\nconfig/version="1.2"\n' > "$tmp/project.godot"
  check "$tmp/project.godot" "$tmp/CHANGELOG.md" >/dev/null 2>&1 && { echo "check_changelog self-test: a version outside [application] was read" >&2; exit 1; }
  echo "check_changelog self-test: ok"
  exit 0
fi

if [ $# -eq 2 ]; then
  check "$1" "$2"
  exit $?
fi
root="$(cd "$(dirname "$0")/.." && pwd)"
check "$root/project.godot" "$root/CHANGELOG.md"
