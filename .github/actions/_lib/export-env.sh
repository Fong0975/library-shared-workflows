#!/usr/bin/env bash
# Appends every key of a project's `env` object to $GITHUB_ENV so that all later
# steps of the job see it.
#
# Env:
#   PROJECT_JSON  Normalized project JSON produced by _detect-changes.yml.
#
# Each variable is written with a random heredoc delimiter so values may span
# multiple lines without being able to inject extra variables.
set -euo pipefail

delimiter="ENV_EOF_$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"

jq -r --arg d "$delimiter" '
  (.env // {}) | to_entries[] | "\(.key)<<\($d)\n\(.value | tostring)\n\($d)"
' <<<"$PROJECT_JSON" >> "$GITHUB_ENV"
