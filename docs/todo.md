# Todo

Open work only. Ordered **small → large**. A `v*` tag must never fail
the release job for a missing signing cert, App Store key, or APNs.

Mailbox contract: [pendant_handoff.md](pendant_handoff.md). Cab sister:
[gantry-cab docs/todo.md](../../gantry-cab/docs/todo.md).

Threat model: a phone that holds a **credential for the crane's room**
(Google session JWE or `MAILBOX_SECRET`) and a socket that **speaks for
the operator**. Losing the credential, sending it to the wrong host, or
letting another app read the thread are the failures that matter.

| Track | Rules |
| --- | --- |
| **Development** | Debug. Cleartext only to loopback. Spike may persist on loopback. |
| **Sideload (the product)** | Xcode / Developer Mode. `https://` Worker. Session expiry, payload caps, slug checks, no cleartext, GPS off until toggled. |
| **App Store** | Not a goal. Do not block sideload to chase a listing. A CarPlay **tile** needs Apple’s messaging entitlement. |

## Small

- [ ] **Wire Google Sign-In iOS.** Add `GoogleSignIn-iOS` to the Xcode
      target. `GET /api/auth/nonce` then `GIDSignIn` with that nonce,
      `POST /api/auth/token`. 404 nonce → `mintNonce()`. Tests for the
      exchange already live in `AuthThemeJpegTests`.
- [ ] **PhotosPicker + camera encode.** Drive `shrinkSteps` /
      `shrinkToFit` with ImageIO. Caption + JPEG one inbound. Attach
      itself never sends.
- [ ] **Hydrate face / backdrop GET.** `Avatar` URLs and `If-None-Match`
      are in Mailbox. App still needs the bytes on disk.

## Medium

- [ ] **Keychain for the JWE.** High. `HelmPrefs` writes the session
      to UserDefaults. Cab’s Tink ticket is the same threat. Wrap with
      Keychain; spike stays memory-only off loopback.
- [ ] **Walk sibling inbound** on a deployed origin. Mouth already paints
      `inbound` as you and skips HUN. Walk:
      [sibling_phones.md](sibling_phones.md).
- [ ] **Photo on the compose draft.** Stage the data URL; Send emits
      one inbound. Same as Cab / PWA.

## Large

- [ ] **CarPlay conversation screen** only if Apple grants the
      messaging entitlement. Sideload product is the notification card.
- [ ] **Replace hand-painted shots** once the UI settles. Cab’s
      `DocsShot` lesson: do not maintain a second painter.

## Watch — not a ticket

- **No cookies.** `URLSessionConfiguration.httpShouldSetCookies = false`.
  Do not add a cookie jar that stores `pendant_session`.
- **`MAILBOX_SECRET`:** a phone that has it *is* the operator. Lab-only.
- **No certificate pinning.** Fine for a Cloudflare Worker + system
  trust store.
- **Notifications are private.** Keep communication notifications from
  showing full text on a locked lock screen if the OS allows it.
- **Secrets in `.env` only.**
- Real phones: HTTPS Worker. Debug allows loopback cleartext and is
  debugger-attached.

## Not this version

Pendant and Cab do not have these either. Do not build them "to catch up":

- Failed + retry on an unacked send; copy on long-press
- Painted timestamps / day chips
- Stop-a-turn, quote / reply-to, reactions, read receipts
- Sign in with Apple
- APNs lock-screen (process dead)

APNs is **not** demo / POC / family-beta. Sideload CarPlay is: open
Helm, send a line, drive. Design:
[apns_design_and_todo.md](apns_design_and_todo.md).
