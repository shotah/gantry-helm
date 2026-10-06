import Mailbox
import SwiftUI

#if canImport(PhotosUI)
  import PhotosUI
#endif

struct HelmHoldBar: View {
  @EnvironmentObject var model: HelmModel
  var colors: HelmColors
  @State private var holding = false
  @State private var aborted = false

  var body: some View {
    let speak = speakBarLabel(model.speakPhase)
    let title =
      holding
      ? holdLabel(model.hold)
      : (speak.isEmpty ? holdLabel(model.hold == .blocked ? .blocked : .idle) : speak)
    Text(title)
      .frame(maxWidth: .infinity)
      .padding(12)
      .background(Color(rgb: colors.track))
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .accessibilityLabel("Hold to talk")
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { g in
            if !holding && !aborted {
              holding = true
              model.voiceDown()
            }
            if holding && (abs(g.translation.width) > 10 || abs(g.translation.height) > 10) {
              holding = false
              aborted = true
              model.voiceCancel()
            }
          }
          .onEnded { _ in
            if holding {
              model.voiceUp()
            }
            holding = false
            aborted = false
          }
      )
  }
}

struct HelmCompose: View {
  @EnvironmentObject var model: HelmModel
  @State private var emojiOpen = false
  @State private var picking = false
  @State private var camera = false
  @FocusState private var composeFocused: Bool
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
      if model.voiceBar {
        HelmHoldBar(colors: colors)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(Color(rgb: colors.panel))
      } else {
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
              .overlay(alignment: .topTrailing) {
                if model.gpsOn {
                  Circle()
                    .fill(Color(rgb: colors.accent))
                    .frame(width: 9, height: 9)
                }
              }
          }
          .accessibilityLabel(model.gpsOn ? "Attach, GPS on" : "Attach")
          Button {
            emojiOpen.toggle()
          } label: {
            Image(systemName: "face.smiling")
              .foregroundStyle(Color(rgb: colors.fg))
              .frame(width: 36, height: 36)
          }
          .accessibilityLabel("Emoji")
          TextField("Message", text: $model.compose, axis: .vertical)
            .lineLimit(1...6)
            .textFieldStyle(.plain)
            .focused($composeFocused)
            .padding(8)
            .background(Color(rgb: colors.track))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .onChange(of: model.compose) { _, new in
              let next = applyEmoji(new, cursor: (new as NSString).length, whenTo: "type")
              if next.text != new {
                model.compose = next.text
              }
            }
          Button {
            let next = applyEmoji(
              model.compose, cursor: (model.compose as NSString).length, whenTo: "send")
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
      }
      if emojiOpen && !model.voiceBar {
        emojiPad(colors)
      }
    }
    .onAppear {
      if model.showEmoji {
        emojiOpen = true
      }
      if model.focusCompose {
        composeFocused = true
      }
    }
    .confirmationDialog("Attach", isPresented: $model.showAttach, titleVisibility: .visible) {
      Button("Photo") { picking = true }
      Button("Camera") { camera = true }
      Button("Commands") { model.compose = "/" }
      Button("GPS this send") { model.setGps(!model.gpsOn) }
      Button("Drop a pin") { model.sendPin() }
    }
    #if canImport(PhotosUI)
      .photosPicker(isPresented: $picking, selection: $picked, matching: .images)
      .onChange(of: picked) { _, item in
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

  /// Grid, a few rows tall, scrolls down. One long sideways strip hid most of it.
  private func emojiPad(_ colors: HelmColors) -> some View {
    let picks = searchEmoji("")
    return ScrollView(.vertical) {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 4)], spacing: 4) {
        ForEach(picks, id: \.name) { e in
          Button(e.emoji) { model.compose += e.emoji }
            .font(.title2)
            .frame(width: 44, height: 44)
            .accessibilityLabel(e.name)
        }
      }
      .padding(8)
    }
    .frame(height: 4 * 48 + 16)
    .background(Color(rgb: colors.track))
  }
}
