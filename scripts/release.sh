#!/usr/bin/env bash
# Bump semver, commit VERSION, annotated-tag (v* + floating latest), push.
# Triggers GitHub Release (tag v*).
#
#   make release
#   make release BUMP=minor
#   make release TAG=v0.2.0
#   make release DRY_RUN=1
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
# shellcheck source=semver.sh
source "$root/scripts/semver.sh"

bump="${BUMP:-patch}"
explicit="${TAG:-}"
dry_run="${DRY_RUN:-}"
skip_push="${SKIP_PUSH:-}"
allow_dirty="${ALLOW_DIRTY:-}"

git_top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
own_repo=0
if [[ -n "$git_top" && "$git_top" == "$root" ]]; then
  own_repo=1
fi

if [[ "$own_repo" -eq 0 ]]; then
  echo "gantry-helm must be its own git checkout (like repos/gantry-cab)." >&2
  echo "git root is ${git_top:-"(none)"} — init a remote here before make release." >&2
  if [[ -z "$dry_run" ]]; then
    exit 1
  fi
  echo "Dry run — using VERSION only (parent tags are ignored)."
fi

git_out() {
  if [[ "$own_repo" -eq 0 ]]; then
    return 0
  fi
  git "$@" 2>/dev/null || true
}

git_live() {
  git "$@"
}

skip_fetch="${SKIP_FETCH:-}"

if [[ "$own_repo" -eq 1 && -z "$skip_fetch" ]]; then
  git fetch --tags --quiet 2>/dev/null || true
fi

current_tag="$(git_out tag -l 'v*' --sort=-v:refname | head -n1)"
file_ver=""
if [[ -f VERSION ]]; then
  file_ver="$(tr -d '[:space:]' < VERSION)"
fi
current="${current_tag:-$file_ver}"
next="$(next_version "$current" "$bump" "$explicit")"

echo "Current tag: ${current_tag:-"(none)"}"
echo "Next tag:    ${next}"
echo "Also tag:    latest (moves to same commit)"

if [[ -n "$dry_run" ]]; then
  echo "Dry run — no commit, tag, or push."
  exit 0
fi

if [[ -z "$allow_dirty" ]]; then
  dirty="$(git status --porcelain)"
  if [[ -n "$dirty" ]]; then
    echo "Error: working tree is dirty; commit or stash first (or ALLOW_DIRTY=1):" >&2
    echo "$dirty" >&2
    exit 1
  fi
fi

printf '%s\n' "$next" > VERSION

git_live add VERSION
if [[ -n "$(git status --porcelain VERSION)" ]]; then
  git_live commit -m "chore: release ${next}"
  echo "Committed VERSION update."
else
  echo "VERSION already at ${next}"
fi

git_live tag -a "$next" -m "Release ${next}"
echo "Created tag ${next}"
git_live tag -fa latest -m "Release ${next} (latest)"
echo "Moved tag latest → ${next}"

if [[ -n "$skip_push" ]]; then
  echo "Skipped push (SKIP_PUSH=1)."
  exit 0
fi

git_live push origin HEAD
git_live push origin "$next"
git_live push --force origin refs/tags/latest
echo "Pushed HEAD, ${next}, and latest — GitHub Release workflow should start."
