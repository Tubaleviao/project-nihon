#!/usr/bin/env bash
# Phase 173 — the follow-up debt cap. Counts open `autopilot-followup` issues via `gh` and exits 1
# when there are more than the cap (default 10, override with FOLLOWUP_CAP). Autopilot runs it
# before it opens a new feature phase.
#
#   tools/check_followups.sh            # repo of the current checkout
#   REPO=Tubaleviao/project-nihon tools/check_followups.sh
set -uo pipefail

CAP="${FOLLOWUP_CAP:-10}"
REPO_ARGS=()
if [ -n "${REPO:-}" ]; then
  REPO_ARGS=(-R "$REPO")
fi

if ! count="$(gh issue list "${REPO_ARGS[@]}" --label autopilot-followup --state open --limit 500 --json number --jq 'length')"; then
  echo "check_followups: could not list issues (is gh authenticated?)" >&2
  exit 2
fi

echo "check_followups: $count open autopilot-followup issues (cap $CAP)"
if [ "$count" -gt "$CAP" ]; then
  echo "check_followups: over the cap — burn the backlog down before a new feature phase" >&2
  exit 1
fi
