import SwiftUI
import SwiftData
import PDFKit
import QuickLook // Import for thumbnail generation
import PhotosUI // Import for modern photo picker

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
    @Published var isImportingFile = false
    @Published var isShowingPhotoPicker = false
    
    // --- Camera and Cropping State (for single image capture) ---
    @Published var isShowingCamera = false
    @Published var isShowingCropper = false
    @Published var imageToCrop: UIImage?
    
    // --- Photos Picker State (for multi-image selection) ---
    @Published var selectedPhotoItems: [PhotosPickerItem] = [] {
        didSet {
            handlePhotoPickerSelection()
        }
    }
    
    // --- Universal Preview State ---
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
    
    // --- Selection State for Multi-Delete ---
    @Published var isEditing = false
    @Published var selectedFiles: Set<URL> = []
    @Published var isShowingMultiDeleteAlert = false
    
    
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
    
    // --- File Import Handlers ---

    func handleFileImport(result: Result<[URL], Error>) {
        isImportingFile = true

        Task {
            // This defer block ensures isImportingFile is always set back to false
            // when the Task finishes, even if an error is thrown.
            defer {
                Task { @MainActor in
                    isImportingFile = false
                }
            }

            do {
                let sourceURLs = try result.get()
                for sourceURL in sourceURLs {
                    let didStartAccessing = sourceURL.startAccessingSecurityScopedResource()
                    if !didStartAccessing {
                        print("Could not access security-scoped resource for \(sourceURL.lastPathComponent)")
                        continue
                    }

                    // Perform blocking file I/O in a detached, background task to avoid freezing the UI.
                    let data = try await Task.detached {
                        // Stop accessing the resource as soon as the background task is done with it.
                        defer { sourceURL.stopAccessingSecurityScopedResource() }
                        return try Data(contentsOf: sourceURL)
                    }.value
                    
                    // Now we are back on the MainActor, so it's safe to access self.subject.
                    let originalFilename = sourceURL.lastPathComponent
                    _ = FileHelper.saveFile(data: data, fileName: originalFilename, to: self.subject)
                }
                
                // Refresh the file list on the main thread.
                loadFiles()

            } catch {
                print("Failed to import files: \(error.localizedDescription)")
            }
        }
    }
    
    private func handlePhotoPickerSelection() {
        guard !selectedPhotoItems.isEmpty else { return }
        isImportingFile = true
        
        let items = selectedPhotoItems
        self.selectedPhotoItems = [] // Clear selection
        
        Task {
            defer {
                Task { @MainActor in
                    isImportingFile = false
                    if self.isEditing { self.toggleEditMode() }
                    self.loadFiles()
                }
            }
            
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let fileName = "image_\(UUID().uuidString).jpg"
                    // self.subject is safe to access here because a Task created in a MainActor-isolated
                    // context will run on the main actor.
                    _ = FileHelper.saveFile(data: data, fileName: fileName, to: self.subject)
                }
            }
        }
    }
    
    // --- Single Image Handlers (for Camera) ---
    
    func handleImageSelected(_ image: UIImage?) {
        guard let image = image else { return }
        imageToCrop = image
        isShowingCropper = true
    }
    
    func handleCroppedImage(_ image: UIImage?) {
        guard let image = image, let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        let fileName = "image_\(UUID().uuidString).jpg"
        
        if FileHelper.saveFile(data: imageData, fileName: fileName, to: subject) != nil {
            if self.isEditing { self.toggleEditMode() }
            loadFiles()
        }
    }

    // --- Thumbnail Generation ---
    
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
    
    // --- Multi-Delete methods ---
    
    func toggleEditMode() {
        withAnimation(.easeInOut) {
            isEditing.toggle()
        }
        if !isEditing {
            selectedFiles.removeAll()
        }
    }

    func toggleSelection(for fileURL: URL) {
        if selectedFiles.contains(fileURL) {
            selectedFiles.remove(fileURL)
        } else {
            selectedFiles.insert(fileURL)
        }
    }

    func deleteSelectedFiles() {
        let urlsToDelete = selectedFiles
        
        for fileURL in urlsToDelete {
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                print("Failed to delete file \(fileURL.lastPathComponent): \(error.localizedDescription)")
            }
        }
        
        DispatchQueue.main.async {
            self.selectedFiles.removeAll()
            withAnimation {
                self.isEditing = false
            }
            self.loadFiles()
        }
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
}

