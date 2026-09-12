# CarPlay

The car mouth, when it exists. Cab's cousin:
[gantry-cab `docs/android_auto_setup.md`](https://github.com/shotah/gantry-cab/blob/main/docs/android_auto_setup.md).

CarPlay reads Kit aloud and stuffs a spoken reply into the same
`inbound` frame the phone compose uses. Helm does not wrap the
Vinext PWA. It does not run a second mailbox.

`NotifyGate` already decides when a communication notification may
post (`shouldPost`, `shouldBuzz`, `carTestBlocked`, test-car copy).
The conversation template and the entitlement are app work.

## Shape

- Host STT → `inbound` text. We never run our own recognizer in
  the dash.
- Host TTS of `reply` / `push`. Skip on `replay` and on `inbound`
  (your other mouth).
- Open Helm and send a line **before** you project, then lock the
  phone. The socket does not come back on reboot.
- APNs is not how the grocery run works:
  [apns_design_and_todo.md](apns_design_and_todo.md).

## Entitlements

CarPlay messaging needs an Apple entitlement. A Personal Team
sideload may not get a CarPlay tile in a real car — same class of
problem as Cab's Auto templated screen vs Unknown-sources
notifications. Do not block the phone thread on that paperwork.

Settings → **Test car voice** posts a check card through the same
path so you can hear it in the driveway once notifications are
allowed.
