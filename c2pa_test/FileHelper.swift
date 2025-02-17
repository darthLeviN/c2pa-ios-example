import Foundation
import UniformTypeIdentifiers
import UIKit

import UniformTypeIdentifiers

class FolderSelector {
    var outputUrl: URL?
    
    @MainActor
    func selectFolder() async {
        let fileHelper = FileManagerHelper()
        let selectedFolder = await fileHelper.requestFolderSelection()
        self.outputUrl = selectedFolder
    }
}

class ImageSelector {
    var selectedImageUrl: URL?
    
    @MainActor
    func selectImage() async {
        let fileHelper = FileManagerHelper()
        let selectedImage = await fileHelper.requestImageSelection()
        self.selectedImageUrl = selectedImage
    }
}

class FileManagerHelper: NSObject, UIDocumentPickerDelegate {
    private var continuation: CheckedContinuation<URL?, Never>?

    @MainActor
    func requestFolderSelection() async -> URL? {
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.folder])
            picker.delegate = self
            picker.allowsMultipleSelection = false
            presentPicker(picker)
        }
    }
    
    @MainActor
    func requestImageSelection() async -> URL? {
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.image])
            picker.delegate = self
            picker.allowsMultipleSelection = false
            presentPicker(picker)
        }
    }

    private func presentPicker(_ picker: UIDocumentPickerViewController) {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(picker, animated: true)
        }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        continuation?.resume(returning: urls.first)
        continuation = nil
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        continuation?.resume(returning: nil)
        continuation = nil
    }
}
