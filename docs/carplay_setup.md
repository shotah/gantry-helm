# CarPlay: after you install Helm

What to do on the iPhone and in Helm so that Kit is read aloud in the
car and your spoken reply goes back to the crane.

Install first: [sideload_to_ios.md](sideload_to_ios.md).

## 0. What "working" looks like

- **There is no Helm tile in the car** from a sideload. Apple only
  admits a messaging *app* into CarPlay with the CarPlay messaging
  entitlement. Helm’s in-dash product is the **message card** — Kit’s
  reply over maps, the car chimes, CarPlay reads it and offers **Reply**.
- You speak; Siri turns it into text; Helm sends it to the crane as
  `inbound` tagged `surface: carplay`.
- Kit only reaches the car after you **open Helm** (Connect, or send
  a line) so the mailbox socket is up, then **lock the phone**. CarPlay
  cannot start Helm for you. Reboot? Open Helm again before you drive.

## 1. Phone

1. Notifications for Helm: on. Time Sensitive / communication allowed.
2. Siri & CarPlay: Helm allowed to announce notifications.
3. Background App Refresh: on (helps a little; it is not APNs).
4. Leave Helm alone once it is Live. Do not Force Quit it. Lock the
   phone.

## 2. Helm

1. Settings: **Mailbox** = the pendant Worker `https://…`, **Talking to**
   = the crane’s room (`kit`), then *Continue with Google* or paste the
   phone secret.
2. **Connect** (or send a line), then wait for the bar to say **Live**.
3. Lock the phone.
4. Settings → **Test car voice**. Expect a *kit* card that starts
   "Car check from Helm".

## 3. Driveway

1. Plug the phone into CarPlay (USB or wireless).
2. Phone: Helm → Settings → **Test car voice**.
3. You should get a chime, a kit card, CarPlay reading the check
   sentence, then a chance to reply. That text lands in the Helm thread
   as your bubble.
4. If the voice says the phone does not see CarPlay but the car still
   read it, you are fine: the sentence reports Helm’s probe; the reading
   comes from CarPlay’s notification listener. Replies just get tagged
   `ios` instead of `carplay`.

## 4. When it does not

| What you see | Why | Do |
| --- | --- | --- |
| Test card on the phone, nothing in the car | Announce notifications off; or CarPlay DND | §1 |
| Card read, reply never reaches Kit | Helm not Live; reply is queued | Connect again |
| Worked yesterday, silent today | Reboot / Force Quit — Helm does not relisten on boot | Open Helm, send a line, then drive |
| Looking for a Helm tile in CarPlay | Expected | There is none for a sideload. See §0 |
