# Design

A phone we own — an iPhone this time — talking to a crane, without
opening a port on the harness. Pitch: [root readme](../README.md).
How it is wired: [architecture.md](architecture.md). What's left:
[todo.md](todo.md). Walk: [setup.md](setup.md).

The mailbox is already built. It lives in
[gantry-pendant](https://github.com/shotah/gantry-pendant). Cab is
the Android mouth. **This repo is the iOS mouth.** Same Durable
Object. Same frames. Do not fork the Worker.

## Problem

ai-gantry is outbound-only. Telegram, Discord Gateway, and Slack
Socket Mode work because **their** hosts are the mailbox. Pendant
replaced Telegram's relay with a Durable Object we deploy. Cab is
that room on Android + Auto.

iPhone still talks through the PWA (Add to Home Screen). Background
is weak, Web Speech dies in the standalone WebView, and CarPlay is
not a browser. Native iOS is the sister Cab already is on Android —
not Expo wrapping the Vinext UI, not a second mailbox.

Two phone ideas people mix up:

| Idea | What it is | This repo? |
| --- | --- | --- |
| Yard on a phone | Operator board in a browser | No — gantree mobile track |
| Gantry helm | Chat mouth. Message Kit. CarPlay later. | Yes |

## Principles

1. **Zero inbound on the crane.** Same rule as Telegram and Cab. The
   phone dials the mailbox. Do not grow a listen port on `gantry`.
2. **Same room as Cab and the PWA.** One Durable Object per crane
   slug. Helm is another `role=phone` socket on the same Google
   `sub`. Sibling live-delivery is already on the Worker.
3. **Mailbox first, shell second.** `Sources/Mailbox` is the
   Android-free `:mailbox` split Cab still wants — wire, mouth,
   photo caps, connect gates. `app/Helm` is the SwiftUI / CarPlay
   skin. Do not put URLSession or Keychain decisions into a view.
4. **Google is the human.** Same Web client `aud` as Cab. A **new
   iOS** OAuth client (bundle id) lives in GCP only. Helm POSTs
   `{ id_token, nonce }` to `/api/auth/token`. Sign in with Apple
   is a mailbox auth change — later, not a Helm-only door.
5. **The phone may send more than text.** GPS on send, caption +
   JPEG together, slash catalog from the crane. `Text` stays the
   words; `context.geo` updates `here`. Same
   `stripHarnessContext` as Cab / pendant / ai-gantry.
6. **CarPlay is the car, when it exists.** Spoken reply / read-aloud
   of `reply` / `push`. Not a second protocol. APNs lock-screen is
   public-scale only, same later as Cab FCM.

## Does it have to have a server?

Yes: the **existing** pendant Worker. No: a second Durable Object,
a Vapor mailbox, or CloudKit as the room.

```text
iPhone  →  pendant Worker (Durable Object)  ←  crane (outbound)
                 ▲
          Cab / PWA already here
```

## Stack

| | gantry-cab | gantry-helm |
| --- | --- | --- |
| Mouth | Kotlin + Compose | Swift + SwiftUI |
| Wire | `mailbox/*.kt` | `Sources/Mailbox/*.swift` |
| Car | Android Auto `MessagingStyle` | CarPlay (later; `NotifyGate` already names it) |
| Install | Sideload APK / Play internal | Xcode / TestFlight later |
| Auth | Google ID token → JWE | Same POST. iOS OAuth client in GCP |

Foundation-only Mailbox so `swift test` can run on a Mac without a
simulator. UIKit / CarPlay stay in `app/`.

## Non-goals

- A second Worker or a forked mailbox schema
- Sign in with Apple before the mailbox accepts it
- App Store listing as the experiment (TestFlight / sideload first)
- Expo / React Native wrapping the PWA
- APNs to catch up Cab FCM (neither is family-beta)
- Feature-matching iMessage
- Putting chat in the Gantree console

## Done enough to experiment

`Sources/Mailbox` parses the same frames Cab does, paints them in
`Mouth`, and refuses a bad photo the same way. The SwiftUI shell
and a TestFlight build are how you talk from a pocket. The crane
still has **no inbound port**.
