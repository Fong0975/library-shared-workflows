#!/usr/bin/env bash
# Builds the Markdown unit-test report for a Node project (Vitest or Jest).
#
# Env:
#   TITLE          Project name shown in the report heading.
#   RESULTS_FILE   Jest-compatible JSON results (numTotalTests, numPassedTests, ...).
#   COVERAGE_FILE  Istanbul json-summary file (coverage-summary.json).
#   THRESHOLD      Line-coverage threshold in percent; 0 disables the per-file list.
#   REPORT_FILE    Path the Markdown report is written to.
#
# Outputs ($GITHUB_OUTPUT):
#   coverage       Total line coverage in percent; omitted when coverage data is missing.
set -euo pipefail

# shellcheck source=SCRIPTDIR/report-common.sh
source "$(dirname "$0")/report-common.sh"

{
  echo "### 🧪 Unit Tests — ${TITLE}"
  echo ""
  if [ -f "$RESULTS_FILE" ]; then
    read -r total passed failed skipped < <(jq -r '
      [.numTotalTests, .numPassedTests, .numFailedTests,
       ((.numPendingTests // 0) + (.numTodoTests // 0))] | @tsv
    ' "$RESULTS_FILE")
    print_test_counts "$total" "$passed" "$failed" "$skipped"
  else
    echo "_Test results are not available for this run._"
  fi

  echo ""
  if [ -f "$COVERAGE_FILE" ]; then
    echo "coverage=$(jq -r '.total.lines.pct' "$COVERAGE_FILE")" >> "$GITHUB_OUTPUT"
    jq -r '.total | "**Coverage:** lines \(.lines.pct)% · statements \(.statements.pct)% · branches \(.branches.pct)% · functions \(.functions.pct)%"' "$COVERAGE_FILE"
    if threshold_enabled "$THRESHOLD"; then
      echo ""
      echo "_Threshold: lines ${THRESHOLD}%_"
      weak=$(jq -r --arg root "$GITHUB_WORKSPACE/" --argjson threshold "$THRESHOLD" '
        to_entries[]
        | select(.key != "total" and .value.lines.pct < $threshold)
        | "\(.key | ltrimstr($root)): \(.value.lines.pct)%"
      ' "$COVERAGE_FILE" | head -30)
      print_weak_section "file" "$THRESHOLD" "$weak"
    fi
  else
    echo "_Coverage data is not available for this run._"
  fi
} > "$REPORT_FILE"
