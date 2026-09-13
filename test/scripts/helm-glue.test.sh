#!/usr/bin/env bash
# Deck-side glue: scenePhase, typing caption, battery/net send, DEBUG samples.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
screen="$root/app/Helm/HelmScreen.swift"
model="$root/app/Helm/HelmModel.swift"
settings="$root/app/Helm/HelmSettings.swift"

grep -q 'scenePhase' "$screen" || {
  echo "FAIL: HelmRoot must bind scenePhase so Settings stays resumed" >&2
  exit 1
}
if grep -q 'resumed = false' "$screen"; then
  echo "FAIL: HelmScreen must not flip resumed on disappear (Settings is still in-app)" >&2
  exit 1
fi
grep -q 'threadStatusLine' "$screen" || {
  echo "FAIL: header must use threadStatusLine (Live · typing…)" >&2
  exit 1
}
grep -q 'peekBattery' "$model" || {
  echo "FAIL: send must peek battery onto PhoneContext" >&2
  exit 1
}
grep -q 'peekNet' "$model" || {
  echo "FAIL: send must peek net onto PhoneContext" >&2
  exit 1
}
grep -q 'batteryHintFromLevel' "$model" || {
  echo "FAIL: UIDevice level must go through batteryHintFromLevel" >&2
  exit 1
}
grep -q 'currentContext' "$model" || {
  echo "FAIL: sendText / sendPin must share currentContext" >&2
  exit 1
}
grep -q 'sampleIds' "$settings" || {
  echo "FAIL: Settings must paint sampleIds chips" >&2
  exit 1
}
grep -q 'applySample' "$settings" || {
  echo "FAIL: sample chips must call applySample" >&2
  exit 1
}
grep -q '#if DEBUG' "$settings" || {
  echo "FAIL: sample chips must be DEBUG-only" >&2
  exit 1
}

echo "ok helm-glue"
