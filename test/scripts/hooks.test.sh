#!/usr/bin/env bash
# install-hooks writes this checkout's hooks, and must not write a parent tree.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"

if [[ ! -x "$root/scripts/pre-commit" ]]; then
  echo "FAIL: scripts/pre-commit should be executable" >&2
  exit 1
fi
if [[ ! -x "$root/scripts/pre-push" ]]; then
  echo "FAIL: scripts/pre-push should be executable" >&2
  exit 1
fi
grep -q "make test-scripts" "$root/scripts/pre-commit" || {
  echo "FAIL: pre-commit should run make test-scripts" >&2
  exit 1
}
grep -q "make test-app" "$root/scripts/pre-commit" || {
  echo "FAIL: pre-commit should run make test-app" >&2
  exit 1
}
if grep -q "make coverage" "$root/scripts/pre-commit"; then
  echo "FAIL: pre-commit should not run make coverage (that is pre-push)" >&2
  exit 1
fi
grep -q "make check-app" "$root/scripts/pre-push" || {
  echo "FAIL: pre-push should run make check-app" >&2
  exit 1
}
grep -q "pre-push" "$root/Makefile" || {
  echo "FAIL: Makefile install-hooks should install pre-push" >&2
  exit 1
}

top="$(git -C "$root" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ "$top" == "$root" ]]; then
  echo "ok hooks (own git)"
  exit 0
fi

if make -C "$root" install-hooks >/tmp/gantry-helm-hooks.out 2>/tmp/gantry-helm-hooks.err; then
  echo "FAIL: install-hooks should refuse a parent git root" >&2
  cat /tmp/gantry-helm-hooks.err >&2
  exit 1
fi
if ! grep -q "own git checkout" /tmp/gantry-helm-hooks.err /tmp/gantry-helm-hooks.out; then
  echo "FAIL: expected own-checkout error" >&2
  cat /tmp/gantry-helm-hooks.out /tmp/gantry-helm-hooks.err >&2
  exit 1
fi

echo "ok hooks"
