import SwiftUI
import SwiftData
import PDFKit
import QuickLook // Import for thumbnail generation
import PhotosUI // Import for modern photo picker

// The @MainActor attribute ensures that all UI updates happen on the main thread.
@MainActor
class CardDetailViewModel: ObservableObject {
    
    // MARK: - Enums
    
    enum SortType: String, CaseIterable, Identifiable {
        case date = "Date Added"
        case name = "Alphabetical"
        
        var id: String { self.rawValue }
    }
    
    // MARK: - Properties
    
    // Centralized entry point to start renaming/captioning a file
    private func beginRenaming(with metadata: FileMetadata) {
        self.renamingFileMetadata = metadata
        self.newFileName = self.suggestedEditableName(from: metadata.fileName)
        self.isShowingRenameView = true
    }
    
    // Returns an empty string for auto-generated image names like "image_<UUID>", otherwise returns the base name without extension.
    private func suggestedEditableName(from fileName: String) -> String {
        let base = (fileName as NSString).deletingPathExtension
        let lower = base.lowercased()
        // Accept both image_ and image- prefixes
        if lower.hasPrefix("image_") || lower.hasPrefix("image-") {
            let dropCount = lower.hasPrefix("image_") ? 6 : 6 // length of "image_" or "image-"
            let uuidPart = String(lower.dropFirst(dropCount))
            // Basic UUID format check: 8-4-4-4-12
            let components = uuidPart.split(separator: "-")
            let expected = [8, 4, 4, 4, 12]
            if components.count == expected.count && zip(components, expected).allSatisfy({ $0.count == $1 }) {
                return ""
            }
        }
        return base
    }
    
    let subject: Subject
    private let modelContext: ModelContext
    
    // --- Folder-based State ---
    @Published var currentFolder: Folder? = nil
    @Published var folderPath: [Folder] = [] // Breadcrumb navigation
    @Published var currentFiles: [FileMetadata] = []
    @Published var filteredFileMetadata: [FileMetadata] = []
    @Published var subfolders: [Folder] = []
    
    @Published var isShowingDeleteAlert = false
    @Published var isShowingEditView = false
    @Published var isShowingFileImporter = false
    @Published var isImportingFile = false
    @Published var isShowingPhotoPicker = false
    // Dedicated flag for rename/caption UI
    @Published var isShowingRenameView = false
    
    // --- Search State ---
    @Published var isSearchBarVisible = false
    @Published var searchText: String = ""
    @Published var isSearching: Bool = false
    @Published var searchResults: [FileMetadata] = []
    @Published var searchFolderResults: [Folder] = []
    
    // --- Folder Management State ---
    @Published var isShowingCreateFolderAlert = false
    @Published var newFolderName: String = ""
    @Published var isShowingFolderPicker = false
    @Published var availableFolders: [Folder] = []
    
    // --- Camera and Cropping State ---
    @Published var isShowingCamera = false
    @Published var isShowingCropper = false
    @Published var imageToCrop: UIImage?
    
    // --- Photos Picker State ---
    @Published var selectedPhotoItems: [PhotosPickerItem] = [] {
        didSet {
            handlePhotoPickerSelection()
        }
    }
    
    // --- Universal Preview State ---
    @Published var documentToPreview: PreviewableDocument? = nil
    
    // --- Filtering and Sorting State ---
    @Published var selectedFilter: NoteFilter = .all
    @Published var sortType: SortType = .date
    @Published var sortAscending: Bool = false // false for descending (newest), true for ascending (oldest)

    // --- Renaming State ---
    @Published var renamingFileMetadata: FileMetadata? = nil {
        didSet {
            if let metadata = renamingFileMetadata {
                if metadata.fileType == .image {
                    newFileName = suggestedEditableName(from: metadata.fileName)
                } else {
                    newFileName = (metadata.fileName as NSString).deletingPathExtension
                }
                isShowingRenameView = true
            }
        }
    }
    @Published var renamingFileURL: URL? = nil {
        didSet {
            guard renamingFileMetadata == nil else { return }
            if let url = renamingFileURL {
                let base = url.deletingPathExtension().lastPathComponent
                newFileName = suggestedEditableName(from: base)
                isShowingRenameView = true
            }
        }
    }
    @Published var newFileName: String = ""
    
    // --- Selection State for Multi-Select ---
    @Published var isEditing = false
    @Published var selectedFileMetadata: Set<FileMetadata> = []
    @Published var isShowingMultiDeleteAlert = false
    
    // --- Multi-Sharing State ---
    @Published var urlsToShare: [URL] = []
    @Published var isShowingMultiShareSheet = false
    
    
    // MARK: - Initializer
    
    init(subject: Subject, modelContext: ModelContext) {
        self.subject = subject
        self.modelContext = modelContext
        
        FileDataService.migrateExistingFiles(for: subject, modelContext: modelContext)
        loadFolderContent()
    }
    
    // MARK: - Sorting Methods
    
    func selectSortOption(_ newSortType: SortType) {
        if self.sortType == newSortType {
            // If the same sort type is tapped again, just reverse the order
            self.sortAscending.toggle()
        } else {
            // If a new sort type is selected, switch to it and set a default order
            self.sortType = newSortType
            // Default to ascending for name (A-Z), descending for date (newest first)
            self.sortAscending = (newSortType == .name)
        }
        
        // Re-apply sorting
        if isSearching {
            performSearch()
        } else {
            loadFolderContent()
        }
    }
    
    // MARK: - Folder-based Methods
    
    func loadFolderContent() {
        let rawSubfolders: [Folder]
        let rawFiles: [FileMetadata]

        if let currentFolder = currentFolder {
            rawSubfolders = Array(currentFolder.subfolders)
            rawFiles = Array(currentFolder.files)
        } else {
            rawSubfolders = Array(subject.rootFolders)
            rawFiles = subject.fileMetadata.filter { $0.folder == nil }
        }

        switch sortType {
        case .name:
            subfolders = rawSubfolders.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == (sortAscending ? .orderedAscending : .orderedDescending)
            }
            currentFiles = rawFiles.sorted {
                $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == (sortAscending ? .orderedAscending : .orderedDescending)
            }
        case .date:
            subfolders = rawSubfolders.sorted {
                sortAscending ? ($0.createdDate < $1.createdDate) : ($0.createdDate > $1.createdDate)
            }
            currentFiles = rawFiles.sorted {
                sortAscending ? ($0.createdDate < $1.createdDate) : ($0.createdDate > $1.createdDate)
            }
        }

        filterFileMetadata()
    }
    
    func filterFileMetadata() {
        let showSearchAtRoot = isSearching && currentFolder == nil
        let filesToFilter = showSearchAtRoot ? searchResults : currentFiles
        
        // Use the already sorted subfolders from loadFolderContent unless searching
        let foldersToUse = isSearching ? searchFolderResults : subfolders

        switch selectedFilter {
        case .all:
            filteredFileMetadata = filesToFilter
            self.subfolders = foldersToUse
        case .images:
            filteredFileMetadata = filesToFilter.filter { $0.fileType == .image }
            self.subfolders = foldersToUse.filter { folder in !folder.files.filter { $0.fileType == .image }.isEmpty }
        case .pdfs:
            filteredFileMetadata = filesToFilter.filter { $0.fileType == .pdf }
            self.subfolders = foldersToUse.filter { folder in !folder.files.filter { $0.fileType == .pdf }.isEmpty }
        case .docs:
            filteredFileMetadata = filesToFilter.filter { $0.fileType == .docx }
            self.subfolders = foldersToUse.filter { folder in !folder.files.filter { $0.fileType == .docx }.isEmpty }
        case .favorites:
            if currentFolder == nil && !isSearching {
                filteredFileMetadata = subject.fileMetadata.filter { $0.isFavorite }
                let allFolders = allFoldersRecursively(from: subject.rootFolders)
                self.subfolders = allFolders.filter { $0.isFavorite }
            } else {
                // When in a folder or searching, show all content and let user see favorites via icon
                filteredFileMetadata = filesToFilter
                self.subfolders = foldersToUse
            }
        }
    }
    
    // Recursively collect all folders starting from a list of folders
    private func allFoldersRecursively(from folders: [Folder]) -> [Folder] {
        var result: [Folder] = []
        for folder in folders {
            result.append(folder)
            if !folder.subfolders.isEmpty {
                result.append(contentsOf: allFoldersRecursively(from: folder.subfolders))
            }
        }
        return result
    }
    
    // MARK: - Navigation Methods
    
    func navigateToFolder(_ folder: Folder) {
        folderPath.append(folder)
        currentFolder = folder
        loadFolderContent()
    }
    
    func navigateToRoot() {
        folderPath.removeAll()
        currentFolder = nil
        loadFolderContent()
    }
    
    func navigateToFolder(at index: Int) {
        guard index < folderPath.count else { return }
        folderPath = Array(folderPath.prefix(index + 1))
        currentFolder = folderPath.last
        loadFolderContent()
    }
    
    // MARK: - Folder Management
    
    func createFolder(named name: String) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let folder = Folder(name: name, parentFolder: currentFolder, subject: subject)
        modelContext.insert(folder)
        _ = FileDataService.createFolder(named: name, in: currentFolder, for: subject)
        
        try? modelContext.save()
        loadFolderContent()
    }
    
    func deleteFolder(_ folder: Folder) {
        _ = FileDataService.deleteFolder(folder, in: subject)
        modelContext.delete(folder)
        try? modelContext.save()
        loadFolderContent()
    }

    func toggleFavorite(for folder: Folder) {
        folder.isFavorite.toggle()
        try? modelContext.save()
        loadFolderContent()
    }
    
    // MARK: - File Management
    
    func toggleFavorite(for fileMetadata: FileMetadata) {
        fileMetadata.isFavorite.toggle()
        try? modelContext.save()
        loadFolderContent() // Refresh to show favorite status change
    }
    
    func deleteFileMetadata(_ fileMetadata: FileMetadata) {
        guard let fileURL = fileMetadata.getFileURL() else { return }
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            modelContext.delete(fileMetadata)
            try? modelContext.save()
            loadFolderContent()
        } catch {
            print("Failed to delete file: \(error)")
        }
    }
    
    func renameFileMetadata(_ fileMetadata: FileMetadata, to newName: String) {
        guard let oldURL = fileMetadata.getFileURL() else { return }
        
        let fileExtension = (fileMetadata.fileName as NSString).pathExtension
        let newFileName = "\(newName).\(fileExtension)"
        let newURL = oldURL.deletingLastPathComponent().appendingPathComponent(newFileName)
        
        do {
            try FileManager.default.moveItem(at: oldURL, to: newURL)
            fileMetadata.fileName = newFileName
            let folderPath = fileMetadata.folder?.fullPath ?? ""
            fileMetadata.relativePath = folderPath.isEmpty ? newFileName : "\(folderPath)/\(newFileName)"
            
            try? modelContext.save()
            loadFolderContent()
        } catch {
            print("Failed to rename file: \(error)")
        }
    }
    
    // MARK: - Search Methods
    
    func toggleSearchBarVisibility() {
        isSearchBarVisible.toggle()
        if !isSearchBarVisible {
            clearSearch()
        }
    }
    
    func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults.removeAll()
            searchFolderResults.removeAll()
            isSearching = false
            filterFileMetadata()
            return
        }
        
        isSearching = true
        let query = searchText.lowercased()
        
        // Search all files and sort them
        let filesToSearch = self.subject.fileMetadata
        var results = filesToSearch.filter { $0.fileName.lowercased().contains(query) }
        
        switch sortType {
        case .name:
            results.sort {
                $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == (sortAscending ? .orderedAscending : .orderedDescending)
            }
        case .date:
            results.sort {
                sortAscending ? ($0.createdDate < $1.createdDate) : ($0.createdDate > $1.createdDate)
            }
        }
        searchResults = results
        
        // Search all folders and sort them
        let allFolders = allFoldersRecursively(from: subject.rootFolders)
        var folderResults = allFolders.filter { $0.name.lowercased().contains(query) }
        
        switch sortType {
        case .name:
            folderResults.sort {
                $0.name.localizedCaseInsensitiveCompare($1.name) == (sortAscending ? .orderedAscending : .orderedDescending)
            }
        case .date:
            folderResults.sort {
                sortAscending ? ($0.createdDate < $1.createdDate) : ($0.createdDate > $1.createdDate)
            }
        }
        searchFolderResults = folderResults
        
        filterFileMetadata()
    }
    
    func clearSearch() {
        searchText = ""
        searchResults.removeAll()
        searchFolderResults.removeAll()
        isSearching = false
        // When clearing search, restore the view to its non-searching state
        loadFolderContent()
    }
    
    // MARK: - Folder Picker & Move Methods
    
    func showFolderPicker(for fileMetadata: FileMetadata) {
        selectedFileMetadata.removeAll()
        selectedFileMetadata.insert(fileMetadata)
        showFolderPickerForSelection()
    }

    func showFolderPickerForSelection() {
        loadAvailableFolders()
        isShowingFolderPicker = true
    }

    func moveSelectedFiles(to targetFolder: Folder?) {
        for fileMetadata in selectedFileMetadata {
            // We need to know the source subject to move correctly
            guard let sourceSubject = fileMetadata.subject else { continue }
            _ = FileDataService.moveFile(fileMetadata, to: targetFolder, in: sourceSubject)
        }
        
        Task {
            try? modelContext.save()
            await MainActor.run {
                selectedFileMetadata.removeAll()
                isEditing = false
                loadFolderContent()
            }
        }
    }
    
    private func loadAvailableFolders() {
        var folders: [Folder] = []
        // This recursive function fetches all subfolders
        func addFoldersRecursively(from parentFolder: Folder?) {
            let foldersToAdd = parentFolder?.subfolders ?? subject.rootFolders
            for folder in foldersToAdd.sorted(by: { $0.name < $1.name }) {
                folders.append(folder)
                // Since we are not allowing nested folders, we don't need the recursive call
                // addFoldersRecursively(from: folder)
            }
        }
        addFoldersRecursively(from: nil)
        availableFolders = folders
    }
    
    func deleteSubject(onDismiss: () -> Void) {
        FileDataService.deleteSubjectFolder(for: subject)
        modelContext.delete(subject)
        onDismiss()
    }
    
    func renameFile() {
        guard !newFileName.isEmpty else { return }

        if let metadata = renamingFileMetadata {
             renameFileMetadata(metadata, to: newFileName)
        }
        
        // Reset the renaming state
        renamingFileURL = nil
        renamingFileMetadata = nil
        isShowingRenameView = false
    }
    
    // MARK: - File Import Handlers

    func handleFileImport(result: Result<[URL], Error>) {
        isImportingFile = true
        Task {
            defer { Task { @MainActor in isImportingFile = false } }
            do {
                let sourceURLs = try result.get()
                for sourceURL in sourceURLs {
                    _ = sourceURL.startAccessingSecurityScopedResource()
                    let data = try await Task.detached {
                        defer { sourceURL.stopAccessingSecurityScopedResource() }
                        return try Data(contentsOf: sourceURL)
                    }.value
                    _ = FileDataService.saveFile(data: data, fileName: sourceURL.lastPathComponent, to: self.currentFolder, in: self.subject, modelContext: self.modelContext)
                }
                loadFolderContent()
            } catch {
                print("Failed to import files: \(error.localizedDescription)")
            }
        }
    }
    
    private func handlePhotoPickerSelection() {
        guard !selectedPhotoItems.isEmpty else { return }
        isImportingFile = true
        let items = selectedPhotoItems
        self.selectedPhotoItems = [] // Clear selection immediately
        
        Task {
            defer { Task { @MainActor in
                isImportingFile = false
                if self.isEditing { self.toggleEditMode() } // Exit edit mode after adding
                self.loadFolderContent()
            }}
            
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let fileName = "image_\(UUID().uuidString).jpg"
                    _ = FileDataService.saveFile(
                        data: data,
                        fileName: fileName,
                        to: self.currentFolder,
                        in: self.subject,
                        modelContext: self.modelContext
                    )
                }
            }
        }
    }
    
    // MARK: - Single Image Handlers (Camera)
    
    func handleImageSelected(_ image: UIImage?) {
        guard let image = image else { return }
        imageToCrop = image
        isShowingCropper = true
    }
    
    func handleCroppedImage(_ image: UIImage?) {
        guard let image = image, let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        let fileName = "image_\(UUID().uuidString).jpg"
        
        if let _ = FileDataService.saveFile(data: imageData, fileName: fileName, to: currentFolder, in: subject, modelContext: modelContext) {
            if self.isEditing { self.toggleEditMode() }
            loadFolderContent()
        }
    }

    // MARK: - Thumbnail Generation
    
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
            DispatchQueue.main.async {
                completion(representation?.uiImage)
            }
        }
    }
    
    // MARK: - Sharing Methods
    
    func shareSelectedFiles() {
        let urls = selectedFileMetadata.compactMap { $0.getFileURL() }
        guard !urls.isEmpty else { return }
        
        self.urlsToShare = urls
        self.isShowingMultiShareSheet = true
    }
    
    func shareFolder(_ folder: Folder) {
        var urls: [URL] = []
        
        func recursivelyCollectFiles(from folder: Folder) {
            urls.append(contentsOf: folder.files.compactMap { $0.getFileURL() })
            for subfolder in folder.subfolders {
                recursivelyCollectFiles(from: subfolder)
            }
        }
        
        recursivelyCollectFiles(from: folder)
        
        guard !urls.isEmpty else {
            // Optionally show an alert that the folder is empty
            return
        }
        
        self.urlsToShare = urls
        self.isShowingMultiShareSheet = true
    }
    
    // MARK: - Multi-Select / Editing Methods
    
    func toggleEditMode() {
        isEditing.toggle()
        if !isEditing {
            selectedFileMetadata.removeAll()
        }
    }

    func deleteSelectedFiles() {
        let metadataToDelete = selectedFileMetadata
        for metadata in metadataToDelete {
            deleteFileMetadata(metadata)
        }
        
        DispatchQueue.main.async {
            self.selectedFileMetadata.removeAll()
            self.isEditing = false
            self.loadFolderContent()
        }
    }
    
    func toggleSelectionForMetadata(_ metadata: FileMetadata) {
        if selectedFileMetadata.contains(metadata) {
            selectedFileMetadata.remove(metadata)
        } else {
            selectedFileMetadata.insert(metadata)
        }
    }
}

