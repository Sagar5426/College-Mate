
//
//  MainFileView.swift
//  College Mate
//
//  Created by Sagar Jangra on 16/01/2025.
//

import SwiftUI
import MobileCoreServices
import PDFKit
import UniformTypeIdentifiers

// MARK: - FileType Enum
enum FileType: String, CaseIterable {
    case all = "All"
    case pdf = "PDF"
    case images = "Images"
    case word = "Word"
    case ppt = "PPT"

    var supportedTypes: [UTType] {
        switch self {
        case .all:
            return [.pdf, .image]
        case .pdf:
            return [.pdf]
        case .images:
            return [.image]
        case .word:
            return [] // Add UTTypes for Word files if supported
        case .ppt:
            return [] // Add UTTypes for PowerPoint files if supported
        }
    }
}

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Main View
// MARK: - Main View
struct MainFileView: View {
    @StateObject private var fileManager = FileManagerViewModel()
    @State private var selectedFileType: FileType = .all
    @State private var selectedFile: IdentifiableURL? = nil
    @State private var showImportOptions = false

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationView {
            VStack {
                // Segmented Control
                Picker("File Type", selection: $selectedFileType) {
                    ForEach(FileType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                // File Grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(fileManager.files(for: selectedFileType)) { file in
                            VStack {
                                FileThumbnailView(file: file)
                                    .frame(width: 100, height: 140)
                                    .cornerRadius(8)
                                    .shadow(radius: 3)
                                    .contextMenu {
                                        Button(action: {
                                            // Rename action
                                            fileManager.renameFile(file: file)
                                        }) {
                                            Text("Rename")
                                            Image(systemName: "pencil")
                                        }

                                        Button(action: {
                                            // Delete action
                                            fileManager.deleteFile(file: file)
                                        }) {
                                            Text("Delete")
                                            Image(systemName: "trash")
                                        }
                                    }
                                    .onTapGesture {
                                        selectedFile = IdentifiableURL(url: file.url)
                                    }

                                Text(file.name)
                                    .lineLimit(1)
                                    .font(.caption)
                                    .frame(maxWidth: 100)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                    .padding()
                }

                // Import Button
                Button(action: { showImportOptions.toggle() }) {
                    Text("Import File")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding()
                .actionSheet(isPresented: $showImportOptions) {
                    ActionSheet(
                        title: Text("Import Options"),
                        buttons: [
                            .default(Text("Import from Camera")) {
                                fileManager.importFromCamera()
                            },
                            .default(Text("Import from Files App")) {
                                fileManager.importFromFiles()
                            },
                            .default(Text("Import from Photos")) {
                                fileManager.importFromPhotos()
                            },
                            .cancel()
                        ]
                    )
                }
            }
            .navigationTitle("Files")
            .onAppear {
                fileManager.loadFiles()
            }
            .fullScreenCover(item: $selectedFile) { identifiableURL in
                ZStack {
                    FileViewer(fileURL: identifiableURL.url)
                    
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                selectedFile = nil
                            }) {
                                Image(systemName: "xmark")
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                    .foregroundStyle(.black)
                                    .padding(8)
                                    .background(
                                        Circle()
                                            .fill(.white)
                                    )
                            }
                            .padding(.top, 20) // Add padding to the top to ensure it stays in the safe area
                            .padding(.trailing, 16) // Align it to the right
                        }
                        Spacer()
                    }
                }
            }

        }
    }
}



// MARK: - File Viewer
// MARK: - File Viewer
struct FileViewer: View {
    let fileURL: URL
    @State private var scale: CGFloat = 1.0
    @State private var initialScale: CGFloat = 1.0

    var body: some View {
        VStack {
            if fileURL.pathExtension.lowercased() == "pdf" {
                PDFKitView(url: fileURL)
            } else if let image = UIImage(contentsOfFile: fileURL.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale) // Apply zoom scale
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = initialScale * value
                            }
                            .onEnded { value in
                                initialScale = scale
                            }
                    )
                    .edgesIgnoringSafeArea(.all)
            } else {
                Text("Unsupported file type")
                    .font(.title)
            }
        }
        .background(Color.black.opacity(0.7))
        .edgesIgnoringSafeArea(.all)
    }
}




struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// MARK: - File Thumbnail View
struct FileThumbnailView: View {
    let file: FileItem

    var body: some View {
        if file.type == .pdf {
            PDFThumbnailView(pdfURL: file.url)
        } else if file.type == .images, let image = UIImage(contentsOfFile: file.url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Color.gray
                .overlay(Text("No Preview").foregroundColor(.white))
        }
    }
}

struct PDFThumbnailView: View {
    let pdfURL: URL

    var body: some View {
        if let thumbnail = generateThumbnail(for: pdfURL) {
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFit()
        } else {
            Color.gray
                .overlay(Text("No Preview").foregroundColor(.white))
        }
    }

    private func generateThumbnail(for url: URL) -> UIImage? {
        guard let document = PDFDocument(url: url), let page = document.page(at: 0) else {
            return nil
        }
        let renderer = UIGraphicsImageRenderer(size: page.bounds(for: .mediaBox).size)
        return renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(ctx.format.bounds)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }
}

// MARK: - FileManagerViewModel
class FileManagerViewModel: ObservableObject {
    @Published private(set) var files: [FileItem] = []
    private var folderMonitor: FolderMonitor?

    init() {
        folderMonitor = FolderMonitor(folderURL: directoryURL) {
            self.loadFiles()
        }
    }

    func files(for type: FileType) -> [FileItem] {
        switch type {
        case .all:
            return files
        case .pdf:
            return files.filter { $0.type == .pdf }
        case .images:
            return files.filter { $0.type == .images }
        default:
            return []
        }
    }

    func loadFiles() {
        do {
            let urls = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            files = urls.map { FileItem(url: $0) }
        } catch {
            print("Failed to load files: \(error)")
        }
    }

    
}

// MARK: - FileItem
struct FileItem: Identifiable {
    let id = UUID()
    let url: URL

    var name: String {
        url.lastPathComponent
    }

    var type: FileType {
        if url.pathExtension.lowercased() == "pdf" {
            return .pdf
        } else if UIImage(contentsOfFile: url.path) != nil {
            return .images
        } else {
            return .all
        }
    }
}

// MARK: - FolderMonitor
class FolderMonitor {
    private let folderURL: URL
    private let fileDescriptor: CInt
    private let source: DispatchSourceFileSystemObject
    private let onChange: () -> Void

    init(folderURL: URL, onChange: @escaping () -> Void) {
        self.folderURL = folderURL
        self.onChange = onChange
        fileDescriptor = open(folderURL.path, O_EVTONLY)
        source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: .write, queue: .main)

        source.setEventHandler { [weak self] in
            self?.onChange()
        }

        source.setCancelHandler {
            close(self.fileDescriptor)
        }
        source.resume()
    }

    deinit {
        source.cancel()
    }
}

// MARK: - Directory Helper
private var directoryURL: URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
}

// Import required frameworks
import SwiftUI
import PhotosUI
import UIKit

// MARK: - FileManagerViewModel Extensions
extension FileManagerViewModel {
    func importFromCamera() {
        CameraHandler.shared.captureImage { [weak self] image in
            guard let self = self, let image = image else { return }
            self.saveImageToDocuments(image: image)
        }
    }

    func importFromFiles() {
        FilePicker.shared.pickFile { [weak self] url in
            guard let self = self, let url = url else { return }
            self.copyFileToDocuments(url: url)
        }
    }

    func importFromPhotos() {
        PhotoLibraryHandler.shared.pickImage { [weak self] image in
            guard let self = self, let image = image else { return }
            self.saveImageToDocuments(image: image)
        }
    }

    private func saveImageToDocuments(image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let fileName = UUID().uuidString + ".jpg"
        let fileURL = directoryURL.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL)
            self.loadFiles()
        } catch {
            print("Failed to save image: \(error)")
        }
    }

    private func copyFileToDocuments(url: URL) {
        let destinationURL = directoryURL.appendingPathComponent(url.lastPathComponent)
        do {
            try FileManager.default.copyItem(at: url, to: destinationURL)
            self.loadFiles()
        } catch {
            print("Failed to copy file: \(error)")
        }
    }
}

// MARK: - Camera Handler
class CameraHandler: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    static let shared = CameraHandler()
    private var completion: ((UIImage?) -> Void)?

    func captureImage(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            print("Camera not available")
            completion(nil)
            return
        }

        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        picker.allowsEditing = true

        guard let topController = UIApplication.shared.windows.first?.rootViewController else { return }
        topController.present(picker, animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage
        completion?(image)
        picker.dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        completion?(nil)
        picker.dismiss(animated: true)
    }
}

// MARK: - File Picker
class FilePicker: NSObject, UIDocumentPickerDelegate {
    static let shared = FilePicker()
    private var completion: ((URL?) -> Void)?

    func pickFile(completion: @escaping (URL?) -> Void) {
        self.completion = completion
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image], asCopy: true)
        picker.delegate = self

        guard let topController = UIApplication.shared.windows.first?.rootViewController else { return }
        topController.present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        completion?(urls.first)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        completion?(nil)
    }
}

// MARK: - Photo Library Handler
class PhotoLibraryHandler: NSObject, PHPickerViewControllerDelegate {
    static let shared = PhotoLibraryHandler()
    private var completion: ((UIImage?) -> Void)?

    func pickImage(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self

        guard let topController = UIApplication.shared.windows.first?.rootViewController else { return }
        topController.present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        guard let result = results.first else {
            completion?(nil)
            picker.dismiss(animated: true)
            return
        }

        if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                DispatchQueue.main.async {
                    if let image = object as? UIImage {
                        self?.completion?(image)
                    } else {
                        print("Failed to load image: \(error?.localizedDescription ?? "Unknown error")")
                        self?.completion?(nil)
                    }
                    picker.dismiss(animated: true)
                }
            }
        }
    }
}


extension FileManagerViewModel {
    

    func deleteFile(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            loadFiles()
        } catch {
            print("Failed to delete file: \(error)")
        }
    }
}


// MARK: - FileManagerViewModel Extensions
extension FileManagerViewModel {
    func renameFile(file: FileItem) {
        let alert = UIAlertController(title: "Rename File", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = file.name
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Rename", style: .default, handler: { [weak self] _ in
            if let newName = alert.textFields?.first?.text, !newName.isEmpty {
                self?.renameFile(at: file.url, newName: newName)
            }
        }))

        if let topController = UIApplication.shared.windows.first?.rootViewController {
            topController.present(alert, animated: true)
        }
    }

    func renameFile(at url: URL, newName: String) {
        let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
        do {
            try FileManager.default.moveItem(at: url, to: newURL)
            loadFiles()
        } catch {
            print("Error renaming file: \(error)")
        }
    }

    func deleteFile(file: FileItem) {
        do {
            try FileManager.default.removeItem(at: file.url)
            loadFiles()
        } catch {
            print("Error deleting file: \(error)")
        }
    }
}
