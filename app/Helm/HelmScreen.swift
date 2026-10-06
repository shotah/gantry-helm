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
    GeometryReader { geo in
      NavigationStack {
        HelmScreen()
          .navigationDestination(isPresented: $model.showSettings) {
            HelmSettings()
          }
      }
      .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
    }
    .ignoresSafeArea(.keyboard)
    .background {
      ScreenPin()
        .allowsHitTesting(false)
    }
    .tint(Color(rgb: colors.accent))
    .onChange(of: scenePhase) { phase in
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
      KitFace(jpeg: model.faceJpeg, rev: model.avatarRev)
        .frame(width: headerFaceSize, height: headerFaceSize)
        .offset(x: 8 + headerFaceNudgeX, y: headerFaceNudgeY)
        .zIndex(2)
    }
    .modifier(KeyboardOverlap(cover: Color(rgb: colors.panel)))
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

#if canImport(UIKit)
  /// UIKit slides the hosting view up with the keyboard and can leave that
  /// offset in place after dismiss. Put the full-width ancestors back.
  private struct ScreenPin: UIViewRepresentable {
    func makeUIView(context: Context) -> PinView { PinView() }

    func updateUIView(_ uiView: PinView, context: Context) {
      uiView.pin()
    }

    final class PinView: UIView {
      private var token: NSObjectProtocol?
      private var pinning = false

      override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        token = NotificationCenter.default.addObserver(
          forName: UIResponder.keyboardWillChangeFrameNotification,
          object: nil,
          queue: .main
        ) { [weak self] _ in
          self?.pin()
        }
      }

      required init?(coder: NSCoder) {
        nil
      }

      deinit {
        if let token {
          NotificationCenter.default.removeObserver(token)
        }
      }

      override func didMoveToWindow() {
        super.didMoveToWindow()
        pin()
      }

      override func layoutSubviews() {
        super.layoutSubviews()
        pin()
      }

      func pin() {
        guard let window, let root = window.rootViewController?.view, !pinning else {
          return
        }
        pinning = true
        defer { pinning = false }
        straighten(root, window: window)
      }

      private func straighten(_ view: UIView, window: UIWindow) {
        if view.transform != .identity {
          view.transform = .identity
        }
        let size = view.bounds.size
        let fullWidth = abs(size.width - window.bounds.width) < 2
        let tall = size.height > window.bounds.height * 0.45
        if fullWidth && tall, let host = view.superview {
          let origin = host.convert(view.frame.origin, to: window)
          if origin.y < -1 {
            var frame = view.frame
            frame.origin.y -= origin.y
            frame.origin.x = 0
            view.frame = frame
            if let scroll = view as? UIScrollView, scroll.contentOffset.y > 1 {
              scroll.contentOffset = .zero
            }
          }
        }
        for child in view.subviews {
          straighten(child, window: window)
        }
      }
    }
  }
#endif

struct KeyboardOverlap: ViewModifier {
  var cover: Color
  @State private var lift: CGFloat = 0

  func body(content: Content) -> some View {
    content
      .padding(.bottom, lift)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .background(alignment: .bottom) {
        cover.frame(maxWidth: .infinity).frame(height: lift)
      }
      .onReceive(
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
      ) { note in
        let next = Self.lift(for: note)
        guard next != lift else {
          return
        }
        let duration =
          note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        withAnimation(.easeOut(duration: duration)) {
          lift = next
        }
      }
  }

  private static func lift(for note: Notification) -> CGFloat {
    #if canImport(UIKit)
      guard let end = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
        return 0
      }
      let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first {
        $0.activationState == .foregroundActive
      }
      let bottom = scene?.screen.bounds.maxY ?? end.maxY
      let home = scene?.keyWindow?.safeAreaInsets.bottom ?? 0
      return max(0, bottom - end.minY - home)
    #else
      return 0
    #endif
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
