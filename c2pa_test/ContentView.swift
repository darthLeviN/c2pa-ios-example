import SwiftUI
import SimpleC2PA
import UniformTypeIdentifiers
import UIKit


struct ContentView: View {
    @ObservedObject var config = Config()
    @State private var statusMessage = "Press the button to start"
    @State private var selectedFilePath: URL?
    @State private var selectedImage: UIImage?

    var body: some View {
        VStack {
            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 300)
            } else {
                Color
                    .clear
                    .frame(width: 300, height: 300)
            }
            
            Text("Selected source file \n: \(selectedFilePath?.absoluteString ?? "No file selected")")
                .padding()
            
            Text(statusMessage)
                .padding()
            
            Button(action: {
                Task {
                    self.selectedFilePath = await selectImage() ?? self.selectedFilePath
                }
            }) {
                Text("Select an image")
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 10))
            
            Button(action: {
                Task {
                    self.selectedFilePath = await createTempImage()
                }
            }) {
                Text("Create temp image")
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 10))
            
            Button(action: {
                if let targetFile = self.selectedFilePath {
                    Task {
                        await addManifest(forFile: targetFile)
                    }
                }
            }) {
                Text("Add metadata")
            }
            .disabled(self.selectedFilePath == nil)
            .padding()
            .background(RoundedRectangle(cornerRadius: 10))
        }
        .onChange(of: selectedFilePath) {
            if let selectedFilePath {
                self.selectedImage = UIImage(contentsOfFile: selectedFilePath.path)
            } else {
                self.selectedImage = nil
            }
        }
    }
    
    func selectImage() async -> URL? {
        let imageSelector = ImageSelector()
        
        await imageSelector.selectImage()
        
        return imageSelector.selectedImageUrl
    }
    
    
    func addManifest(forFile: URL) async {
        do {
            let rootCert = try await Task(priority: .userInitiated) {
                try createRootCertificate(organization: nil, validityDays: nil)
            }.value
            
            let contentCert = try await Task(priority: .userInitiated) {
                try createContentCredentialsCertificate(rootCertificate: rootCert, organization: nil, validityDays: nil)
            }.value
            
            let fileData = FileData(path: forFile.path, bytes: nil, fileName: forFile.lastPathComponent)
            let cc = ContentCredentials(certificate: contentCert, file: fileData, applicationInfo: nil)
            
            try await Task(priority: .userInitiated) {
                try cc.addCreatedAssertion()
            }.value
            
            await MainActor.run {
                statusMessage = "Metadata added successfully"
            }
            
            let folderSelector = FolderSelector()
            await folderSelector.selectFolder()
            print("Selected folder: \(folderSelector.outputUrl?.path ?? "None")")
            if let outputUrl = folderSelector.outputUrl {
                _ = try cc.embedManifest(outputPath: outputUrl.path()+"signed_"+forFile.lastPathComponent)
            }
        } catch {
            await MainActor.run {
                statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }
    
    @MainActor
    func createTempImage() async -> URL?  {
        do {
            
            let imagePath = try! createTestImageFile()
            let tempOutputPath = FileManager.default.temporaryDirectory.appendingPathComponent("output_image.jpg")
            let imageURL = URL(fileURLWithPath: imagePath)
            if let imageData = try? Data(contentsOf: imageURL) {
                try imageData.write(to: tempOutputPath)
                await MainActor.run {
                    statusMessage = "Temp image created successfully"
                }
            } else {
                await MainActor.run {
                    statusMessage = "Error: Failed to load image data"
                }
            }
            
            return tempOutputPath
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
        }
        
        return nil
    }
    
    func createTestImageFile() throws -> String {
        let imageSize = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        let image = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(origin: .zero, size: imageSize))
        }
        
        let imageData = image.jpegData(compressionQuality: 1.0)
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_image.jpg")
        try imageData?.write(to: fileURL)
        
        return fileURL.path
    }
}
