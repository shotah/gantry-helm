#!/usr/bin/env bash
# Dry-run must not read parent-repo tags when this folder is not its own git root.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
file_ver="$(tr -d '[:space:]' < "$root/VERSION")"
want="$("$root/scripts/semver.sh" next "$file_ver" patch)"

grep -q 'SKIP_FETCH' "$root/scripts/release.sh" || {
  echo "FAIL: release.sh should honour SKIP_FETCH" >&2
  exit 1
}

out="$(DRY_RUN=1 SKIP_FETCH=1 "$root/scripts/release.sh")"
echo "$out"

echo "$out" | grep -q "using VERSION only" || {
  echo "$out" | grep -q "Next tag:" || {
    echo "FAIL: release dry-run printed no next tag" >&2
    exit 1
  }
  echo "ok release (own git)"
  exit 0
}

echo "$out" | grep -q "Next tag:    ${want}" || {
  echo "FAIL: expected next ${want} from VERSION ${file_ver} (not parent tags)" >&2
  exit 1
}

echo "ok release (nested, VERSION only)"
