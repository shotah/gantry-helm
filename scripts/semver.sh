#!/usr/bin/env bash
# Semver helpers for make release — same rules as ai-gantry / gantry-pendant.
set -euo pipefail

SEMVER='^v?([0-9]+)\.([0-9]+)\.([0-9]+)$'

die() {
  echo "Error: $*" >&2
  exit 1
}

version_without_v() {
  local tag="${1:-}"
  echo "${tag#v}"
}

# next_version <current> <bump> [explicit]
# empty current + patch → v0.0.1 (same as sister repos).
next_version() {
  local current="${1:-}"
  local bump="${2:-patch}"
  local explicit="${3:-}"

  if [[ -n "$explicit" ]]; then
    if [[ ! "$explicit" =~ $SEMVER ]]; then
      die "invalid --version ${explicit@Q} (want vMAJOR.MINOR.PATCH)"
    fi
    echo "v${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
    return 0
  fi

  local major=0 minor=0 patch=0
  if [[ -n "$current" ]]; then
    if [[ ! "$current" =~ $SEMVER ]]; then
      die "latest tag ${current@Q} is not semver; pass --version=vX.Y.Z"
    fi
    major="${BASH_REMATCH[1]}"
    minor="${BASH_REMATCH[2]}"
    patch="${BASH_REMATCH[3]}"
  fi

  case "${bump,,}" in
    patch|"")
      patch=$((patch + 1))
      ;;
    minor)
      minor=$((minor + 1))
      patch=0
      ;;
    major)
      major=$((major + 1))
      minor=0
      patch=0
      ;;
    *)
      die "invalid --bump ${bump@Q} (want patch, minor, or major)"
      ;;
  esac
  echo "v${major}.${minor}.${patch}"
}

# version_code <tag-or-name> → Play versionCode (MAJOR*10000 + MINOR*100 + PATCH)
version_code() {
  local raw
  raw="$(version_without_v "${1:-}")"
  if [[ ! "v${raw}" =~ $SEMVER ]]; then
    die "invalid version ${1@Q} (want vMAJOR.MINOR.PATCH)"
  fi
  echo $((BASH_REMATCH[1] * 10000 + BASH_REMATCH[2] * 100 + BASH_REMATCH[3]))
}

usage() {
  cat <<'EOF'
Usage:
  scripts/semver.sh next <current> [bump] [explicit]
  scripts/semver.sh name <tag>
  scripts/semver.sh code <tag>
EOF
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  cmd="${1:-}"
  shift || true
  case "$cmd" in
    next)
      next_version "${1:-}" "${2:-patch}" "${3:-}"
      ;;
    name)
      version_without_v "${1:-}"
      ;;
    code)
      version_code "${1:-}"
      ;;
    -h|--help|"")
      usage
      ;;
    *)
      die "unknown command ${cmd@Q}"
      ;;
  esac
fi
