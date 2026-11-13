#!/usr/bin/env bash
# Phase 253: the failure rate per CI job over the last 40 completed runs of `main`.
# Prints one line per job (failed / total) and exits 1 when any job fails in more than
# GATE_MAX_PCT percent (default 10) of the runs it appeared in. Needs `gh` and `jq`, and
# GH_TOKEN (or a logged-in gh) with read access to Actions.
# GATE_RUNS=40 GATE_MAX_PCT=10 GATE_REPO=owner/name tools/check_gate_health.sh
set -u
RUNS="${GATE_RUNS:-40}"
MAX_PCT="${GATE_MAX_PCT:-10}"
REPO="${GATE_REPO:-${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}}"
WORKFLOW="${GATE_WORKFLOW:-ci.yml}"

case "$RUNS" in ''|*[!0-9]*|0) echo "gate health: GATE_RUNS must be a positive number, got '$RUNS'"; exit 2;; esac

# The API caps per_page at 100, so larger windows are read page by page.
ids=""
page=1
while :; do
  per_page=$(( RUNS < 100 ? RUNS : 100 ))
  batch=$(gh api "repos/$REPO/actions/workflows/$WORKFLOW/runs?branch=main&event=push&status=completed&per_page=$per_page&page=$page" \
    --jq '.workflow_runs[].id') || { echo "gate health: could not list runs (page $page)"; exit 2; }
  [ -n "$batch" ] || break
  ids+="$batch"$'\n'
  [ "$(printf '%s' "$ids" | grep -c .)" -ge "$RUNS" ] && break
  page=$(( page + 1 ))
done
ids=$(printf '%s' "$ids" | grep . | head -n "$RUNS")
[ -n "$ids" ] || { echo "gate health: no completed runs found"; exit 2; }

rows=""
for id in $ids; do
  # A failed call (rate limit, network) would silently drop this run from the counts and could hide a
  # flaky gate, so it stops the check instead.
  jobs=$(gh api "repos/$REPO/actions/runs/$id/jobs?per_page=100" \
    --jq '.jobs[] | select(.conclusion=="success" or .conclusion=="failure") | "\(.name)\t\(.conclusion)"') \
    || { echo "gate health: could not list the jobs of run $id"; exit 2; }
  rows+="$jobs"$'\n'
done

printf '%s' "$rows" | awk -F'\t' -v max="$MAX_PCT" '
  NF == 2 { total[$1]++; if ($2 == "failure") failed[$1]++ }
  END {
    bad = 0
    for (j in total) {
      pct = 100 * failed[j] / total[j]
      flag = pct > max ? "  <-- over " max "%" : ""
      printf "%-50s %2d/%2d failed (%.0f%%)%s\n", j, failed[j], total[j], pct, flag
      if (pct > max) bad = 1
    }
    exit bad
  }' | sort
exit "${PIPESTATUS[1]}"
