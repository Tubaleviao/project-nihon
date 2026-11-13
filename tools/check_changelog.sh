#!/usr/bin/env bash
# Phase 255 — the version in project.godot (`application/config/version`, the `config/version` key of
# its [application] section) must have a `## v<version>` entry in CHANGELOG.md, so a release is never
# tagged without its notes. Fails on a missing version, one that is not major.minor.patch, or no entry.
#
#   tools/check_changelog.sh                          # the repository this script lives in
#   tools/check_changelog.sh <project.godot> <CHANGELOG.md>
#   tools/check_changelog.sh --self-test              # proves the check rejects a version with no entry
#   tools/check_changelog.sh --print-version          # prints the project version (the release's tag check)
#   tools/check_changelog.sh --notes <tag>            # prints the tag's entry, heading left out (release notes)
#
# A heading is `## v<version>`, optionally followed by whitespace and more text (`## v0.2.0 — 2026-12-01`).
# The check and the notes read headings through the same rule, so an entry the check accepts always has notes.
set -uo pipefail

# The `config/version` value of project.godot's [application] section, or "".
version_of() {
  awk '/^\[/{ app = ($0 == "[application]") } app && /^config\/version=/{ sub(/^config\/version="/, ""); sub(/"$/, ""); print; exit }' "$1"
}

# The ERE a `## v<version>` heading of `$1` matches (dots escaped).
heading_re() {
  printf '^## v%s([[:space:]]|$)' "${1//./\\.}"
}

# The lines of `$2`'s entry for version `$1`, heading left out, up to the next `## ` heading.
notes_of() {
  # Through ENVIRON, not -v: -v would turn the regex's `\.` into `.`.
  RE="$(heading_re "$1")" awk 'on && /^## / { exit } on { print } $0 ~ ENVIRON["RE"] { on = 1 }' "$2"
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
  if [ ! -f "$changelog" ] || ! grep -qE "$(heading_re "$v")" "$changelog"; then
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
  printf '# Changelog\n\n## v1.2.3 — 2026-12-01\n\nDated notes.\n\n## v1.2.2\n\nOld.\n' > "$tmp/CHANGELOG.md"
  printf '[application]\nconfig/version="1.2.3"\n' > "$tmp/project.godot"
  check "$tmp/project.godot" "$tmp/CHANGELOG.md" >/dev/null 2>&1 || { echo "check_changelog self-test: a dated heading was rejected" >&2; exit 1; }
  notes="$(notes_of 1.2.3 "$tmp/CHANGELOG.md")"
  [[ "$notes" == *"Dated notes."* && "$notes" != *"Old."* && "$notes" != *"## "* ]] || { echo "check_changelog self-test: the notes of a dated heading were not its entry: $notes" >&2; exit 1; }
  [ "$(version_of "$tmp/project.godot")" = "1.2.3" ] || { echo "check_changelog self-test: --print-version misread the version" >&2; exit 1; }
  echo "check_changelog self-test: ok"
  exit 0
fi

root="$(cd "$(dirname "$0")/.." && pwd)"

if [ "${1:-}" = "--print-version" ]; then
  v="$(version_of "$root/project.godot")"
  [ -n "$v" ] || { echo "check_changelog: $root/project.godot has no application/config/version" >&2; exit 1; }
  echo "$v"
  exit 0
fi

if [ "${1:-}" = "--notes" ]; then
  tag="${2:-}"
  [ -n "$tag" ] || { echo "usage: check_changelog.sh --notes <tag>" >&2; exit 2; }
  notes="$(notes_of "${tag#v}" "$root/CHANGELOG.md")"
  [ -n "$(printf '%s' "$notes" | tr -d '[:space:]')" ] || { echo "check_changelog: CHANGELOG.md has no notes for $tag" >&2; exit 1; }
  printf '%s\n' "$notes"
  exit 0
fi

if [ $# -eq 2 ]; then
  check "$1" "$2"
  exit $?
fi
check "$root/project.godot" "$root/CHANGELOG.md"
