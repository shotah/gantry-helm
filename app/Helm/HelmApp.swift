import SwiftUI
import Mailbox

@main
struct HelmApp: App {
  @StateObject private var model = HelmModel()

  var body: some Scene {
    WindowGroup {
      HelmRoot()
        .environmentObject(model)
        .preferredColorScheme(helmColors(model.paintedTheme).scheme == "light" ? .light : .dark)
    }
  }
}
