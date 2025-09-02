import SwiftUI
import SwiftData
import PDFKit
import QuickLook // Import for thumbnail generation

// The @MainActor attribute ensures that all UI updates happen on the main thread.
@MainActor
class CardDetailViewModel: ObservableObject {
    
    // MARK: - Properties
    
    let subject: Subject
    private let modelContext: ModelContext
    
    // --- UI State ---
    @Published var allFiles: [URL] = []
    @Published var filteredFiles: [URL] = []
    
    @Published var isShowingDeleteAlert = false
    @Published var isShowingEditView = false
    @Published var isShowingFileImporter = false
    @Published var isShowingImagePicker = false
    @Published var isImportingFile = false
    
    // --- Camera and Cropping State ---
    @Published var isShowingCamera = false
    @Published var isShowingCropper = false
    @Published var imageToCrop: UIImage?
    
    // --- Universal Preview State ---
    // This now handles PDFs, DOCX, and Images.
    @Published var documentToPreview: PreviewableDocument? = nil
    
    @Published var selectedFilter: NoteFilter = .all
    
    // --- Renaming State ---
    @Published var renamingFileURL: URL? = nil {
        didSet {
            if let url = renamingFileURL {
                newFileName = url.deletingPathExtension().lastPathComponent
            }
        }
    }
    @Published var newFileName: String = ""
    
    // REMOVED: All properties related to custom image preview gestures (scale, offset, etc.)
    
    // MARK: - Initializer
    
    init(subject: Subject, modelContext: ModelContext) {
        self.subject = subject
        self.modelContext = modelContext
        loadFiles()
    }
    
    // MARK: - Business Logic
    
    func loadFiles() {
        self.allFiles = FileHelper.loadFiles(from: subject)
        filterNotes()
    }
    
    func filterNotes() {
        switch selectedFilter {
        case .all:
            filteredFiles = allFiles
        case .images:
            filteredFiles = allFiles.filter { $0.isImage }
        case .pdfs:
            filteredFiles = allFiles.filter { $0.isPDF }
        case .docs:
            filteredFiles = allFiles.filter { $0.isDocx }
        }
    }
    
    func deleteSubject(onDismiss: () -> Void) {
        FileHelper.deleteSubjectFolder(for: subject)
        modelContext.delete(subject)
        onDismiss()
    }
    
    func deleteFile(at fileURL: URL) {
        do {
            try FileManager.default.removeItem(at: fileURL)
            loadFiles()
        } catch {
            print("Failed to delete file: \(error.localizedDescription)")
        }
    }
    
    func renameFile() {
        guard let oldURL = renamingFileURL, !newFileName.isEmpty else { return }
        
        let fileExtension = oldURL.pathExtension
        let newURL = oldURL.deletingLastPathComponent().appendingPathComponent("\(newFileName).\(fileExtension)")
        
        do {
            try FileManager.default.moveItem(at: oldURL, to: newURL)
            loadFiles()
        } catch {
            print("Rename failed: \(error.localizedDescription)")
        }
        renamingFileURL = nil
    }
    
    func handleFileImport(result: Result<URL, Error>) {
        isImportingFile = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            defer { self.isImportingFile = false }
            do {
                let sourceURL = try result.get()
                guard sourceURL.startAccessingSecurityScopedResource() else { return }
                defer { sourceURL.stopAccessingSecurityScopedResource() }
                
                let data = try Data(contentsOf: sourceURL)
                let originalFilename = sourceURL.lastPathComponent
                
                if FileHelper.saveFile(data: data, fileName: originalFilename, to: self.subject) != nil {
                    self.loadFiles()
                }
            } catch {
                print("Failed to import file: \(error.localizedDescription)")
            }
        }
    }
    
    func handleImageSelected(_ image: UIImage?) {
        guard let image = image else { return }
        imageToCrop = image
        isShowingCropper = true
    }
    
    func handleCroppedImage(_ image: UIImage?) {
        guard let image = image, let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        let fileName = "image_\(UUID().uuidString).jpg"
        
        if FileHelper.saveFile(data: imageData, fileName: fileName, to: subject) != nil {
            loadFiles()
        }
    }
    
    func generatePDFThumbnail(from url: URL) -> UIImage? {
        guard let document = PDFDocument(url: url), let page = document.page(at: 0) else { return nil }
        let pageRect = page.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        
        return renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(pageRect)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }
    
    func generateDocxThumbnail(from url: URL, completion: @escaping (UIImage?) -> Void) {
        let size = CGSize(width: 80, height: 100)
        let scale = UIScreen.main.scale
        
        let request = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: scale, representationTypes: .thumbnail)
        
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, error in
            if let error = error {
                print("Failed to generate thumbnail: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            DispatchQueue.main.async {
                completion(representation?.uiImage)
            }
        }
    }
    
    // REMOVED: All gesture logic functions (onImagePreviewAppear, adjustScale, etc.)
}

// MARK: - Helpers
extension URL {
    var isImage: Bool {
        let ext = self.pathExtension.lowercased()
        return ext == "jpg" || ext == "jpeg" || ext == "png"
    }
    
    var isPDF: Bool { self.pathExtension.lowercased() == "pdf" }
    
    var isDocx: Bool {
        self.pathExtension.lowercased() == "docx"
    }
}

