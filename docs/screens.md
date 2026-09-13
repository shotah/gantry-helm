# Screens

What the mouth looks like. Reshoot when `make shot` exists. The
SwiftUI shell is in `app/Helm` — same Ada/Kit copy, same Boom /
Lamp / Paper as Cab.

Boom is the default mood; Lamp and Paper are the other two README
themes. The rest of the catalog lives in Settings (`Look.themeIds`).

Samples are canned Ada/Kit turns — not a live crane. Release builds
ignore a `sample` launch argument.

---

## Phone

| Shot | Sample | What it is |
| --- | --- | --- |
| `phone-unsigned` | `unsigned` | Google door. Avatar + cog. |
| `phone-empty` | `empty` | Live, nothing said yet. |
| `phone-thread` | `thread` | Ada ↔ Kit. Boom. |
| `phone-stream` | `stream` | Draft bubble + `Live · typing…`. |
| `phone-photo` | `photo` | Hatch photo in a you-bubble. |
| `phone-down` | `down` | Socket down; local echo still `sending`. |
| `phone-settings` | `empty` | Settings: origin, slug, theme catalog, font, photo size, follow Kit, backdrop, Test car voice. DEBUG builds also chip `sampleIds`. |
| `phone-emoji` | `thread` | Emoji picker over compose. |
| `phone-attach` | `thread` | Paperclip: photo, camera, commands, GPS, pin. |
| `phone-draft` | `thread` | Staged photo on compose: thumbnail + Remove; Send carries caption + JPEG. |
| `phone-thread-lamp` | `thread` | Same thread, Lamp. |
| `phone-thread-paper` | `thread` | Same thread, Paper (daylight). |

## CarPlay

Later. List + conversation stand-in. Voice is CarPlay host STT, not
Siri as a second mailbox.

| Shot | Sample | What it is |
| --- | --- | --- |
| `car-empty` | `empty` | CarPlay list, empty. |
| `car-thread` | `thread` | CarPlay list, last six turns. |

PNGs land in `assets/docs/` once the paint path exists. Cab's
current shots are the look to match:
[gantry-cab `docs/screens.md`](https://github.com/shotah/gantry-cab/blob/main/docs/screens.md).
