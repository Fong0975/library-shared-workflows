#!/usr/bin/env bash
# Builds the Markdown unit-test report for a Go module.
#
# Env:
#   TITLE             Project name shown in the report heading.
#   RESULTS_FILE      Verbose `go test -v` output (counts `--- PASS/FAIL/SKIP` lines).
#   COVERAGE_FILE     Cover profile written by `go test -coverprofile`.
#   COVERAGE_EXCLUDE  Extended regex; profile lines matching it are dropped before measuring.
#   THRESHOLD         Statement-coverage threshold in percent; 0 disables the per-function list.
#   REPORT_FILE       Path the Markdown report is written to.
#
# Outputs ($GITHUB_OUTPUT):
#   coverage          Total statement coverage in percent; omitted when coverage data is missing.
set -euo pipefail

# shellcheck source=SCRIPTDIR/report-common.sh
source "$(dirname "$0")/report-common.sh"

count_results() {
  grep -cE "^\s*--- $1" "$RESULTS_FILE" || true
}

{
  echo "### 🧪 Unit Tests — ${TITLE}"
  echo ""
  if [ -f "$RESULTS_FILE" ]; then
    passed=$(count_results PASS)
    failed=$(count_results FAIL)
    skipped=$(count_results SKIP)
    print_test_counts "$((passed + failed + skipped))" "$passed" "$failed" "$skipped"
  else
    echo "_Test results are not available for this run._"
  fi

  echo ""
  if [ -f "$COVERAGE_FILE" ]; then
    profile="$COVERAGE_FILE"
    if [ -n "${COVERAGE_EXCLUDE:-}" ]; then
      profile="${RUNNER_TEMP}/coverage.filtered.out"
      grep -v -E "$COVERAGE_EXCLUDE" "$COVERAGE_FILE" > "$profile" || true
    fi
    func_report=$(go tool cover -func="$profile")
    total=$(awk '/^total:/ { gsub("%", "", $NF); print $NF }' <<<"$func_report")
    echo "coverage=${total}" >> "$GITHUB_OUTPUT"
    echo "**Coverage:** statements ${total}%"
    if threshold_enabled "$THRESHOLD"; then
      echo ""
      echo "_Threshold: statements ${THRESHOLD}%_"
      weak=$(awk -v t="$THRESHOLD" '
        !/^total:/ { pct = $NF; gsub("%", "", pct); if (pct + 0 < t) print }
      ' <<<"$func_report" | head -30)
      print_weak_section "function" "$THRESHOLD" "$weak"
    fi
  else
    echo "_Coverage data is not available for this run._"
  fi
} > "$REPORT_FILE"
