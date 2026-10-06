#!/usr/bin/env bash
# Photograph the phone rows in docs/screens.md from the iOS Simulator.
# SHOT_DRY=1 prints the file names and does not build. SHOT=phone-thread shoots one.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
shots_swift="$root/Sources/Mailbox/Shots.swift"
out="$root/assets/docs"
bundle_id="com.gantree.helm"
wait_s="${SHOT_WAIT:-2}"

shots=()
while IFS= read -r name; do
  [[ -n "$name" ]] && shots+=("$name")
done < <(grep -o 'file: "[^"]*"' "$shots_swift" | sed 's/file: "//; s/"$//')
if [[ ${#shots[@]} -eq 0 ]]; then
  echo "no docShots in $shots_swift" >&2
  exit 1
fi

if [[ -n "${SHOT:-}" ]]; then
  found=0
  for name in "${shots[@]}"; do
    if [[ "$name" == "$SHOT" ]]; then
      found=1
      break
    fi
  done
  if [[ "$found" -ne 1 ]]; then
    echo "unknown shot: $SHOT" >&2
    printf '  %s\n' "${shots[@]}" >&2
    exit 1
  fi
  shots=("$SHOT")
fi

if [[ "${SHOT_DRY:-}" == 1 ]]; then
  printf '%s\n' "${shots[@]}"
  exit 0
fi

if ! command -v xcodebuild >/dev/null 2>&1 || ! command -v xcrun >/dev/null 2>&1; then
  echo "make shot needs Xcode and an iOS Simulator. This host has neither." >&2
  echo "SHOT_DRY=1 ./scripts/helm-shot.sh prints the list." >&2
  exit 1
fi

line="$(xcrun simctl list devices available | grep -E 'iPhone' | grep -v unavailable | head -1 || true)"
udid="$(printf '%s\n' "$line" | sed -n 's/.*(\([0-9A-Fa-f-]\{36\}\)).*/\1/p')"
if [[ -z "$udid" ]]; then
  echo "no available iPhone simulator" >&2
  exit 1
fi

echo "simulator $line"
xcrun simctl boot "$udid" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$udid" -b >/dev/null

echo "building Helm (Debug, unsigned)"
xcodebuild \
  -project "$root/app/Helm.xcodeproj" \
  -scheme Helm \
  -configuration Debug \
  -destination "id=$udid" \
  -derivedDataPath "$root/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  ONLY_ACTIVE_ARCH=YES \
  build

app="$(find "$root/DerivedData/Build/Products" -path '*iphonesimulator*' -name 'Helm.app' -type d | head -1)"
if [[ -z "$app" ]]; then
  echo "Helm.app not in DerivedData" >&2
  exit 1
fi

xcrun simctl install "$udid" "$app"
mkdir -p "$out"

for name in "${shots[@]}"; do
  xcrun simctl terminate "$udid" "$bundle_id" >/dev/null 2>&1 || true
  xcrun simctl launch "$udid" "$bundle_id" -shot "$name" >/dev/null
  sleep "$wait_s"
  xcrun simctl io "$udid" screenshot "$out/$name.png"
  echo "wrote assets/docs/$name.png"
done
