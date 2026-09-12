# Pendant mailbox — Helm handoff

Mailbox checkout (`gantry-pendant`) owns the Worker. **This file is the
Helm work.** Do not wait for a pendant agent to touch Swift. Cab already
walked the same wire; copy those lessons, do not invent a second protocol.

Wire: pendant
[`docs/frontends.md`](https://github.com/shotah/gantry-pendant/blob/main/docs/frontends.md).
Voice: pendant [`docs/voice.md`](https://github.com/shotah/gantry-pendant/blob/main/docs/voice.md).
Sibling: [sibling_phones.md](sibling_phones.md).

---

## Already true (do not "fix")

These landed on the Worker. Helm matches Cab.

- **Cookie CSRF is PWA-only.** `MailboxSocket` uses ephemeral
  `URLSession` with `httpShouldSetCookies = false` and
  `Authorization: Bearer <jwe>`. Do not add a cookie jar.
- **`GET /api/auth/config`** may include additive `version` and `dev`.
  `parseAuthConfig` keeps `mode` / `google` and drops unknown keys.
- **Push host allowlist** is PWA Web Push (`PUT /api/push`). Helm does
  not subscribe that way. Do not invent a Helm push URL. APNs is later.
- **Google return-to** is the PWA browser flow. Helm never hits
  `GET /api/auth/google`.
- **`GET /api/auth/logout` is gone.** Sign-out is `HelmPrefs.signOut()`
  (drops the JWE).
- **Caption + attach: one inbound.** Compose stages the JPEG; Send emits
  one `inbound` with `text` + `images[0]`. Attach itself never sends.
- **Thread cache.** `ThreadCache` paints the last room before hydrate;
  connect `ack` `since` is the highest cached seq. Same mailbox contract
  as the PWA IndexedDB cache and Cab `ThreadCache`.
- **Header face.** 82 pt, 40×80 slot, nudge **-2 / -4**, 2 pt `line`
  stroke. Empty / Google door stay the centered hero.
- **Transcript hydrate** replays last 80 with `replay: true`.
  `shouldSpeak(kind, replay)` skips CarPlay HUNs.

---

## Lockstep

- [x] **Server-issued native nonce (Helm half).** `AuthApi.nonce()` GETs
      `/api/auth/nonce`. 404 / junk / empty → `mintNonce()`. **Do not
      require stored nonces until a Helm build that fetches them is the
      sideload** (same rule as Cab).
- [x] **4401 / handshake 401 drops the JWE.** Close `4401` and HTTP 401
      on upgrade stop retry, call `signOut()`, and hint "sign in again".
      HTTP **403** does **not** drop the session.
- [x] **`ios` / `carplay` surfaces.** Helm encodes those names.
      Pendant `Surface` must keep them (additive). Old Cab still sends
      `android` / `android_auto`.

---

## Ship / walk

- [ ] **Ship a sideload that skips CarPlay HUN on `replay`.**
      `shouldSpeak` is in `Mailbox`. Tag with the hydrating Worker.
- [ ] **Walk sibling inbound** on the deployed Worker. Fan is shipped.
      Helm paints `inbound` as you and skips HUN.

---

## Watch

- Do not send `seq` / `at` from the phone. The mailbox stamps those.
- Do not concatenate `PhoneContext` into inbound `text`. `inbound()`
  runs `stripHarnessContext`. Keep `context` JSON.
- Additive JSON is fine. A new required field or `kind` needs a Helm
  change or mailbox tolerance for the old client.
- Do not start a WKWebView to catch up the PWA.
- Do not add a cookie jar that stores `pendant_session`.
- Do not fork the Durable Object.
