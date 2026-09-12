#!/usr/bin/env bash
# Real mailbox / OAuth values stay out of git. Bake them at assemble time.
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"

grep -qx '.env' "$root/.gitignore" || {
  echo "FAIL: .gitignore must ignore .env" >&2
  exit 1
}

test -f "$root/.env.example" || {
  echo "FAIL: missing .env.example" >&2
  exit 1
}
grep -q 'HELM_MAILBOX_ORIGIN=' "$root/.env.example" || {
  echo "FAIL: .env.example should set HELM_MAILBOX_ORIGIN" >&2
  exit 1
}
grep -q 'HELM_GOOGLE_WEB_CLIENT_ID=' "$root/.env.example" || {
  echo "FAIL: .env.example should set HELM_GOOGLE_WEB_CLIENT_ID" >&2
  exit 1
}
grep -q 'HELM_GOOGLE_IOS_CLIENT_ID=' "$root/.env.example" || {
  echo "FAIL: .env.example should set HELM_GOOGLE_IOS_CLIENT_ID" >&2
  exit 1
}

grep -q 'HELM_MAILBOX_ORIGIN' "$root/.github/workflows/release.yml" || {
  echo "FAIL: release.yml should pass HELM_MAILBOX_ORIGIN" >&2
  exit 1
}
grep -q 'HELM_GOOGLE_WEB_CLIENT_ID' "$root/.github/workflows/release.yml" || {
  echo "FAIL: release.yml should pass HELM_GOOGLE_WEB_CLIENT_ID" >&2
  exit 1
}
grep -q 'HELM_GOOGLE_IOS_CLIENT_ID' "$root/.github/workflows/release.yml" || {
  echo "FAIL: release.yml should pass HELM_GOOGLE_IOS_CLIENT_ID" >&2
  exit 1
}

plist="$root/app/Info.plist"
grep -q 'com.gantree.helm\|PRODUCT_BUNDLE_IDENTIFIER' "$root/app/Helm.xcodeproj/project.pbxproj" || {
  echo "FAIL: Xcode project must set com.gantree.helm" >&2
  exit 1
}
grep -q 'NSLocationWhenInUseUsageDescription' "$plist" || {
  echo "FAIL: Info.plist must declare location usage" >&2
  exit 1
}

if grep -q 'NSAllowsArbitraryLoads</key>$' "$plist"; then
  if grep -A1 'NSAllowsArbitraryLoads' "$plist" | grep -q '<true/>'; then
    echo "FAIL: release ATS must not allow arbitrary loads" >&2
    exit 1
  fi
fi

debug_ats="$root/app/Helm/Debug-ATS.plist"
grep -q '127.0.0.1' "$debug_ats" || {
  echo "FAIL: debug ATS should allow simulator loopback" >&2
  exit 1
}
if grep -q 'NSAllowsArbitraryLoads' "$debug_ats"; then
  echo "FAIL: debug ATS must not be a global cleartext allow" >&2
  exit 1
fi

if grep -rI --exclude-dir=.build --exclude-dir=.git --exclude-dir=.swiftpm \
  --exclude=.env --exclude=helm-bake.test.sh \
  -n 'bldhosting' "$root"
then
  echo "FAIL: personal mailbox host must not be in the public tree" >&2
  exit 1
fi

if grep -rI --exclude-dir=.build --exclude-dir=.git --exclude-dir=.swiftpm \
  --exclude=.env --exclude=helm-bake.test.sh \
  -nE '[0-9]+-[a-z0-9]+\.apps\.googleusercontent\.com' "$root"
then
  echo "FAIL: Google client id must not be in the public tree" >&2
  exit 1
fi

sock="$root/app/Helm/MailboxSocket.swift"
grep -q 'httpShouldSetCookies = false' "$sock" || {
  echo "FAIL: MailboxSocket must not store cookies (CSRF is PWA-only)" >&2
  exit 1
}
grep -q 'Authorization' "$sock" || {
  echo "FAIL: MailboxSocket must send Authorization Bearer" >&2
  exit 1
}

grep -q 'contents: read' "$root/.github/workflows/ci.yml" || {
  echo "FAIL: ci.yml default token should be contents: read" >&2
  exit 1
}
grep -q 'persist-credentials: false' "$root/.github/workflows/ci.yml" || {
  echo "FAIL: ci.yml checkout should not persist credentials" >&2
  exit 1
}

echo "ok helm-bake"
