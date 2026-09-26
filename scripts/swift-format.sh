#!/usr/bin/env bash
# Apple swift-format, using the Swift 6.3.3 defaults in .swift-format.
# format — rewrite sources in place
# lint — strict diagnostics, then fail if format would still change a file
set -euo pipefail

mode="${1:-lint}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

cfg="$root/.swift-format"
paths=(Sources Tests app Package.swift)

case "$mode" in
  format)
    swift format format --in-place --recursive --parallel --configuration "$cfg" "${paths[@]}"
    ;;
  lint)
    swift format lint --strict --recursive --parallel --configuration "$cfg" "${paths[@]}"
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    cp -a Sources Tests app Package.swift "$tmp/"
    swift format format --in-place --recursive --parallel --configuration "$cfg" \
      "$tmp/Sources" "$tmp/Tests" "$tmp/app" "$tmp/Package.swift"
    diff -ru Sources "$tmp/Sources"
    diff -ru Tests "$tmp/Tests"
    diff -ru app "$tmp/app"
    diff -q Package.swift "$tmp/Package.swift"
    ;;
  *)
    echo "usage: swift-format.sh format|lint" >&2
    exit 2
    ;;
esac
