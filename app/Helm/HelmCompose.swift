import SwiftUI
import Mailbox
#if canImport(PhotosUI)
import PhotosUI
#endif

struct HelmCompose: View {
  @EnvironmentObject var model: HelmModel
  @State private var emojiOpen = false
  @State private var picking = false
  @State private var camera = false
  #if canImport(PhotosUI)
  @State private var picked: PhotosPickerItem?
  #endif

  var body: some View {
    let colors = helmColors(model.paintedTheme)
    VStack(alignment: .leading, spacing: 8) {
      if let photo = model.stagedPhoto {
        HStack(spacing: 8) {
          if let data = decodeDataUrl(photo), let img = helmImage(data) {
            img.resizable().scaledToFill()
              .frame(width: 48, height: 48)
              .clipShape(RoundedRectangle(cornerRadius: 8))
          }
          Text("Photo staged").font(.caption).foregroundStyle(Color(rgb: colors.muted))
          Button("Remove") { model.stagedPhoto = nil }
            .font(.caption)
        }
        .padding(.horizontal, 16)
        .accessibilityLabel("Staged photo")
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
          Button("Photo") { picking = true }
          Button("Camera") { camera = true }
          Button("Commands") { model.compose = "/" }
          Button("GPS this send") { model.setGps(!model.gpsOn) }
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
    #if canImport(PhotosUI)
    .photosPicker(isPresented: $picking, selection: $picked, matching: .images)
    .onChange(of: picked) { item in
      guard let item else { return }
      Task {
        if let data = try? await item.loadTransferable(type: Data.self) {
          await MainActor.run { model.stagePhoto(data: data) }
        }
        await MainActor.run { picked = nil }
      }
    }
    #endif
    .sheet(isPresented: $camera) {
      HelmCamera { data in
        camera = false
        if let data {
          model.stagePhoto(data: data)
        }
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
