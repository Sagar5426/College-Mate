import SwiftUI
import SwiftData
import PDFKit

// It's good practice to keep these small, related structs and enums with the ViewModel
// if they aren't used elsewhere, or in their own file if they are.

struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

enum NoteFilter: String, CaseIterable {
    case all = "All"
    case images = "Images"
    case pdfs = "PDFs"
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
    // All @State properties from the View become @Published properties here.
    // The View will now subscribe to these for updates.
    
    @Published var allFiles: [URL] = []
    @Published var filteredFiles: [URL] = []
    
    @Published var isShowingDeleteAlert = false
    @Published var isShowingEditView = false
    @Published var selectedImageForPreview: IdentifiableImage? = nil
    @Published var isShowingFileImporter = false
    @Published var isShowingImagePicker = false
    @Published var isImportingFile = false
    
    // When selectedFilter changes, the view will trigger a re-filter.
    @Published var selectedFilter: NoteFilter = .all
    
    // Logic for handling the rename alert state
    @Published var renamingFileURL: URL? = nil {
        didSet {
            // Pre-populate the text field when a URL is set for renaming
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
        
        // Load initial data when the ViewModel is created.
        loadFiles()
    }
    
    // MARK: - Business Logic (Moved from View)
    
    // Load all files from storage and then apply the current filter.
    func loadFiles() {
        self.allFiles = FileHelper.loadFiles(from: subject)
        filterNotes()
    }
    
    // Update the filteredFiles array based on the selected filter.
    // This is more efficient than filtering inside a computed property.
    func filterNotes() {
        switch selectedFilter {
        case .all:
            filteredFiles = allFiles
        case .images:
            filteredFiles = allFiles.filter { $0.isImage }
        case .pdfs:
            filteredFiles = allFiles.filter { $0.isPDF }
        }
    }
    
    // The ViewModel can't dismiss the view directly, so we accept a
    // closure (a function) to be executed after the logic is done.
    func deleteSubject(onDismiss: () -> Void) {
        FileHelper.deleteSubjectFolder(for: subject)
        modelContext.delete(subject)
        onDismiss()
    }
    
    func deleteFile(at fileURL: URL) {
        do {
            try FileManager.default.removeItem(at: fileURL)
            loadFiles() // Refresh the file list after deletion.
        } catch {
            print("Failed to delete file: \(error.localizedDescription)")
        }
    }
    
    func renameFile() {
        guard let oldURL = renamingFileURL else { return }
        
        let newURL = oldURL.deletingLastPathComponent().appendingPathComponent("\(newFileName).pdf")
        do {
            try FileManager.default.moveItem(at: oldURL, to: newURL)
            loadFiles() // Refresh file list
        } catch {
            print("Rename failed: \(error.localizedDescription)")
        }
        // Reset the state to dismiss the alert.
        renamingFileURL = nil
    }
    
    func handleFileImport(result: Result<URL, Error>) {
        isImportingFile = true
        
        // Using a weak self to prevent retain cycles in closures.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            // Ensure the loading indicator is turned off, even if something fails.
            defer { self.isImportingFile = false }
            
            do {
                let fileURL = try result.get()
                guard fileURL.startAccessingSecurityScopedResource() else { return }
                defer { fileURL.stopAccessingSecurityScopedResource() }
                
                let data = try Data(contentsOf: fileURL)
                let fileName = "pdf_\(UUID().uuidString).pdf"
                
                if let savedURL = FileHelper.saveFile(data: data, fileName: fileName, to: self.subject) {
                    let newNote = Note(title: fileName, type: .pdf, content: Data(savedURL.absoluteString.utf8))
                    self.subject.notes.append(newNote)
                    try? self.modelContext.save()
                    self.loadFiles() // Refresh file list
                }
            } catch {
                print("Failed to import PDF: \(error.localizedDescription)")
            }
        }
    }
    
    func handleImageSelected(_ image: UIImage?) {
        guard let image = image, let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        let fileName = "image_\(UUID().uuidString).jpg"
        
        if let fileURL = FileHelper.saveFile(data: imageData, fileName: fileName, to: subject) {
            let newNote = Note(title: fileName, type: .image, content: Data(fileURL.absoluteString.utf8))
            subject.notes.append(newNote)
            try? modelContext.save()
            loadFiles() // Refresh file list
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
        
        // Disabling animation during drag for a more responsive feel.
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
// This extension is now part of the ViewModel's file.
extension URL {
    var isImage: Bool {
        let ext = self.pathExtension.lowercased()
        return ext == "jpg" || ext == "png"
    }
    
    var isPDF: Bool { self.pathExtension.lowercased() == "pdf" }
}
