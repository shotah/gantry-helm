#!/usr/bin/env bash
# Home-screen glyph is the pendant from assets/logo.svg, not the black dev icon.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
logo="$root/assets/logo.svg"
icon="$root/app/Helm/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
proj="$root/app/Helm.xcodeproj/project.pbxproj"

grep -Fq 'd="M20 18h24v28a12 12 0 0 1-24 0V18z"' "$logo" || {
  echo "FAIL: assets/logo.svg is missing the pendant body path" >&2
  exit 1
}

[[ -f "$icon" ]] || {
  echo "FAIL: AppIcon.png missing (raster of assets/logo.svg)" >&2
  exit 1
}

python3 - "$icon" <<'PY'
import struct
import sys

path = sys.argv[1]
with open(path, "rb") as handle:
    data = handle.read(26)
if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
    sys.exit("FAIL: AppIcon.png is not a PNG")
width, height = struct.unpack(">II", data[16:24])
color = data[25]
if (width, height) != (1024, 1024):
    sys.exit(f"FAIL: AppIcon.png is {width}x{height}, want 1024x1024")
if color != 2:
    sys.exit(f"FAIL: AppIcon.png color type {color}, want opaque RGB")
PY

count=$(grep -c 'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;' "$proj" || true)
[[ "$count" -ge 2 ]] || {
  echo "FAIL: Debug and Release must set ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon" >&2
  exit 1
}

grep -q 'Assets.xcassets in Resources' "$proj" || {
  echo "FAIL: Assets.xcassets must be in the Resources build phase" >&2
  exit 1
}

echo "ok helm-icon"
