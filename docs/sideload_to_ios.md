# Phone install

From a Helm checkout to a working app on an iPhone. Family sideload.
The App Store is not the product.

`make ios` compiles an unsigned Simulator app. A phone install is a
signed **Run** from Xcode, after `.env` is baked in.

## 1. Xcode

Install the Xcode app. Command Line Tools are not enough to sign or
install.

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -version
```

`xcode-select -p` should end in `Xcode.app/Contents/Developer`. If the
app lives somewhere else, pass that `Contents/Developer` path. When
two Xcode apps are on disk, select the one you open to Run.

## 2. Compile

From this checkout:

```bash
make ios
```

`** BUILD SUCCEEDED **` means the Simulator target compiled. The
`.app` from that command stays on the Mac.

## 3. `.env`, then bake

```bash
cp .env.example .env
```

A phone needs the HTTPS Worker, the same host Cab already uses.
`http://127.0.0.1:3000` is the Simulator talking to a dev Worker on
the Mac.

```bash
HELM_MAILBOX_ORIGIN=https://pendant.example.com
HELM_GOOGLE_WEB_CLIENT_ID=<pendant Web client id>
HELM_GOOGLE_IOS_CLIENT_ID=<new iOS client>
```

The first two strings are Cab’s `CAB_MAILBOX_ORIGIN` and
`CAB_GOOGLE_WEB_CLIENT_ID`. The iOS client is new: Google Cloud →
Credentials → OAuth client ID → **iOS**, bundle `com.gantree.helm`.
No SHA-1. No redirect URI. The click-path is
[setup.md](setup.md#google-production-worker).

```bash
make bake
```

That writes gitignored `app/Helm.local.xcconfig`. The reversed iOS
URL scheme is derived from `HELM_GOOGLE_IOS_CLIENT_ID`. Leave `.env`
and that xcconfig out of git.

## 4. Phone settings

1. **Settings → Privacy & Security → Developer Mode** → on. Restart
   when the phone asks.
2. Plug in the cable. Unlock. Tap **Trust This Computer**.

## 5. Run on the phone

1. Open `app/Helm.xcodeproj`.
2. The Helm target → **Signing & Capabilities**. Team is your Apple
   ID. **Automatically manage signing** stays on. Bundle id stays
   `com.gantree.helm`.
3. A free Apple ID is enough. That profile lasts about seven days;
   Run again from Xcode when it expires.
4. The destination is your iPhone, not a Simulator.
5. Press Run.

Xcode registers the phone with your Apple ID on that Run.

## 6. Trust the cert, then open Helm

The first launch waits on **Settings → General → VPN & Device
Management**. Open the developer profile and tap Trust. Then open
Helm.

Settings shows the baked mailbox and **Talking to** (the room, usually
`kit`). **Continue with Google**. The bar should say **Live**.

A failed `GET /api/auth/nonce` stops sign-in and leaves Google
closed. Check the Worker URL, then Run again after `make bake` if you
changed `.env`.

Google on this phone and on Cab (same account) is how a line typed
on one mouth shows up as you on the other. A spike secret is the lab
socket; sibling delivery follows the Google `sub`.

Uninstall Helm before switching signing teams. The identity on the
phone is the team.

Car, after the thread is Live: [carplay_setup.md](carplay_setup.md).
