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

Needs Swift 5.9+ (`swift test`). CI uses Swift 6.3.3 and Node 24.
Xcode: open `app/Helm.xcodeproj`, which depends on the local `Mailbox`
package at the repo root. iOS 17+.

### Without a Mac

Linux and this Deck get the mailbox: `make test-scripts`, `swift test`
in Docker (`swift:6.3.3`), coverage of `Sources/Mailbox`. Exact
commands: [development.md](development.md). That is the wire, mouth,
themes, photo caps, avatar GET — not the screen.

GitHub Actions `macos-latest` runs `make ios`: an unsigned Simulator
build of `app/Helm`. That catches SwiftUI / GoogleSignIn / Photos
compile breaks. It is not an IPA you can put on a phone, and there is
no window to click.

To *see* Helm you still need someone with an iPhone (or a Mac
Simulator) and an Apple ID. Cab and the pendant PWA are the mouths
that run here. Sideload:
[sideload_to_ios.md](sideload_to_ios.md).

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
[sideload_to_ios.md](sideload_to_ios.md).

GitHub repo **Settings → Secrets and variables → Actions** — same
idea as Cab. You can copy the Cab values for the first two:

| Secret / variable | Copy from Cab? | What it is |
| --- | --- | --- |
| `HELM_MAILBOX_ORIGIN` | `CAB_MAILBOX_ORIGIN` | HTTPS Worker URL. No trailing slash. |
| `HELM_GOOGLE_WEB_CLIENT_ID` | `CAB_GOOGLE_WEB_CLIENT_ID` | Pendant **Web** OAuth client (token `aud`). |
| `HELM_GOOGLE_IOS_CLIENT_ID` | No — new | iOS OAuth client for bundle `com.gantree.helm`. |

Do not put a real Worker URL in git. Today's Release job writes notes
only (no IPA). Nora still bakes those keys into Xcode from `.env`.

## Loopback (no Google)

1. Pendant: `npm run dev` (binds `127.0.0.1:3000`).
2. iOS Simulator: origin `http://127.0.0.1:3000`, slug `kit`, spike
   secret from pendant `.dev.vars` `MAILBOX_SECRET`.
3. Connect. Type. `/crane` tab on the laptop is the other socket.

A physical phone on LAN needs pendant bound to the LAN IP. The
default `vinext dev -H 127.0.0.1` will not see it.

## Google (production Worker)

Two OAuth clients in the **same** GCP project as pendant. Copying the
pendant **Web** client id into Helm is correct (same value as Cab).
You still need a **new iOS** client. Helm does not use a Google
redirect / callback URI.

| Client | Type | Where it goes | Redirect / callback |
| --- | --- | --- | --- |
| Pendant’s existing Web application | Web | `HELM_GOOGLE_WEB_CLIENT_ID` (`.env` and the GitHub secret). This is the ID token `aud`. | Pendant’s own Web callback — leave it. Do **not** add a Helm URL here. |
| **New** iOS client | iOS | `HELM_GOOGLE_IOS_CLIENT_ID` (`.env` and GitHub). GIDSignIn + the reversed URL scheme. | **None.** |

There is **no SHA-1** on iOS. Android binds package + signing-cert
fingerprint. iOS binds **bundle id** `com.gantree.helm`. Apple’s
signing team / cert is how the phone trusts the install — Google
never sees that cert.

What actually happens: Google Sign-In mints an ID token on the phone,
then Helm `POST`s `{ id_token, nonce }` to
`https://<mailbox>/api/auth/token`. That Worker URL is the only
“callback.” Allowlist is still `PENDANT_ALLOWED_USERS`.

1. APIs & Services → Credentials → **Create credentials** → OAuth
   client ID → **iOS** (this is the new one, not a copy of Web or the
   Android client). Bundle ID: `com.gantree.helm`. Leave App Store ID
   empty until there is a store listing. No SHA-1 field. No authorized
   redirect URIs.

   Google shows the client id
   (`….apps.googleusercontent.com`) and the **iOS URL scheme**
   (`com.googleusercontent.apps.…` — the id reversed). Helm needs the
   client id in `HELM_GOOGLE_IOS_CLIENT_ID`; the scheme is derived
   from it. Do not paste either into git.

2. Bake the Worker host, the **Web** client id, and the **iOS**
   client id at assemble time. Copy `.env.example` to `.env`:

   ```
   HELM_MAILBOX_ORIGIN=https://pendant.example.com
   HELM_GOOGLE_WEB_CLIENT_ID=<pendant Web client id>
   HELM_GOOGLE_IOS_CLIENT_ID=<new iOS client>
   ```

   First two are the same strings as Cab’s `CAB_MAILBOX_ORIGIN` and
   `CAB_GOOGLE_WEB_CLIENT_ID`. GitHub Releases / Nora’s Xcode bake
   also read these as repo Actions secrets (or variables), plus
   `HELM_GOOGLE_IOS_CLIENT_ID`.

3. Rebuild / Run on device, then Continue with Google. If the sheet
   never returns to Helm, the iOS client’s bundle id does not match
   `com.gantree.helm`, or the reversed URL scheme is missing from
   Info.plist. The Web id in `.env` is fine. If Google succeeds but
   the bar stays **Offline**, that is the mailbox socket, not OAuth.

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
