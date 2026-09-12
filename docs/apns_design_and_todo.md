# APNs lock-screen (public service — not this beta)

How a **huge public Helm** would hear Kit when the process is dead,
without anyone opening the app first.

This is **not** demo, POC, or family-beta work. Sideload CarPlay is:
**open Helm, send a line, lock the phone, drive.** Reboot? Open Helm
again.

Cab’s cousin is FCM:
[`gantry-cab/docs/fcm_design_and_todo.md`](../../gantry-cab/docs/fcm_design_and_todo.md).
Cloudflare will not send APNs for us. Pendant Web Push is the PWA
lock-screen and is a different threat model (`PUT /api/push`). Helm
must **not** `PUT /api/push`.

When (if) this becomes a public service:

- Data-only (or content-available) push that Helm turns into the
  **same** communication notification as a live socket `reply` /
  `push`. Never let APNs display a generic banner with no Reply action.
- Dedup by frame `id`. Hydrate `replay` must not chime.
- Register after Google session; DELETE on sign-out / 4401. Spike
  never registers.
- Native token store on the Durable Object (`a:` or whatever pendant
  names it), keyed by Google `sub`, **not** overloaded onto VAPID
  `p:` rows.
- Missing Worker secrets → 404; Helm stays on “open then drive.”

Until then the boxes stay closed. Do not bring back a boot relisten
to “make APNs easier.”
