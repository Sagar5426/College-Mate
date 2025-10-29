import SwiftUI
import SwiftData
import PDFKit
import QuickLook // Import for thumbnail generation
import PhotosUI // Import for modern photo picker

// The @MainActor attribute ensures that all UI updates happen on the main thread.
@MainActor
class CardDetailViewModel: ObservableObject {
    
    // MARK: - Enums
    enum SortType: String {
        case date = "Date Added"
        case name = "Alphabetical"
    }

    enum LayoutStyle: String, CaseIterable {
        case grid = "Grid"
        case list = "List"
    }
    
    // MARK: - Properties
    
    private let layoutStyleKey: String
    
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
    
    // --- View State ---
    @Published var layoutStyle: LayoutStyle = .grid {
        didSet {
            UserDefaults.standard.set(layoutStyle.rawValue, forKey: layoutStyleKey)
        }
    }
    @Published var sortType: SortType = .date
    @Published var sortAscending: Bool = false // false for newest first/A-Z
    
    // ADDED: State for the note sheet
    @Published var isShowingNoteSheet = false
    @Published var subjectNote: String = ""
    
    // --- Folder-based State ---
    @Published var currentFolder: Folder? = nil
    @Published var folderPath: [Folder] = [] // Breadcrumb navigation
    @Published var currentFiles: [FileMetadata] = []
    @Published var originalSubfolders: [Folder] = [] // Store the unfiltered subfolders
    @Published var filteredFileMetadata: [FileMetadata] = []
    @Published var subfolders: [Folder] = []
    
    @Published var isShowingDeleteAlert = false
    @Published var isShowingEditView = false
    @Published var isShowingFileImporter = false
    @Published var isImportingFile = false
    @Published var isShowingPhotoPicker = false
    // Dedicated flag for rename/caption UI
    @Published var isShowingRenameView = false
    
    // --- Single Item Delete State ---
    @Published var itemToDelete: AnyHashable? = nil
    @Published var isShowingSingleDeleteAlert = false {
        didSet {
            // When the alert is dismissed (either by confirm or cancel),
            // reset the itemToDelete.
            if !isShowingSingleDeleteAlert {
                itemToDelete = nil
            }
        }
    }
    
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
    
    @Published var selectedFilter: NoteFilter = .all
    
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
    @Published var selectedFolders: Set<Folder> = []
    @Published var isShowingMultiDeleteAlert = false
    
    // Computed property to disable the move button
    var isMoveButtonDisabled: Bool {
        // Disable if any folder is selected OR if no files are selected.
        return !selectedFolders.isEmpty || selectedFileMetadata.isEmpty
    }
    
    // --- Multi-Sharing State ---
    @Published var urlsToShare: [URL] = []
    @Published var isShowingMultiShareSheet = false
    
    
    // MARK: - Initializer
    
    init(subject: Subject, modelContext: ModelContext) {
        self.subject = subject
        self.modelContext = modelContext
        self.layoutStyleKey = "CardDetailView_LayoutStyle_\(subject.id.uuidString)"
        
        // Load saved layout style
        if let savedLayoutRawValue = UserDefaults.standard.string(forKey: layoutStyleKey),
           let savedLayout = LayoutStyle(rawValue: savedLayoutRawValue) {
            self.layoutStyle = savedLayout
        } else {
            self.layoutStyle = .grid // Default
        }
        
        FileDataService.migrateExistingFiles(for: subject, modelContext: modelContext)
        loadFolderContent()
        
        // ADDED: Load the saved note
        self.subjectNote = subject.ImportantTopicsNote
    }
    
    // MARK: - Sorting Method
    func selectSortOption(_ newSortType: SortType) {
        if sortType == newSortType {
            sortAscending.toggle()
        } else {
            sortType = newSortType
            sortAscending = false // Default to descending for date, ascending for name
        }
        loadFolderContent()
        performSearch() // Re-apply search with new sort
    }

    // ADDED: Function to save the note
    // MARK: - Subject Note
    
    func saveSubjectNote() {
        subject.ImportantTopicsNote = subjectNote
        do {
            try modelContext.save()
        } catch {
            print("Failed to save subject note: \(error)")
        }
    }

    // MARK: - Folder-based Methods
    
    func loadFolderContent() {
        let baseSubfolders: [Folder]
        let baseFiles: [FileMetadata]

        if let currentFolder = currentFolder {
            baseSubfolders = currentFolder.subfolders
            baseFiles = currentFolder.files
        } else {
            baseSubfolders = subject.rootFolders
            baseFiles = subject.fileMetadata.filter { $0.folder == nil }
        }

        // Apply sorting and store original list of folders
        self.originalSubfolders = sortFolders(baseSubfolders)
        self.subfolders = self.originalSubfolders
        currentFiles = sortFiles(baseFiles)
        
        filterFileMetadata()
    }
    
    // Helper to sort folders
    private func sortFolders(_ folders: [Folder]) -> [Folder] {
        return folders.sorted {
            let name1 = $0.name.lowercased()
            let name2 = $1.name.lowercased()
            return sortAscending ? name1 < name2 : name1 > name2
        }
    }
    
    // Helper to sort files
    private func sortFiles(_ files: [FileMetadata]) -> [FileMetadata] {
        return files.sorted {
            switch sortType {
            case .date:
                let date1 = $0.createdDate
                let date2 = $1.createdDate
                return sortAscending ? date1 < date2 : date1 > date2
            case .name:
                let name1 = $0.fileName.lowercased()
                let name2 = $1.fileName.lowercased()
                return sortAscending ? name1 < name2 : name1 > name2
            }
        }
    }
    
    func filterFileMetadata() {
        let showSearchAtRoot = isSearching && currentFolder == nil
        let filesToFilter = showSearchAtRoot ? searchResults : currentFiles
        
        // Always start with the original, unfiltered list of folders
        let foldersToFilter: [Folder] = showSearchAtRoot ? searchFolderResults : self.originalSubfolders

        switch selectedFilter {
        case .all:
            filteredFileMetadata = filesToFilter
            subfolders = foldersToFilter
        case .images:
            filteredFileMetadata = filesToFilter.filter { $0.fileType == .image }
            subfolders = showSearchAtRoot ? [] : foldersToFilter.filter { folder in
                !folder.files.filter { $0.fileType == .image }.isEmpty
            }
        case .pdfs:
            filteredFileMetadata = filesToFilter.filter { $0.fileType == .pdf }
            subfolders = showSearchAtRoot ? [] : foldersToFilter.filter { folder in
                !folder.files.filter { $0.fileType == .pdf }.isEmpty
            }
        case .docs:
            filteredFileMetadata = filesToFilter.filter { $0.fileType == .docx }
            subfolders = showSearchAtRoot ? [] : foldersToFilter.filter { folder in
                !folder.files.filter { $0.fileType == .docx }.isEmpty
            }
        case .favorites:
            if currentFolder == nil && !isSearching {
                filteredFileMetadata = sortFiles(subject.fileMetadata.filter { $0.isFavorite })
                let allFolders = allFoldersRecursively(from: subject.rootFolders)
                subfolders = sortFolders(allFolders.filter { $0.isFavorite })
            } else {
                // When in a folder, just filter the current content
                filteredFileMetadata = filesToFilter.filter { $0.isFavorite }
                subfolders = foldersToFilter.filter { $0.isFavorite }
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
    
    // MARK: - Single Item Delete Methods
    
    func promptForDelete(item: AnyHashable) {
        itemToDelete = item
        isShowingSingleDeleteAlert = true
    }

    func confirmDeleteItem() {
        if let folder = itemToDelete as? Folder {
            deleteFolder(folder)
        } else if let fileMetadata = itemToDelete as? FileMetadata {
            deleteFileMetadata(fileMetadata)
        }
        // itemToDelete is reset by the isShowingSingleDeleteAlert.didSet
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
        
        // Always search all files within the current subject.
        let filesToSearch = self.subject.fileMetadata
        let results = filesToSearch.filter { $0.fileName.lowercased().contains(query) }
        searchResults = sortFiles(results)

        // Search all folders (including nested) by name
        let allFolders = allFoldersRecursively(from: subject.rootFolders)
        searchFolderResults = sortFolders(allFolders.filter { $0.name.lowercased().contains(query) })
        
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
        var urlsToShare = selectedFileMetadata.compactMap { $0.getFileURL() }
        
        // Add files from selected folders
        for folder in selectedFolders {
            func recursivelyCollectFiles(from folder: Folder) {
                urlsToShare.append(contentsOf: folder.files.compactMap { $0.getFileURL() })
                for subfolder in folder.subfolders {
                    recursivelyCollectFiles(from: subfolder)
                }
            }
            recursivelyCollectFiles(from: folder)
        }
        
        guard !urlsToShare.isEmpty else { return }
        
        self.urlsToShare = urlsToShare
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
    
    // Computed property to check if all *visible* files are selected
    var allVisibleFilesSelected: Bool {
        // Can't be "all selected" if there are no files to select
        if filteredFileMetadata.isEmpty { return false }
        
        // Create a Set of visible file IDs for efficient checking
        let visibleFileIDs = Set(filteredFileMetadata.map { $0.id })
        // Create a Set of selected file IDs
        let selectedFileIDs = Set(selectedFileMetadata.map { $0.id })
        
        // Check if the selected IDs contain all the visible IDs
        return selectedFileIDs.isSuperset(of: visibleFileIDs)
    }
    
    func toggleSelectAllFiles() {
        if allVisibleFilesSelected {
            // Deselect all visible files
            selectedFileMetadata.subtract(filteredFileMetadata)
        } else {
            // Select all visible files
            selectedFileMetadata.formUnion(filteredFileMetadata)
        }
    }
    
    func toggleEditMode() {
        isEditing.toggle()
        if !isEditing {
            selectedFileMetadata.removeAll()
            selectedFolders.removeAll()
        }
    }

    func deleteSelectedItems() {
        let metadataToDelete = selectedFileMetadata
        for metadata in metadataToDelete {
            deleteFileMetadata(metadata)
        }
        
        let foldersToDelete = selectedFolders
        for folder in foldersToDelete {
            deleteFolder(folder)
        }
        
        DispatchQueue.main.async {
            self.selectedFileMetadata.removeAll()
            self.selectedFolders.removeAll()
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
    
    func toggleSelectionForFolder(_ folder: Folder) {
        if selectedFolders.contains(folder) {
            selectedFolders.remove(folder)
        } else {
            selectedFolders.insert(folder)
        }
    }
}

