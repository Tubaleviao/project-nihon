#!/usr/bin/env bash
# Points this clone (and its worktrees) at the repository's hooks in .githooks/.
set -euo pipefail
cd "$(dirname "$0")/.."
git config core.hooksPath .githooks
echo "hooks: core.hooksPath = .githooks ($(ls .githooks | tr '\n' ' '))"
