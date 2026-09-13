# Development

How this repo is tested on a Linux host (Steam Deck) that has **no
Swift toolchain**. Nora’s Mac uses the same Make targets with a
native `swift`. CI is `.github/workflows/ci.yml`.

There is no SwiftLint / `make lint`. Typecheck is `swift test`
compiling. Script tests are bash. Mailbox tests are XCTest under
`Tests/MailboxTests/`, mirroring `Sources/Mailbox/`. Do not colocate
`*.test.swift` next to sources.

Do not poke the Worker with curl. If a parse path needs checking,
add a Vitest-shaped XCTest and call the function.

## What runs where

| Layer | Where | Command |
| --- | --- | --- |
| Script tests (semver, badge, release, hooks, bake) | Host bash + Node | `make test-scripts` |
| Mailbox unit tests | Docker `swift:6.3.3` (or host `swift`) | `swift test` |
| Coverage + 70% bar | Same Swift as the tests, then host Node for the gate | see below |
| Unsigned Simulator `.app` | macOS / Actions `macos-latest` only | `make ios` |
| Device / Google / spike walk | Nora + Xcode | [setup.md](setup.md) |

Linux and this Deck never see SwiftUI, GoogleSignIn, Photos, or
`xcodebuild`. That compile is the `ios` job. The mailbox is the
wire, mouth, themes, photo caps, avatar GET.

## Script tests (no Swift)

From the repo root. Host needs bash and Node (badge % parser).

```bash
chmod +x scripts/*.sh test/scripts/*.test.sh
make test-scripts
```

That is `semver`, `coverage-badge`, `release`, `hooks`, `helm-bake`.
`helm-bake` refuses a real Worker host or a Google client id in the
public tree.

## Mailbox tests (Docker)

Image matches CI: **Swift 6.3.3**. First run pulls ~1 GB.
`make test-app` / `make coverage` wrap that image.

```bash
make test-app
make test-app FILTER=SamplesTests
```

Mount the repo at `/src` so `.build/` stays on disk. The container
user may leave root-owned files in `.build`; `make clean` removes
them (may need `sudo` on the Deck). Override the image with
`SWIFT_IMAGE=swift:6.3.3`.

## Coverage (the CI `check` job)

CI: `setup-node@v7` (Node 24) → `make test-scripts` → `make
coverage`. Export runs **inside** the Swift image so `llvm-cov` is
on PATH (hosted `setup-swift` often has `swift` and not `llvm-cov`).
The 70% gate is host Node.

```bash
make coverage
```

`coverage-export.sh` asks `llvm-cov export -format=json`. Docker
5.10 / 6.3.3 only have text / html / **lcov** — the script then
writes lcov and awk-builds the JSON shape `coverage-pct.sh` already
reads. The 70% bar is **line** coverage of paths containing
`Sources/Mailbox` only.

## Linux Swift traps

Apple `swift` accepts labeled init arguments in any order. Linux
does not — match the `init` parameter list (`kind` then `text` on
`WireFrame`; `lines` then `typing` on `SampleScene`). A Mac-only
green `swift test` can still fail the Ubuntu job.

Other Linux-only edges already covered by tests:

- `import FoundationNetworking` next to `Foundation` (`URLSession`).
- `Data(base64Encoded:)` wants padding (`QQ` / `aa`).
- `JSONSerialization` yields `NSDictionary` / `NSArray`.
- `NSNumber(0)` is `is Bool` on Linux; `jsonWholeNumber` checks
  `CFBoolean` first.
- ImageIO is Apple-only (`#if canImport(ImageIO)`). Linux
  passthroughs an accepted JPEG that already fits.

## What this machine cannot verify

- `make ios` / a clickable UI / Google Sign-In / keychain / camera.
- A signed IPA. GitHub Release notes only; no APK-style sideload
  artifact. See [setup.md](setup.md).
- Live pendant. Spike and Google walks are Nora + a Worker.

Reproduce a red Actions job the same way: script tests on the host,
then the Docker `swift test` / coverage block above. The public
Actions log page needs a GitHub sign-in; the compile error prints
in the container either way.
