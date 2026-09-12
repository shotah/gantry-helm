import SwiftUI
import Mailbox
#if canImport(PhotosUI)
import PhotosUI
#endif
#if canImport(UIKit)
import UIKit
#endif

struct HelmCamera: UIViewControllerRepresentable {
  var onPick: (Data?) -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(onPick: onPick)
  }

  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
    picker.delegate = context.coordinator
    picker.allowsEditing = false
    return picker
  }

  func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

  final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let onPick: (Data?) -> Void

    init(onPick: @escaping (Data?) -> Void) {
      self.onPick = onPick
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
      onPick(nil)
    }

    func imagePickerController(
      _ picker: UIImagePickerController,
      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
      let image = (info[.originalImage] as? UIImage)
      onPick(image?.jpegData(compressionQuality: 0.9))
    }
  }
}
