import Mailbox
import SwiftUI

#if canImport(UIKit)
  import UIKit
#endif

struct HelmSettings: View {
  @EnvironmentObject var model: HelmModel
  @State private var copied = false

  var body: some View {
    let colors = helmColors(model.paintedTheme)
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("You are the operator. The name in the chat bar is the crane.")
          .font(.body)
          .foregroundStyle(Color(rgb: colors.muted))
        if !model.cranes.isEmpty {
          Text("Talking to").font(.caption).foregroundStyle(Color(rgb: colors.muted))
          ChipWrap {
            ForEach(model.cranes, id: \.self) { c in
              chip(displaySlug(c), on: c == model.slug) { model.slug = c }
            }
          }
        }
        labeled("Mailbox") {
          TextField("https://pendant.example.com", text: $model.origin)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
        Text(
          "The pendant Worker host — same site as the PWA. Cloudflare URL, or Gantree’s PENDANT_MAILBOX_URL without /ws/kit."
        )
        .font(.caption)
        .foregroundStyle(Color(rgb: colors.dim))
        labeled("Talking to") {
          TextField("kit", text: $model.slug)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .onChange(of: model.slug) { _, new in model.slug = new.lowercased() }
        }
        Text("The crane’s room, usually kit. Not your name.")
          .font(.caption)
          .foregroundStyle(Color(rgb: colors.dim))
        if model.googleReady && model.email.isEmpty {
          Button {
            HelmGoogle.signIn(webClientId: model.webClientId, origin: model.origin) { result in
              switch result {
              case .success(let session):
                model.applyGoogle(session: session)
              case .failure(let err):
                model.authHint = googleSignInHint(err)
              }
            }
          } label: {
            Text(model.signingIn ? "Opening Google…" : "Continue with Google")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .disabled(model.signingIn)
        }
        if !model.authHint.isEmpty {
          Text(model.authHint)
            .font(.caption)
            .foregroundStyle(
              model.authHint.hasPrefix("Opening") || model.authHint.hasPrefix("Signed")
                ? Color(rgb: colors.ok) : Color(rgb: colors.danger)
            )
        }
        if !model.googleReady {
          Text(
            "This build has no Google Sign-In. Use a phone secret, or rebuild with HELM_GOOGLE_WEB_CLIENT_ID."
          )
          .font(.caption)
          .foregroundStyle(Color(rgb: colors.dim))
        }
        labeled("Phone secret") {
          SecureField("MAILBOX_SECRET", text: $model.spike)
        }
        Text(
          model.googleReady
            ? "Optional. Lab MAILBOX_SECRET only — not the crane’s PENDANT_BEARER."
            : "MAILBOX_SECRET from pendant .dev.vars. Not PENDANT_BEARER (that’s Kit’s socket)."
        )
        .font(.caption)
        .foregroundStyle(Color(rgb: colors.dim))
        if model.voiceOffered {
          dropdown(
            "Language", ids: langIds, label: langLabel,
            selection: Binding(get: { model.langId }, set: { model.setLang($0) })
          )
          .accessibilityLabel("language")
          Text("What hold-to-talk hears, and the language Kit speaks back.")
            .font(.caption)
            .foregroundStyle(Color(rgb: colors.dim))
        }
        themePicker()
        dropdown("Font size", ids: fontIds, label: fontLabel, selection: $model.fontId)
        dropdown(
          "Photo size", ids: photoSizeIds, label: photoSizeChip, selection: $model.photoSizeId)
        Text("Smaller sends faster and costs fewer tokens to look at.")
          .font(.caption)
          .foregroundStyle(Color(rgb: colors.dim))
        Toggle(
          isOn: Binding(
            get: { model.gpsOn },
            set: { model.setGps($0) }
          )
        ) {
          Text("GPS this send")
        }
        Text(model.gpsOn ? geoHint(enabled: true, geo: model.prefs.lastGeo) : "GPS off")
          .font(.caption)
          .foregroundStyle(Color(rgb: colors.dim))
        Toggle("Follow Kit's mood", isOn: $model.followTheme)
        Text(
          "When on, \(displaySlug(model.slug)) picks the color theme. Off keeps the one you pick."
        )
        .font(.caption)
        .foregroundStyle(Color(rgb: colors.dim))
        Toggle(
          isOn: Binding(
            get: { model.backdropOn },
            set: { model.setBackdrop($0) }
          )
        ) {
          Text("Backdrop")
        }
        Text(
          "\(displaySlug(model.slug)) can paint a wallpaper behind the thread. Off keeps the theme."
        )
        .font(.caption)
        .foregroundStyle(Color(rgb: colors.dim))
        Text("CarPlay").font(.caption).foregroundStyle(Color(rgb: colors.muted))
        Text(
          "Helm has no tile in the car from a sideload. Kit arrives as a communication notification that CarPlay reads aloud; tap the card to reply by voice. Open Helm and send a line before you drive, then lock the phone. Plug in, then tap Test to hear a check message."
        )
        .font(.caption)
        .foregroundStyle(Color(rgb: colors.dim))
        Button("Test car voice") { model.carTest() }
          .accessibilityLabel("test car voice")
        #if DEBUG
          if HelmConfig.debug {
            Text("Samples").font(.caption).foregroundStyle(Color(rgb: colors.muted))
            ChipWrap {
              ForEach(sampleIds, id: \.self) { id in
                chip(id, on: false) {
                  model.applySample(id)
                  model.showSettings = false
                }
              }
            }
            .accessibilityLabel("debug samples")
            Text("DEBUG only. Does not persist or connect.")
              .font(.caption)
              .foregroundStyle(Color(rgb: colors.dim))
          }
        #endif
        HStack {
          Button("Connect") { model.connect() }
            .buttonStyle(.bordered)
          if !model.email.isEmpty {
            Button("Sign out") { model.signOut() }
          }
        }
        if !model.email.isEmpty {
          Text(model.email).font(.caption).foregroundStyle(Color(rgb: colors.muted))
        }
        if !model.email.isEmpty && model.cranes.isEmpty && !model.sub.isEmpty {
          Text("Not on any crane yet — give this to your yard admin")
            .font(.caption)
            .foregroundStyle(Color(rgb: colors.dim))
          Text(model.sub)
            .font(.system(.caption, design: .monospaced))
            .accessibilityLabel("google sub")
          Button(copied ? "Copied" : "Copy") {
            #if canImport(UIKit)
              UIPasteboard.general.string = allowlistCopy(email: model.email, sub: model.sub)
              copied = true
            #endif
          }
        }
      }
      .padding(24)
      .padding(.bottom, 32)
    }
    .scrollDismissesKeyboard(.interactively)
    .background(Color(rgb: colors.canvas))
    .navigationTitle("Settings")
    .onDisappear { model.persistFields() }
  }

  private func labeled(_ title: String, @ViewBuilder field: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title).font(.caption).foregroundStyle(Color(rgb: helmColors(model.paintedTheme).muted))
      field()
        .padding(8)
        .background(Color(rgb: helmColors(model.paintedTheme).track))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
  }

  /// Plain, then mood pairs. A tap is a human pick. Kit tags the room id while following.
  private func themePicker() -> some View {
    let colors = helmColors(model.paintedTheme)
    return VStack(alignment: .leading, spacing: 8) {
      Text("Theme").font(.caption).foregroundStyle(Color(rgb: colors.muted))
      ForEach(themeGroups, id: \.title) { group in
        Text(group.title)
          .font(.caption)
          .foregroundStyle(Color(rgb: colors.dim))
        ForEach(Array(group.rows.enumerated()), id: \.offset) { _, row in
          HStack(spacing: 8) {
            ForEach(row, id: \.self) { id in
              themeChip(id)
            }
          }
        }
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("color theme")
  }

  private func themeChip(_ id: String) -> some View {
    let colors = helmColors(model.paintedTheme)
    let swatch = helmColors(id)
    let on = model.themeId == id
    let kit = model.followTheme && model.roomTheme == id
    return Button {
      model.pickTheme(id)
    } label: {
      HStack(spacing: 6) {
        HStack(spacing: 0) {
          Color(rgb: swatch.canvas)
          Color(rgb: swatch.accent)
        }
        .frame(width: 14, height: 14)
        .clipShape(Circle())
        Text(themeLabel(id)).font(.caption)
        if kit {
          Text("Kit")
            .font(.caption2)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(Color(rgb: colors.accentSoft))
            .clipShape(Capsule())
        }
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(on ? Color(rgb: colors.accentSoft) : Color(rgb: colors.track))
      .foregroundStyle(Color(rgb: on ? colors.mark : colors.fg))
      .clipShape(Capsule())
      .overlay(
        Capsule().stroke(on ? Color(rgb: colors.accent) : Color(rgb: colors.line), lineWidth: 1)
      )
    }
    .accessibilityLabel(kit ? "\(themeLabel(id)), Kit" : themeLabel(id))
  }

  /// One-of-N as a menu. Chips wrapped into a sideways scroll on narrow screens.
  private func dropdown(
    _ title: String, ids: [String], label: @escaping (String) -> String,
    selection: Binding<String>
  ) -> some View {
    labeled(title) {
      Picker(title, selection: selection) {
        ForEach(ids, id: \.self) { id in
          Text(label(id)).tag(id)
        }
      }
      .pickerStyle(.menu)
      .labelsHidden()
      .tint(Color(rgb: helmColors(model.paintedTheme).fg))
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func chip(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
    let colors = helmColors(model.paintedTheme)
    return Button(action: action) {
      Text(title)
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(on ? Color(rgb: colors.accentSoft) : Color(rgb: colors.track))
        .foregroundStyle(Color(rgb: on ? colors.mark : colors.fg))
        .clipShape(Capsule())
        .overlay(
          Capsule().stroke(on ? Color(rgb: colors.accent) : Color(rgb: colors.line), lineWidth: 1)
        )
    }
  }
}

private struct ChipWrap: Layout {
  var spacing: CGFloat = 8

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let limit = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? .greatestFiniteMagnitude
    let rows = flow(maxWidth: limit, subviews: subviews)
    let natural = rows.map(\.width).max() ?? 0
    let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? natural
    let gaps = spacing * CGFloat(max(0, rows.count - 1))
    let height = rows.reduce(CGFloat(0)) { $0 + $1.height } + gaps
    return CGSize(width: width, height: height)
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let rows = flow(maxWidth: bounds.width, subviews: subviews)
    var y = bounds.minY
    var index = 0
    for row in rows {
      var x = bounds.minX
      for size in row.sizes {
        subviews[index].place(
          at: CGPoint(x: x, y: y),
          anchor: .topLeading,
          proposal: ProposedViewSize(width: size.width, height: size.height)
        )
        x += size.width + spacing
        index += 1
      }
      y += row.height + spacing
    }
  }

  private struct Row {
    var sizes: [CGSize]
    var width: CGFloat
    var height: CGFloat
  }

  private func flow(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
    var rows: [Row] = []
    var sizes: [CGSize] = []
    var rowWidth: CGFloat = 0
    var rowHeight: CGFloat = 0
    let limit = maxWidth.isFinite ? maxWidth : .greatestFiniteMagnitude
    for sub in subviews {
      let size = sub.sizeThatFits(.unspecified)
      let next = sizes.isEmpty ? size.width : rowWidth + spacing + size.width
      if !sizes.isEmpty && next > limit {
        rows.append(Row(sizes: sizes, width: rowWidth, height: rowHeight))
        sizes = [size]
        rowWidth = size.width
        rowHeight = size.height
      } else {
        sizes.append(size)
        rowWidth = next
        rowHeight = max(rowHeight, size.height)
      }
    }
    if !sizes.isEmpty {
      rows.append(Row(sizes: sizes, width: rowWidth, height: rowHeight))
    }
    return rows
  }
}
