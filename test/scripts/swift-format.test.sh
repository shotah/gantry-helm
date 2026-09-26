#!/usr/bin/env bash
# make lint stays on Apple swift-format defaults. No house-style overrides.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cfg="$root/.swift-format"
script="$root/scripts/swift-format.sh"

if [[ ! -x "$script" ]]; then
  echo "FAIL: scripts/swift-format.sh should be executable" >&2
  exit 1
fi
grep -q 'swift format lint --strict' "$script" || {
  echo "FAIL: lint must be swift format lint --strict" >&2
  exit 1
}
grep -q 'swift format format --in-place' "$script" || {
  echo "FAIL: format must rewrite in place" >&2
  exit 1
}
grep -q -- '--configuration' "$script" || {
  echo "FAIL: swift-format must load .swift-format" >&2
  exit 1
}
grep -q 'swift-format.sh lint' "$root/Makefile" || {
  echo "FAIL: make lint should run scripts/swift-format.sh lint" >&2
  exit 1
}
grep -q 'swift-format.sh format' "$root/Makefile" || {
  echo "FAIL: make format should run scripts/swift-format.sh format" >&2
  exit 1
}
grep -q 'check: lint' "$root/Makefile" || {
  echo "FAIL: make check should depend on lint" >&2
  exit 1
}

grep -q '"lineLength" : 100' "$cfg" || {
  echo "FAIL: .swift-format lineLength should stay 100" >&2
  exit 1
}
grep -q '"indentConditionalCompilationBlocks" : true' "$cfg" || {
  echo "FAIL: .swift-format should indent #if bodies" >&2
  exit 1
}
grep -q '"spaces" : 2' "$cfg" || {
  echo "FAIL: .swift-format should indent with 2 spaces" >&2
  exit 1
}

echo "ok swift-format"
