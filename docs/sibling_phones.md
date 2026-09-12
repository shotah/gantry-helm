# Sibling phones (live inbound)

Canonical design lives in the mailbox checkout:

[`gantry-pendant/docs/sibling_phones.md`](../../gantry-pendant/docs/sibling_phones.md)

This page is what that means for Helm. Same as Cab: **not** a new
mailbox, a group chat, or a Helm-side poll.

## What Helm already does (keep it)

| Piece | Why it stays |
| --- | --- |
| `inbound` paints as you (`Mouth.ingest`) | A sibling frame is the same kind as a hydrate frame |
| Dedup by `id`; `pending` waits for `ack` | The sender's own echo, and a sibling copy, share an id |
| `shouldSpeak` skips `inbound` | No CarPlay HUN / toast for your other mouth |
| `MailboxSocket.sweep` | Quiet second dial, no down state. Frozen sockets, and spike (no `sub`), still need a connect flush |

## What Helm does not do

- Do not flash Offline or clear the thread to "sync".
- Do not treat spike (`MAILBOX_SECRET`) as the same human as Google.
  Sibling live-delivery is per `sub`. Sign both mouths in with Google.

## Walk

Google on Helm and Cab (or the PWA), both sockets up, deployed origin:

1. Type in Helm — the other mouth inserts it as "you" without
   clearing the thread. Type on the other mouth — Helm does the same.
2. Bob in the same room still does not see Ada's inbound.
3. Helm sweep still runs. After the fan it is mostly "socket looks up
   but is frozen".
