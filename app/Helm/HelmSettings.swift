import SwiftUI
import Mailbox
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
          ScrollView(.horizontal, showsIndicators: false) {
            HStack {
              ForEach(model.cranes, id: \.self) { c in
                chip(displaySlug(c), on: c == model.slug) { model.slug = c }
              }
            }
          }
        }
        labeled("Mailbox") {
          TextField("https://pendant.example.com", text: $model.origin)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        }
        Text("The pendant Worker host — same site as the PWA. Cloudflare URL, or Gantree’s PENDANT_MAILBOX_URL without /ws/kit.")
          .font(.caption)
          .foregroundStyle(Color(rgb: colors.dim))
        labeled("Talking to") {
          TextField("kit", text: $model.slug)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .onChange(of: model.slug) { model.slug = $0.lowercased() }
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
          Text("This build has no Google Sign-In. Use a phone secret, or rebuild with HELM_GOOGLE_WEB_CLIENT_ID.")
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
        Text("Theme").font(.caption).foregroundStyle(Color(rgb: colors.muted))
        ScrollView(.horizontal, showsIndicators: false) {
          HStack {
            ForEach(themeIds, id: \.self) { id in
              chip(themeLabel(id), on: id == model.themeId) { model.pickTheme(id) }
            }
          }
        }
        .accessibilityLabel("color theme")
        Text("Font size").font(.caption).foregroundStyle(Color(rgb: colors.muted))
        ScrollView(.horizontal, showsIndicators: false) {
          HStack {
            ForEach(fontIds, id: \.self) { id in
              chip(fontLabel(id), on: id == model.fontId) { model.fontId = id }
            }
          }
        }
        Text("Photo size").font(.caption).foregroundStyle(Color(rgb: colors.muted))
        ScrollView(.horizontal, showsIndicators: false) {
          HStack {
            ForEach(photoSizeIds, id: \.self) { id in
              chip(photoSizeChip(id), on: id == model.photoSizeId) { model.photoSizeId = id }
            }
          }
        }
        Text("Smaller sends faster and costs fewer tokens to look at.")
          .font(.caption)
          .foregroundStyle(Color(rgb: colors.dim))
        Toggle("Follow Kit's mood", isOn: $model.followTheme)
        Text("When on, \(displaySlug(model.slug)) picks the color theme. Off keeps the one you pick.")
          .font(.caption)
          .foregroundStyle(Color(rgb: colors.dim))
        Toggle(isOn: Binding(
          get: { model.backdropOn },
          set: { model.setBackdrop($0) }
        )) {
          Text("Backdrop")
        }
        Text("\(displaySlug(model.slug)) can paint a wallpaper behind the thread. Off keeps the theme.")
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
    .background(Color(rgb: helmColors(model.paintedTheme).canvas))
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
