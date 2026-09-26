#!/usr/bin/env bash
# make shot photographs the Simulator. This host only checks the list.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
shot="$root/scripts/helm-shot.sh"
screens="$root/docs/screens.md"

[[ -x "$shot" ]] || {
  echo "FAIL: scripts/helm-shot.sh should be executable" >&2
  exit 1
}
grep -q 'simctl io' "$shot" || {
  echo "FAIL: helm-shot must use simctl screenshot, not a second painter" >&2
  exit 1
}
if grep -q 'DocsShot' "$shot"; then
  echo "FAIL: helm-shot must not paint a stand-in" >&2
  exit 1
fi

names=()
while IFS= read -r name; do
  [[ -n "$name" ]] && names+=("$name")
done < <(SHOT_DRY=1 "$shot")
[[ ${#names[@]} -ge 1 ]] || {
  echo "FAIL: SHOT_DRY printed nothing" >&2
  exit 1
}
for name in "${names[@]}"; do
  grep -q "\`$name\`" "$screens" || {
    echo "FAIL: docs/screens.md missing $name" >&2
    exit 1
  }
  grep -q "file: \"$name\"" "$root/Sources/Mailbox/Shots.swift" || {
    echo "FAIL: Shots.swift missing $name" >&2
    exit 1
  }
done
if printf '%s\n' "${names[@]}" | grep -q '^car-'; then
  echo "FAIL: car rows have no conversation screen to shoot" >&2
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  if "$shot" >/tmp/helm-shot.out 2>/tmp/helm-shot.err; then
    echo "FAIL: make shot should refuse a host without Xcode" >&2
    exit 1
  fi
  grep -q 'needs Xcode' /tmp/helm-shot.err || {
    echo "FAIL: refusal should say Xcode" >&2
    cat /tmp/helm-shot.err >&2
    exit 1
  }
fi

echo "ok helm-shot"
