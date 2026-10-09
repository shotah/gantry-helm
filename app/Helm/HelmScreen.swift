import Mailbox
import SwiftUI

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
    .onChange(of: scenePhase) { _, phase in
      model.setResumed(phase == .active)
    }
    .sheet(
      isPresented: $model.showGoals,
      onDismiss: {
        model.markAimsSeen()
      },
      content: {
        HelmGoals()
          .environmentObject(model)
          .onAppear { model.markAimsSeen() }
      }
    )
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
        // Overlay + clip: a bare scaledToFill image reports its overflow as
        // its size, grows the ZStack past the screen, and the parent centers
        // it — pushing the header and compose bar off the edges, worst with a
        // keyboard up or on an iPad whose aspect differs from the photo.
        Color.clear
          .overlay { img.resizable().scaledToFill() }
          .clipped()
          .opacity(0.35)
          .ignoresSafeArea()
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
          Spacer(minLength: 8)
          HStack(spacing: 8) {
            if model.voiceOffered {
              headerIcon(
                model.voiceOn ? "mic.fill" : "mic",
                label: model.voiceOn ? "Voice on" : "Voice"
              ) {
                model.toggleVoice()
              }
            }
            if !model.todo.isEmpty {
              headerIcon(
                "checkmark.square",
                label: tasksLabel(model.tasksChanged),
                badge: model.tasksChanged
              ) {
                model.showTasks = true
              }
            }
            if !model.aims.isEmpty {
              headerIcon(
                "scope",
                label: goalsLabel(model.goalsChanged),
                badge: model.goalsChanged
              ) {
                model.showGoals = true
              }
            }
            headerIcon("gearshape", label: "Settings") {
              model.showSettings = true
            }
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(rgb: colors.panel))
        .layoutPriority(1)
        HelmChat()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        HelmCompose()
      }
      Button {
        model.showAvatar = true
      } label: {
        KitFace(jpeg: model.faceJpeg, rev: model.avatarRev)
          .frame(width: headerFaceSize, height: headerFaceSize)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Kit's face")
      .offset(x: 8 + headerFaceNudgeX, y: headerFaceNudgeY)
      .zIndex(2)
    }
    .onAppear {
      if !model.sampleShown {
        HelmNotify.setup()
      }
      if !model.sampleShown && model.mouth.lines.isEmpty && !model.bearer.isEmpty {
        model.connect()
      }
    }
    .sheet(
      isPresented: $model.showTasks,
      onDismiss: {
        model.markTodoSeen()
      },
      content: {
        HelmTasks()
          .environmentObject(model)
          .onAppear { model.markTodoSeen() }
      }
    )
    .sheet(
      isPresented: $model.showAvatar,
      onDismiss: {
        model.avatarDismissed()
      },
      content: {
        HelmAvatar()
          .environmentObject(model)
      }
    )
    .modifier(HelmAvatarFollowUp())
  }

  private func headerIcon(
    _ systemName: String,
    label: String,
    badge: Int = 0,
    action: @escaping () -> Void
  ) -> some View {
    let colors = helmColors(model.paintedTheme)
    return Button(action: action) {
      Image(systemName: systemName)
        .font(.body)
        .foregroundStyle(Color(rgb: colors.fg))
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .overlay(alignment: .topTrailing) {
          if badge > 0 {
            Text("\(badge)")
              .font(.caption2)
              .padding(3)
              .background(Color(rgb: colors.accent))
              .clipShape(Circle())
              .offset(x: -4, y: 4)
          }
        }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label)
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

private let chatTailID = "helm-chat-tail"

struct HelmChat: View {
  @EnvironmentObject var model: HelmModel

  /// Count plus the latest bubble. Text edits of that bubble do not count, so a
  /// scroll up into history stays put until a new line arrives.
  private var pinToken: String {
    guard let last = model.lines.last else {
      return ""
    }
    return "\(model.lines.count)\n\(composeKey(last))"
  }

  var body: some View {
    let colors = helmColors(model.paintedTheme)
    ScrollViewReader { proxy in
      ScrollView {
        // Newest first. The scroll view is flipped, so this end sits on screen
        // at the bottom without waiting for a scroll-to that the lazy stack never built.
        LazyVStack(alignment: .leading, spacing: 8) {
          Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: 1)
            .id(chatTailID)
          ForEach(Array(model.lines.reversed()), id: \.id) { line in
            bubble(line, colors: colors)
              .id(composeKey(line))
              .scaleEffect(y: -1)
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
      }
      .scrollDismissesKeyboard(.interactively)
      .scaleEffect(y: -1)
      .onChange(of: pinToken) { _, token in
        guard !token.isEmpty else {
          return
        }
        pin(proxy)
      }
    }
  }

  private func pin(_ proxy: ScrollViewProxy) {
    proxy.scrollTo(chatTailID, anchor: .top)
    DispatchQueue.main.async {
      proxy.scrollTo(chatTailID, anchor: .top)
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
          img.resizable().scaledToFit().frame(maxWidth: 220).clipShape(
            RoundedRectangle(cornerRadius: 10))
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
        if model.reactingId == line.id {
          bubbleMenu(line, colors: colors)
        }
      }
      if !line.fromYou { Spacer(minLength: 48) }
    }
    .contentShape(Rectangle())
    // A tap handler ahead of the long press keeps the scroll view scrolling.
    .onTapGesture {
      model.reactingId = nil
    }
    .onLongPressGesture {
      if canHold(fromYou: line.fromYou, kind: line.kind, id: line.id, text: line.text, up: model.up)
      {
        model.reactingId = line.id
      }
    }
  }

  /// Inline menu, no context-menu lift: that preview snapshots the flipped
  /// bubble and shows it upside down. Copy text first on any bubble with
  /// words; the emoji rows under it only on Kit's live `reply` / `push`.
  private func bubbleMenu(_ line: ChatLine, colors: HelmColors) -> some View {
    VStack(spacing: 4) {
      if canCopy(line.text) {
        Button {
          model.copyText(line.text)
        } label: {
          Label(copyTextLabel, systemImage: "doc.on.doc")
            .font(.callout)
            .foregroundStyle(Color(rgb: colors.fg))
            .frame(maxWidth: .infinity, minHeight: 40)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(copyTextLabel)
      }
      if showsReactions(fromYou: line.fromYou, kind: line.kind, id: line.id, up: model.up) {
        reactionRowsView(line, colors: colors)
      }
    }
    .padding(6)
    .background(Color(rgb: colors.panel))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(rgb: colors.line), lineWidth: 1))
    .accessibilityLabel("Bubble menu")
  }

  private func reactionRowsView(_ line: ChatLine, colors: HelmColors) -> some View {
    VStack(spacing: 4) {
      ForEach(reactionRows(reactionPalette), id: \.self) { row in
        HStack(spacing: 4) {
          ForEach(row, id: \.self) { emoji in
            Button {
              model.react(id: line.id, emoji: toggleReaction(line.reaction, emoji))
            } label: {
              Text(emoji)
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(
                  line.reaction == emoji ? Color(rgb: colors.accentSoft) : .clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("React \(emoji)")
          }
        }
      }
    }
    .accessibilityLabel("Reactions")
  }
}
