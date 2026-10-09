import Mailbox
import SwiftUI

#if canImport(PhotosUI)
  import PhotosUI
#endif
#if canImport(UIKit)
  import UIKit
#endif

/// Tap the header face → this, not the photo picker. The face large, the
/// crane's name, then Copy / Share / Replace. Copy and Share only when the
/// room has set a face; the bundled default is Replace alone.
struct HelmAvatar: View {
  @EnvironmentObject var model: HelmModel

  var body: some View {
    let colors = helmColors(model.paintedTheme)
    let actions = avatarSheetActions(hasFace: model.faceJpeg != nil)
    VStack(spacing: 16) {
      KitFace(jpeg: model.faceJpeg, rev: model.avatarRev)
        .frame(width: avatarSheetFaceSize, height: avatarSheetFaceSize)
      Text(displaySlug(model.slug))
        .font(.title2)
        .foregroundStyle(Color(rgb: colors.fg))
      HStack(spacing: 12) {
        ForEach(actions, id: \.self) { action in
          Button(label(action)) { model.avatarAct(action) }
            .buttonStyle(.bordered)
            .accessibilityLabel(label(action))
        }
      }
      .padding(.top, 8)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(rgb: colors.canvas))
    .presentationDetents([.medium])
  }

  private func label(_ action: AvatarAction) -> String {
    action == .copy ? avatarCopyLabel(copied: model.faceCopied) : action.label
  }
}

/// Share and Replace run after the avatar sheet is gone: the system share
/// sheet over the JPEG, or the photo picker whose pick POSTs the new face.
struct HelmAvatarFollowUp: ViewModifier {
  @EnvironmentObject var model: HelmModel
  #if canImport(PhotosUI)
    @State private var picked: PhotosPickerItem?
  #endif

  func body(content: Content) -> some View {
    content
      .sheet(isPresented: $model.shareFace) {
        if let jpeg = model.faceJpeg {
          HelmShare(jpeg: jpeg)
        }
      }
      #if canImport(PhotosUI)
        .photosPicker(isPresented: $model.pickFace, selection: $picked, matching: .images)
        .onChange(of: picked) { _, item in
          guard let item else { return }
          Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
              await MainActor.run { model.replaceFace(data: data) }
            }
            await MainActor.run { picked = nil }
          }
        }
      #endif
  }
}

/// System share sheet over the face JPEG.
struct HelmShare: UIViewControllerRepresentable {
  var jpeg: Data

  func makeUIViewController(context: Context) -> UIActivityViewController {
    let items: [Any] = UIImage(data: jpeg).map { [$0] } ?? [jpeg]
    return UIActivityViewController(activityItems: items, applicationActivities: nil)
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
