import SwiftUI
import SwiftData
import PDFKit

// It's good practice to keep these small, related structs and enums with the ViewModel
// if they aren't used elsewhere, or in their own file if they are.

struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

// FIXED: Removed the PPTs case
enum NoteFilter: String, CaseIterable {
    case all = "All"
    case images = "Images"
    case pdfs = "PDFs"
    case docs = "Docs"
}

// Wrapper to make URL Identifiable for the .sheet modifier
struct PreviewableDocument: Identifiable {
    let id = UUID()
    let url: URL
}

// The @MainActor attribute ensures that all UI updates happen on the main thread.
@MainActor
class CardDetailViewModel: ObservableObject {
    
    // MARK: - Properties
    
    // The Model data for the view
    let subject: Subject
    
    // Dependencies like the model context are passed in.
    private let modelContext: ModelContext
    
    // --- UI State ---
    @Published var allFiles: [URL] = []
    @Published var filteredFiles: [URL] = []
    
    @Published var isShowingDeleteAlert = false
    @Published var isShowingEditView = false
    @Published var selectedImageForPreview: IdentifiableImage? = nil
    @Published var isShowingFileImporter = false
    @Published var isShowingImagePicker = false
    @Published var isImportingFile = false
    
    // --- New UI State for Camera and Cropping ---
    @Published var isShowingCamera = false
    @Published var isShowingCropper = false
    @Published var imageToCrop: UIImage?
    
    // --- Document Preview State ---
    @Published var documentToPreview: PreviewableDocument? = nil
    
    @Published var selectedFilter: NoteFilter = .all
    
    @Published var renamingFileURL: URL? = nil {
        didSet {
            if let url = renamingFileURL {
                newFileName = url.deletingPathExtension().lastPathComponent
            }
        }
    }
    @Published var newFileName: String = ""
    
    // --- Image Preview Gesture State ---
    @Published var scale = 1.0
    @Published var lastScale = 1.0
    @Published var imageOffset = CGSize.zero
    @Published var lastOffset = CGSize.zero
    
    private let minScale = 1.0
    private let maxScale = 5.0
    
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
        // FIXED: Removed logic for PPTs
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
    
    // MARK: - Gesture Logic
    
    func onImagePreviewAppear() {
        scale = 1.0
        imageOffset = .zero
        lastOffset = .zero
    }
    
    func adjustScale(from state: MagnificationGesture.Value) {
        let delta = state / lastScale
        scale *= delta
        lastScale = state
    }
    
    func onMagnificationEnded() {
        withAnimation(.easeOut(duration: 0.3)) {
            scale = max(min(scale, maxScale), minScale)
        }
        lastScale = 1.0

        if scale <= 1.01 {
            withAnimation(.easeOut(duration: 0.8)) {
                imageOffset = .zero
                lastOffset = .zero
            }
        }
    }
    
    func adjustDragOffset(gesture: DragGesture.Value, geometrySize: CGSize) {
        let maxOffsetX = (geometrySize.width * (scale - 1)) / 2
        let maxOffsetY = (geometrySize.height * (scale - 1)) / 2
        
        withTransaction(Transaction(animation: nil)) {
            imageOffset.width = min(max(gesture.translation.width + lastOffset.width, -maxOffsetX), maxOffsetX)
            imageOffset.height = min(max(gesture.translation.height + lastOffset.height, -maxOffsetY), maxOffsetY)
        }
    }
    
    func onDragEnded() {
        lastOffset = imageOffset
    }
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
    
    // Removed isPptx
}

