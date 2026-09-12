# Sideload Helm onto an iPhone

Family-beta install. App Store is not a goal.

## Once

1. Apple ID with Developer Mode (Settings → Privacy & Security →
   Developer Mode) on the phone, or a paid developer team in Xcode.
2. Mac with Xcode 15+. Open `app/Helm.xcodeproj`.
3. Signing: your team, bundle `com.gantree.helm`.
4. Bake mailbox + Google into the scheme / `.env` (same first two
   strings as Cab; iOS client is new — **no SHA-1**):

   ```
   HELM_MAILBOX_ORIGIN=https://pendant.example.com
   HELM_GOOGLE_WEB_CLIENT_ID=<pendant Web client id>
   HELM_GOOGLE_IOS_CLIENT_ID=<new iOS client>
   ```

   Fill-in walk: [setup.md](setup.md#google-production-worker).

5. Run on the device. First launch: trust the developer cert
   (Settings → General → VPN & Device Management).

Simulator is for the spike (`http://127.0.0.1:3000`). A real phone
needs the HTTPS Worker.

Uninstall to switch signing teams. Same lesson as Cab’s rotating
debug key: the identity on device is the team, not the version.

After install: [setup.md](setup.md) (Google), then
[carplay_setup.md](carplay_setup.md).
