import SwiftUI
import Mailbox
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@main
struct HelmApp: App {
  @StateObject private var model = HelmModel(sample: Self.launchSample())

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

  static func launchSample() -> String? {
    #if DEBUG
    launchSampleId(ProcessInfo.processInfo.arguments)
    #else
    nil
    #endif
  }
}

#Preview("thread") {
  HelmRoot().environmentObject(HelmModel(sample: "thread"))
}

#Preview("unsigned") {
  HelmRoot().environmentObject(HelmModel(sample: "unsigned"))
}
