#!/usr/bin/env bash
# Mirrors gantry-cab/test/scripts/semver.test.sh
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
semver="$root/scripts/semver.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_eq() {
  local got="$1" want="$2" msg="${3:-}"
  if [[ "$got" != "$want" ]]; then
    fail "got ${got@Q} want ${want@Q} ${msg}"
  fi
}

assert_fails() {
  local msg="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    fail "expected error: ${msg}"
  fi
}

assert_eq "$("$semver" next "" patch)" "v0.0.1" "empty + patch"
assert_eq "$("$semver" next "v0.1.0" patch)" "v0.1.1" "patch"
assert_eq "$("$semver" next "v0.1.0" minor)" "v0.2.0" "minor"
assert_eq "$("$semver" next "v0.1.0" major)" "v1.0.0" "major"
assert_eq "$("$semver" next "v1.2.3" patch)" "v1.2.4" "1.2.3 patch"
assert_eq "$("$semver" next "v0.1.0" patch "v9.8.7")" "v9.8.7" "explicit v"
assert_eq "$("$semver" next "v0.1.0" patch "1.0.0")" "v1.0.0" "explicit bare"

assert_eq "$("$semver" name "v0.1.1")" "0.1.1" "strip v"
assert_eq "$("$semver" code "v0.1.0")" "100" "0.1.0 → 100"
assert_eq "$("$semver" code "v0.1.1")" "101" "0.1.1 → 101"
assert_eq "$("$semver" code "v1.0.0")" "10000" "1.0.0 → 10000"

assert_fails "bad bump" "$semver" next "v0.1.0" tiny
assert_fails "bad explicit" "$semver" next "v0.1.0" patch nope
assert_fails "bad current" "$semver" next "latest" patch

file_ver="$(tr -d '[:space:]' < "$root/VERSION")"
if [[ ! "$file_ver" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  fail "VERSION ${file_ver@Q} is not vMAJOR.MINOR.PATCH"
fi
next_from_file="$("$semver" next "$file_ver" patch)"
if [[ ! "$next_from_file" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  fail "bump from VERSION produced ${next_from_file@Q}"
fi
if [[ "$next_from_file" == "$file_ver" ]]; then
  fail "patch bump should change VERSION"
fi

echo "ok semver"
