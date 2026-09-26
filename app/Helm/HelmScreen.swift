import SwiftUI
import Mailbox
#if canImport(UIKit)
import UIKit
#endif

struct HelmRoot: View {
  @EnvironmentObject var model: HelmModel
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    let colors = helmColors(model.paintedTheme)
    NavigationStack {
      HelmScreen()
        .navigationDestination(isPresented: $model.showSettings) {
          HelmSettings()
        }
    }
    .tint(Color(rgb: colors.accent))
    .onChange(of: scenePhase) { phase in
      model.setResumed(phase == .active)
    }
    .sheet(isPresented: $model.showGoals, onDismiss: {
      model.markAimsSeen()
    }) {
      HelmGoals()
        .environmentObject(model)
        .onAppear { model.markAimsSeen() }
    }
  }
}

struct HelmScreen: View {
  @EnvironmentObject var model: HelmModel

  var body: some View {
    let colors = helmColors(model.paintedTheme)
    let name = displaySlug(model.slug)
    ZStack(alignment: .topLeading) {
      Color(rgb: colors.canvas).ignoresSafeArea()
      if model.backdropOn, let data = model.backdropJpeg, let img = helmImage(data) {
        img.resizable().scaledToFill().opacity(0.35).ignoresSafeArea()
      }
      VStack(spacing: 0) {
        HStack(spacing: 0) {
          Color.clear
            .frame(width: headerFaceSlotWidth, height: headerFaceSlotHeight)
          VStack(alignment: .leading, spacing: 2) {
            Text(name)
              .font(.headline)
              .foregroundStyle(Color(rgb: colors.fg))
            TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
              Text(statusLine(now: timeline.date))
                .font(.caption)
                .foregroundStyle(Color(rgb: colors.muted))
            }
          }
          Spacer()
          if model.voiceOffered {
            Button {
              model.toggleVoice()
            } label: {
              Image(systemName: model.voiceOn ? "mic.fill" : "mic")
                .foregroundStyle(Color(rgb: colors.fg))
            }
            .accessibilityLabel(model.voiceOn ? "Voice on" : "Voice")
          }
          if !model.aims.isEmpty {
            Button {
              model.showGoals = true
            } label: {
              Image(systemName: "scope")
                .foregroundStyle(Color(rgb: colors.fg))
                .overlay(alignment: .topTrailing) {
                  if model.goalsChanged > 0 {
                    Text("\(model.goalsChanged)")
                      .font(.caption2)
                      .padding(3)
                      .background(Color(rgb: colors.accent))
                      .clipShape(Circle())
                      .offset(x: 8, y: -8)
                  }
                }
            }
            .accessibilityLabel(goalsLabel(model.goalsChanged))
          }
          Button {
            model.showSettings = true
          } label: {
            Image(systemName: "gearshape")
              .foregroundStyle(Color(rgb: colors.fg))
          }
          .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(rgb: colors.panel))
        HelmChat()
        HelmCompose()
      }
      KitFace(jpeg: model.faceJpeg, rev: model.avatarRev)
        .frame(width: headerFaceSize, height: headerFaceSize)
        .offset(x: 8 + headerFaceNudgeX, y: headerFaceNudgeY)
        .zIndex(2)
    }
    .onAppear {
      HelmNotify.setup()
      if !model.sampleShown && model.mouth.lines.isEmpty && !model.bearer.isEmpty {
        model.connect()
      }
    }
  }

  private func statusLine(now: Date) -> String {
    threadStatusLine(
      up: model.up,
      hint: model.hint,
      typingUntil: model.typingUntil,
      nowMs: Int64(now.timeIntervalSince1970 * 1000),
      speak: model.speakPhase
    )
  }
}

struct KitFace: View {
  var jpeg: Data?
  var rev: Int
  var body: some View {
    let colors = helmColors("boom")
    Circle()
      .fill(Color(rgb: colors.track))
      .overlay {
        if let jpeg, let img = helmImage(jpeg) {
          img.resizable().scaledToFill()
        } else {
          Text(rev > 0 ? "" : "K")
            .font(.title2.weight(.semibold))
            .foregroundStyle(Color(rgb: colors.mark))
        }
      }
      .overlay(
        Circle().stroke(Color(rgb: colors.line), lineWidth: headerFaceStroke)
      )
      .clipShape(Circle())
      .accessibilityLabel("Kit")
  }
}

func helmImage(_ data: Data) -> Image? {
  #if canImport(UIKit)
  if let ui = UIImage(data: data) {
    return Image(uiImage: ui)
  }
  #endif
  return nil
}

struct HelmChat: View {
  @EnvironmentObject var model: HelmModel

  var body: some View {
    let colors = helmColors(model.paintedTheme)
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 8) {
          ForEach(model.lines, id: \.id) { line in
            bubble(line, colors: colors)
              .id(composeKey(line))
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
      }
      .onChange(of: model.lines.count) { _ in
        if let last = model.lines.last {
          proxy.scrollTo(composeKey(last), anchor: .bottom)
        }
      }
    }
  }

  @ViewBuilder
  private func bubble(_ line: ChatLine, colors: HelmColors) -> some View {
    HStack {
      if line.fromYou { Spacer(minLength: 48) }
      VStack(alignment: line.fromYou ? .trailing : .leading, spacing: 4) {
        if !line.text.isEmpty {
          Text(line.text)
            .font(.system(size: CGFloat(chatSp(model.fontId))))
            .foregroundStyle(Color(rgb: colors.fg))
            .padding(10)
            .background(Color(rgb: line.fromYou ? colors.you : colors.kit))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        if let photo = line.photo, let data = decodeDataUrl(photo), let img = helmImage(data) {
          img.resizable().scaledToFit().frame(maxWidth: 220).clipShape(RoundedRectangle(cornerRadius: 10))
        }
        if let reaction = line.reaction, !reaction.isEmpty {
          Text(reaction).font(.caption)
        }
        if line.pending {
          Text("sending").font(.caption2).foregroundStyle(Color(rgb: colors.dim))
        }
        if let failed = line.failed {
          Text(failed).font(.caption2).foregroundStyle(Color(rgb: colors.danger))
        }
      }
      if !line.fromYou { Spacer(minLength: 48) }
    }
    .contextMenu {
      if canReact(fromYou: line.fromYou, kind: line.kind, id: line.id) {
        ForEach(reactionPalette, id: \.self) { emoji in
          Button(emoji) {
            model.react(id: line.id, emoji: toggleReaction(line.reaction, emoji))
          }
        }
      }
    }
  }

}
