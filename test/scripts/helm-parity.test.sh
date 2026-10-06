#!/usr/bin/env bash
# Aims, tasks, reactions, seen-on-ack, pocket voice, and stored nonces stay wired.
# Device act does not.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
model="$root/app/Helm/HelmModel.swift"
screen="$root/app/Helm/HelmScreen.swift"
settings="$root/app/Helm/HelmSettings.swift"

grep -q 'kind == "aims"' "$root/Sources/Mailbox/Mouth.swift" || {
  echo "FAIL: Mouth must ingest aims before the bubble path" >&2
  exit 1
}
grep -q 'kind != "aims"' "$root/Sources/Mailbox/Thread.swift" || {
  echo "FAIL: aims must not move the cursor" >&2
  exit 1
}
grep -q 'applyReaction' "$root/Sources/Mailbox/Mouth.swift" || {
  echo "FAIL: react must paint a chip, not a turn" >&2
  exit 1
}
grep -q 'ackSeen' "$model" || {
  echo "FAIL: HelmModel must send seen acks" >&2
  exit 1
}
grep -q 'dismissKitOnFrame' "$model" || {
  echo "FAIL: a sibling read must dismiss the local card" >&2
  exit 1
}
grep -q 'goalsLabel' "$screen" || {
  echo "FAIL: header must use goalsLabel" >&2
  exit 1
}
grep -q 'canReact' "$screen" || {
  echo "FAIL: Kit bubbles need the reaction menu" >&2
  exit 1
}
grep -q 'voiceBarShown' "$model" || {
  echo "FAIL: hold bar follows voiceBarShown" >&2
  exit 1
}
grep -q 'langIds' "$settings" || {
  echo "FAIL: Settings language must use langIds" >&2
  exit 1
}
grep -q 'kind == "todo"' "$root/Sources/Mailbox/Mouth.swift" || {
  echo "FAIL: Mouth must ingest todo before the bubble path" >&2
  exit 1
}
grep -q 'kind != "todo"' "$root/Sources/Mailbox/Thread.swift" || {
  echo "FAIL: todo must not move the cursor" >&2
  exit 1
}
grep -q 'tasksLabel' "$screen" || {
  echo "FAIL: header must use tasksLabel" >&2
  exit 1
}
grep -q 'todoSeen' "$root/app/Helm/HelmPrefs.swift" || {
  echo "FAIL: todoSeen must persist on the helm defaults" >&2
  exit 1
}
grep -q 'tickTask' "$model" || {
  echo "FAIL: a checkbox must send without closing the sheet" >&2
  exit 1
}
grep -q 'GoogleNeedNonce' "$root/app/Helm/HelmGoogle.swift" || {
  echo "FAIL: a failed nonce GET must stop sign-in" >&2
  exit 1
}
if grep -q 'mintNonce' "$root/Sources/Mailbox/Auth.swift" "$root/app/Helm/HelmGoogle.swift"; then
  echo "FAIL: do not mint a nonce when GET /api/auth/nonce fails" >&2
  exit 1
fi
grep -q 'NSSpeechRecognitionUsageDescription' "$root/app/Info.plist" || {
  echo "FAIL: Info.plist must explain speech recognition" >&2
  exit 1
}
if grep -q 'AlarmKit' "$root/app/Helm/"*.swift; then
  echo "FAIL: device act is not routed yet" >&2
  exit 1
fi

echo "ok helm-parity"
