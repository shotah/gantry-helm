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

- [x] **Wire Google Sign-In iOS.** `GoogleSignIn-iOS` 9.2 on the Xcode
      target. `GET /api/auth/nonce` then `GIDSignIn` with that nonce,
      `POST /api/auth/token`. A failed GET stops sign-in. Tests for the
      exchange already live in `AuthThemeJpegTests`.
- [x] **PhotosPicker + camera encode.** Drive `shrinkSteps` /
      `shrinkToFit` with ImageIO. Caption + JPEG one inbound. Attach
      itself never sends.
- [x] **Hydrate face / backdrop GET.** `AvatarApi` + `BlobCache` keep
      JPEG + rev on disk and send `If-None-Match`. Header face and
      thread wallpaper paint the bytes.
- [x] **Google URL callback.** `onOpenURL` → `GIDSignIn.handle`.
      Without it the sheet returns and the token never lands.
- [x] **`-sample` launch argument.** DEBUG only. `Samples.swift` scenes
      (`unsigned` / `empty` / `thread` / `stream` / `ping` / `photo` /
      `down`). Release ignores it. Does not persist or connect.
- [x] **`make bake`.** `.env` → gitignored `app/Helm.local.xcconfig`.
      Reversed iOS client id is derived. Nora does not type secrets
      into Xcode.
- [x] **Loopback ATS.** `127.0.0.1` / `localhost` exception domains in
      `Info.plist`. `NSAllowsArbitraryLoads` stays false.
- [x] **Notification reply → send.** `HelmNotifyDelegate` is the
      `UNUserNotificationCenter` delegate so CarPlay / lock-screen
      Reply reaches `sendText`.
- [x] **CoreLocation when GPS is on.** Toggle asks When In Use and
      writes `prefs.lastGeo`. Drop a pin / attach-on-send use that fix.
- [x] **Socket sweep timer.** `watchingThread` + `sweepEveryMs` call
      `MailboxSocket.sweep` so a sibling inbound can flush.
- [x] **`scenePhase` for `resumed`.** Opening Settings no longer flips
      `resumed` via `onDisappear`. Kit HUNs stay suppressed while the
      scene is `.active`.
- [x] **Status bar typing.** `threadStatusLine` paints `Live · typing…`
      while `typingUntil` is live (`stream` sample / Kit draft).
- [x] **Battery + net on send.** Same `PhoneContext` fields as Cab.
      `UIDevice` level + `NWPathMonitor` peek.
- [x] **DEBUG sample chips.** Settings paints `sampleIds`. Release
      strips them. Does not persist or connect.
- [x] **`aims` board.** Parse with the 5 / 14 / 13 / 3 caps. Not a
      turn. Header target badges changes since the sheet was open
      (`helm` / `aimsSeen`). Sheet copy matches Cab. CarPlay shows
      nothing.
- [x] **`react`.** Ignore-then-paint on a Kit `reply` / `push`.
      Context menu is the palette. Socket down does not paint a chip.
- [x] **`seen` on ack.** Connect while the thread is up, and each
      live `reply` / `push`, send `ack` `seen: true`. A sibling
      inbound or a seen ack drops the local card.
- [x] **Pocket voice.** Header mic when config says `voice`. Hold
      bar, `SFSpeechRecognizer` in the Language locale, `POST /api/tts`
      with `lang`. Settings → Language is the same four ids.
- [x] **`todo` board.** Parse with the 100 / 240 caps. Not a turn.
      Header check-square badges changes since the sheet was open
      (`helm` / `todoSeen`), keyed by slug. Checkbox sends
      `/todo done <id>` and stays open. Add and Full list close.
      CarPlay shows nothing.

Device `act` stays out until pendant routes `kind=helm`.

## Medium

- [x] **Keychain for the JWE.** Session, spike, and email live in the
      keychain (`com.gantree.helm`). First read migrates the old
      UserDefaults copy. Spike still memory-only off loopback in debug.
- [ ] **Walk sibling inbound** on a deployed origin. Mouth already paints
      `inbound` as you and skips HUN. Walk:
      [sibling_phones.md](sibling_phones.md).
- [x] **Photo on the compose draft.** Stage the data URL (thumbnail +
      Remove); Send emits one inbound. Same as Cab / PWA.

## Large

- [ ] **CarPlay conversation screen** only if Apple grants the
      messaging entitlement. Sideload product is the notification
      card (`INSendMessageIntent` + Reply). Head-unit detect is the
      car-audio route (`HelmCar`), not a tile.
- [x] **`make shot`.** Simulator captures of the phone rows in
      `docs/screens.md`, written to `assets/docs/`. No second
      painter. Car rows wait on the conversation screen.

## Paid developer plan

Blocked on Apple Developer Program enrollment. A free Personal Team
cannot sign these capabilities, so Helm posts a plain card today.
`HelmNotify` reads the entitlements out of `embedded.mobileprovision`
and turns each path on by itself once the profile carries it.

Enrollment facts, from [developer.apple.com/programs/enroll](https://developer.apple.com/programs/enroll/):

- **US$99 per membership year**, local currency where available.
  Auto-renewing subscription; cancel up to a day before renewal; the
  current year is non-refundable.
- **Individual is fine.** One Apple Account plus a government photo
  ID, verified in the Apple Developer app on an iPhone or iPad. No
  company, no D-U-N-S number.
- **Not** the $299 Enterprise Program; that is MDM distribution.
- Also fixes the seven-day profile in
  [sideload_to_ios.md](sideload_to_ios.md): profiles last a year and
  up to 100 devices per device type can stay installed.
- The paid team is a new signing identity. Uninstall Helm from each
  device before the first Run on it, as the sideload doc already says.

- [ ] **Communication Notifications capability** on the Helm target.
      Lights up the `INSendMessageIntent` card: Kit avatar, promoted
      in Notification Center, CarPlay reads it aloud. Everything in
      [carplay_setup.md](carplay_setup.md) past the plain banner waits
      on this.
- [ ] **Time Sensitive Notifications capability.** Kit's card breaks
      through Focus (`.timeSensitive`). Until then it posts `.active`.
- [ ] **Entitlements file** (`app/Helm/Helm.entitlements`,
      `CODE_SIGN_ENTITLEMENTS` in `project.yml`) with both keys, plus
      a `v*` release that still passes without them. Keep the free
      sideload working: do not make signing fail on a Personal Team.
- [ ] **Walk the driveway** in [carplay_setup.md §3](carplay_setup.md)
      on the entitled build, then drop the "plain banner" row from §4.

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
