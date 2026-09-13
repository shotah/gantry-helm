#!/usr/bin/env bash
# Sideload CarPlay is the communication card, not a tile. Keep the contract.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
notify="$root/app/Helm/HelmNotify.swift"
model="$root/app/Helm/HelmModel.swift"
app="$root/app/Helm/HelmApp.swift"
car="$root/app/Helm/HelmCar.swift"

grep -q 'allowInCarPlay' "$notify" || {
  echo "FAIL: HelmNotify category must allow CarPlay" >&2
  exit 1
}
grep -q 'allowAnnouncement' "$notify" || {
  echo "FAIL: HelmNotify category must allow announcement" >&2
  exit 1
}
grep -q 'INSendMessageIntent' "$notify" || {
  echo "FAIL: HelmNotify must donate INSendMessageIntent" >&2
  exit 1
}
grep -q 'carPlay' "$notify" || {
  echo "FAIL: HelmNotify must request .carPlay authorization" >&2
  exit 1
}
grep -q 'kitReplyAction' "$notify" || {
  echo "FAIL: reply action id must come from Mailbox kitReplyAction" >&2
  exit 1
}
grep -q 'carPlayReplyText' "$notify" || {
  echo "FAIL: delegate must use carPlayReplyText" >&2
  exit 1
}
grep -q 'UNUserNotificationCenter.current().delegate' "$model" || {
  echo "FAIL: HelmModel must assign the notify delegate" >&2
  exit 1
}
grep -q 'kitNoticeBody' "$model" || {
  echo "FAIL: ingest must use kitNoticeBody (the tested gate)" >&2
  exit 1
}
grep -q 'HelmCar.start' "$model" || {
  echo "FAIL: HelmModel must watch HelmCar for attachment" >&2
  exit 1
}
grep -q 'onOpenURL' "$app" || {
  echo "FAIL: HelmApp must handle the Google URL callback" >&2
  exit 1
}
grep -q 'GIDSignIn' "$root/app/Helm/HelmGoogle.swift" || {
  echo "FAIL: HelmGoogle must call GIDSignIn.handle" >&2
  exit 1
}
grep -q 'requestWhenInUseAuthorization' "$root/app/Helm/HelmLocation.swift" || {
  echo "FAIL: GPS must request When In Use" >&2
  exit 1
}
grep -q 'carPlayRouteAttached' "$car" || {
  echo "FAIL: HelmCar must read the car-audio route" >&2
  exit 1
}
grep -q 'surface: carplay' "$root/docs/carplay_setup.md" || {
  echo "FAIL: carplay_setup should say spoken reply is surface: carplay" >&2
  exit 1
}

echo "ok helm-carplay"
