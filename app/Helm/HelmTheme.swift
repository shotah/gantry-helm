import SwiftUI
import Mailbox

extension Color {
  init(rgb: UInt32) {
    let r = Double((rgb >> 16) & 0xFF) / 255
    let g = Double((rgb >> 8) & 0xFF) / 255
    let b = Double(rgb & 0xFF) / 255
    self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
  }
}
