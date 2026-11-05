#!/usr/bin/env bash
# Helpers shared by the language-specific unit-test report builders.
# Source this file; it defines functions only.

# Returns success when the given coverage threshold is a positive number.
#
# Args:
#   $1  Threshold in percent (may be empty).
threshold_enabled() {
  awk -v t="${1:-0}" 'BEGIN { exit !(t + 0 > 0) }'
}

# Prints the Markdown table with the test counts.
#
# Args:
#   $1 total, $2 passed, $3 failed, $4 skipped
print_test_counts() {
  echo "| Total | Passed | Failed | Skipped |"
  echo "| --- | --- | --- | --- |"
  echo "| $1 | $2 | $3 | $4 |"
}

# Prints a collapsible list of entries below the coverage threshold, or a
# success line when nothing is below it.
#
# Args:
#   $1  Unit being measured, e.g. "file" or "function".
#   $2  Threshold in percent.
#   $3  Newline-separated entries below the threshold (may be empty).
print_weak_section() {
  local unit="$1" limit="$2" weak="$3"
  echo ""
  if [ -n "$weak" ]; then
    echo "<details><summary>⚠️ ${unit^}s under ${limit}% coverage</summary>"
    echo ""
    echo '```'
    echo "$weak"
    echo '```'
    echo ""
    echo "</details>"
  else
    echo "✅ Every ${unit} is at or above ${limit}% coverage"
  fi
}
