# Setup

Sister of gantry-cab and gantry-pendant. The Worker is the mailbox. This
app is another phone. CarPlay is a communication notification.

## Build

```bash
make test            # no Swift: make test-scripts
make coverage        # llvm-cov + 70% bar
make check-app       # test + coverage
make install-hooks   # pre-commit: tests; pre-push: coverage
make ios             # xcodebuild (macOS)
```

Needs Swift 5.9+ (`swift test`). Xcode: open `app/Helm.xcodeproj`, which
depends on the local `Mailbox` package at the repo root. iOS 17+.

This app is a normal iPhone chat (thread + communication notifications).
CarPlay is extra, not the only mouth. The pendant PWA in Safari is a
different client. Cab is the Android sister.

Debug builds may talk cleartext to `127.0.0.1` / `localhost` only. Release
is HTTPS. The 70% bar is line coverage of `Sources/Mailbox` (wire + mouth),
same idea as Cab gating the JVM mailbox.

## Publish (GitHub Release)

This folder is its own git remote (like `repos/gantry-cab`), not a path
inside the gantree tree. `make release` refuses to tag a parent repo.

```bash
make release                 # patch
make release BUMP=minor
make release TAG=v0.2.0
make release DRY_RUN=1
```

Sideload from Xcode or a Developer-Mode IPA. Walk:
[sideload_to_ios.md](sideload_to_ios.md). Bake the mailbox with
`HELM_MAILBOX_ORIGIN` and `HELM_GOOGLE_WEB_CLIENT_ID` (Actions secrets).
Do not put a real Worker URL in git.

## Loopback (no Google)

1. Pendant: `npm run dev` (binds `127.0.0.1:3000`).
2. iOS Simulator: origin `http://127.0.0.1:3000`, slug `kit`, spike
   secret from pendant `.dev.vars` `MAILBOX_SECRET`.
3. Connect. Type. `/crane` tab on the laptop is the other socket.

A physical phone on LAN needs pendant bound to the LAN IP. The
default `vinext dev -H 127.0.0.1` will not see it.

## Google (production Worker)

Two OAuth clients in the **same** GCP project as pendant. Copying the
pendant **Web** client id into Helm is correct. You still need a **new
iOS** client. Helm does not use a Google redirect / callback URI.

| Client | Type | Where it goes | Redirect / callback |
| --- | --- | --- | --- |
| Pendant’s existing Web application | Web | `HELM_GOOGLE_WEB_CLIENT_ID` (`.env`). This is the ID token `aud`. | Pendant’s own Web callback — leave it. Do **not** add a Helm URL here. |
| **New** iOS client | iOS | GCP only, plus `HELM_GOOGLE_IOS_CLIENT_ID` for GIDSignIn’s URL scheme. | **None.** |

What actually happens: Google Sign-In mints an ID token on the phone,
then Helm `POST`s `{ id_token, nonce }` to
`https://<mailbox>/api/auth/token`. That Worker URL is the only
“callback.” Allowlist is still `PENDANT_ALLOWED_USERS`.

`GET /api/auth/nonce` first; mint locally on 404 / junk / empty. Close
`4401` / handshake 401 drops the JWE; 403 does not.

Sign in with Apple is a **mailbox** change (pendant `security.md`). Do
not invent it in Helm.

## CarPlay

- A real car gets the communication notification card, not a Helm tile.
- Open Helm (send a line or Connect) before you drive, then lock the
  phone. The socket does not come back on reboot.
- Voice reply is CarPlay / Siri STT. We never run a second recognizer
  in the dash.
