#!/usr/bin/env bash
# Find llvm-cov + profdata from `swift test --enable-code-coverage` and write JSON.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$root/.build/coverage.json}"

cd "$root"

PROF="$(find .build -name 'default.profdata' | head -n1)"
if [[ -z "$PROF" ]]; then
  echo "missing default.profdata; run: swift test --enable-code-coverage" >&2
  exit 1
fi

BIN="$(find .build -name 'gantry-helmPackageTests.xctest' | head -n1)"
if [[ -z "$BIN" ]]; then
  BIN="$(find .build -name '*PackageTests.xctest' | head -n1)"
fi
if [[ -z "$BIN" ]]; then
  echo "missing PackageTests.xctest" >&2
  exit 1
fi

# Linux: the xctest "bundle" is the executable. Darwin: Contents/MacOS/*.
EXE="$BIN"
if [[ -d "$BIN/Contents/MacOS" ]]; then
  EXE="$(find "$BIN/Contents/MacOS" -type f | head -n1)"
fi

LLVM_COV="$(command -v llvm-cov || true)"
if [[ -z "$LLVM_COV" ]]; then
  # Swift toolchain
  if command -v swift >/dev/null; then
    TOOLCHAIN="$(dirname "$(dirname "$(command -v swift)")")"
    if [[ -x "$TOOLCHAIN/usr/bin/llvm-cov" ]]; then
      LLVM_COV="$TOOLCHAIN/usr/bin/llvm-cov"
    fi
  fi
fi
if [[ -z "$LLVM_COV" ]]; then
  echo "llvm-cov not on PATH" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT")"
"$LLVM_COV" export -format=json -instr-profile="$PROF" "$EXE" > "$OUT"
echo "wrote $OUT"
