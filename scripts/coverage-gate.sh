#!/usr/bin/env bash
# Fail if Mailbox line coverage is below COVERAGE_MIN (default 70).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
REPORT="${1:-.build/coverage.json}"
MIN="${COVERAGE_MIN:-70}"

if [[ ! "$MIN" =~ ^[0-9]+$ ]]; then
  echo "COVERAGE_MIN must be an integer, got ${MIN@Q}" >&2
  exit 1
fi

PCT="$("$root/scripts/coverage-pct.sh" "$REPORT")"
if [[ "$PCT" -lt "$MIN" ]]; then
  echo "coverage ${PCT}% is below the ${MIN}% bar" >&2
  exit 1
fi
echo "coverage ${PCT}% (bar ${MIN}%)"
