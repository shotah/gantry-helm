import Mailbox
import SwiftUI

#if canImport(GoogleSignIn)
  import GoogleSignIn
#endif

@main
struct HelmApp: App {
  @StateObject private var model = Self.makeModel()

  var body: some Scene {
    WindowGroup {
      HelmRoot()
        .environmentObject(model)
        .preferredColorScheme(helmColors(model.paintedTheme).scheme == "light" ? .light : .dark)
        .onOpenURL { url in
          HelmGoogle.handle(url)
        }
    }
  }

  static func makeModel() -> HelmModel {
    #if DEBUG
      let args = ProcessInfo.processInfo.arguments
      if let shot = launchDocShot(args) {
        return HelmModel(sample: shot.sample, theme: shot.theme, open: shot.open)
      }
      return HelmModel(sample: launchSampleId(args))
    #else
      return HelmModel()
    #endif
  }
}

#Preview("thread") {
  HelmRoot().environmentObject(HelmModel(sample: "thread"))
}

#Preview("unsigned") {
  HelmRoot().environmentObject(HelmModel(sample: "unsigned"))
}
