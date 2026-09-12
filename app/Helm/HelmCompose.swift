import SwiftUI
import Mailbox

struct HelmCompose: View {
  @EnvironmentObject var model: HelmModel
  @State private var emojiOpen = false
  @State private var slashOpen = false

  var body: some View {
    let colors = helmColors(model.paintedTheme)
    VStack(alignment: .leading, spacing: 8) {
      if let photo = model.stagedPhoto {
        HStack {
          Text("Photo staged").font(.caption).foregroundStyle(Color(rgb: colors.muted))
          Button("Remove") { model.stagedPhoto = nil }
            .font(.caption)
        }
        .padding(.horizontal, 16)
      }
      let matches = matchSlash(model.compose, catalog: model.catalog)
      if !matches.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack {
            ForEach(matches, id: \.name) { cmd in
              Button {
                model.compose = slashInsert(cmd)
              } label: {
                Text("/\(cmd.name)").font(.caption)
              }
            }
          }
          .padding(.horizontal, 16)
        }
      }
      HStack(alignment: .bottom, spacing: 8) {
        Menu {
          Button("Photo") { /* PhotosPicker wired in HelmPhoto */ }
          Button("Camera") {}
          Button("Commands") { model.compose = "/" }
          Button("GPS this send") { model.gpsOn.toggle() }
          Button("Drop a pin") { model.sendPin() }
        } label: {
          Image(systemName: "paperclip")
            .foregroundStyle(Color(rgb: colors.fg))
            .frame(width: 36, height: 36)
        }
        .accessibilityLabel("Attach")
        Button {
          emojiOpen.toggle()
        } label: {
          Text("☺︎").font(.title3)
        }
        .accessibilityLabel("Emoji")
        TextField("Message", text: $model.compose, axis: .vertical)
          .lineLimit(1...6)
          .textFieldStyle(.plain)
          .padding(8)
          .background(Color(rgb: colors.track))
          .clipShape(RoundedRectangle(cornerRadius: 10))
          .onChange(of: model.compose) { new in
            let next = applyEmoji(new, cursor: (new as NSString).length, whenTo: "type")
            if next.text != new {
              model.compose = next.text
            }
          }
        Button {
          let next = applyEmoji(model.compose, cursor: (model.compose as NSString).length, whenTo: "send")
          model.compose = next.text
          model.sendText()
        } label: {
          Image(systemName: "arrow.up.circle.fill")
            .font(.title)
            .foregroundStyle(
              composeHasTurn(text: model.compose, photo: model.stagedPhoto)
                ? Color(rgb: colors.accent) : Color(rgb: colors.dim)
            )
        }
        .disabled(!composeHasTurn(text: model.compose, photo: model.stagedPhoto))
        .accessibilityLabel("Send")
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color(rgb: colors.panel))
      if emojiOpen {
        emojiPad(colors)
      }
    }
  }

  private func emojiPad(_ colors: HelmColors) -> some View {
    let picks = searchEmoji("")
    return ScrollView(.horizontal, showsIndicators: false) {
      HStack {
        ForEach(picks, id: \.name) { e in
          Button(e.emoji) { model.compose += e.emoji }
            .font(.title2)
        }
      }
      .padding(8)
    }
    .background(Color(rgb: colors.track))
  }
}
