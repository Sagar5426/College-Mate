import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers
import QuickLook

// MARK: - CardDetailView
struct CardDetailView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel: CardDetailViewModel
    @FocusState private var isSearchFocused: Bool
    
    @State private var isShowingRenameFolderAlert: Bool = false
    @State private var folderBeingRenamed: Folder? = nil
    @State private var newFolderNameForRename: String = ""
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private var tileSize: CGFloat { isPad ? 120 : 80 }
    private var gridSpacing: CGFloat { isPad ? 16 : 12 }
    private var gridColumns: [GridItem] {
        if isPad {
            return [GridItem(.adaptive(minimum: tileSize), spacing: gridSpacing)]
        } else {
            return Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: 3)
        }
    }
    
    init(subject: Subject, modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: CardDetailViewModel(subject: subject, modelContext: modelContext))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isSearchBarVisible {
                searchBarView
            }
            filterView
            breadcrumbView
            Divider()
            contentView
        }
        .background(Color(.systemGroupedBackground))
        .alert(viewModel.renamingFileMetadata?.fileType == .image ? "Add Caption" : "Rename File", isPresented: .constant(viewModel.renamingFileMetadata != nil)) {
            if viewModel.renamingFileMetadata?.fileType == .image {
                TextField("e.g. Maths Formula", text: $viewModel.newFileName)
            } else {
                TextField("New Name", text: $viewModel.newFileName)
            }
            Button("Cancel", role: .cancel) {
                viewModel.renamingFileMetadata = nil
            }
            Button("Save") {
                viewModel.renameFile()
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.isEditing {
                editingBottomBar
            } else {
                addButton
            }
        }
        .navigationTitle(viewModel.subject.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.isEditing {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: { viewModel.shareSelectedFiles() }) {
                        Image(systemName: "square.and.arrow.up")
                            .frame(width: 24, height: 24)
                    }
                    .disabled(viewModel.selectedFileMetadata.isEmpty)
                    .opacity(viewModel.selectedFileMetadata.isEmpty ? 0 : 1)
                    .accessibilityHidden(viewModel.selectedFileMetadata.isEmpty)
                    
                    Button("Cancel") {
                        viewModel.toggleEditMode()
                    }
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) {
                                viewModel.toggleSearchBarVisibility()
                            }
                            isSearchFocused.toggle()
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        
                        Menu {
                            if !viewModel.filteredFileMetadata.isEmpty {
                                Button {
                                    viewModel.toggleEditMode()
                                } label: {
                                    Label("Select Files", systemImage: "checkmark.circle")
                                }
                            }
                            
                            Button {
                                viewModel.isShowingEditView.toggle()
                            } label: {
                                Label("Edit Subject", systemImage: "pencil")
                            }
                            
                            Button(role: .destructive) {
                                triggerHapticFeedback()
                                viewModel.isShowingDeleteAlert = true
                            } label: {
                                Label("Delete Subject", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .alert("Delete this Subject", isPresented: $viewModel.isShowingDeleteAlert) {
            deleteAlertContent
        } message: {
            Text("Deleting this subject will remove all associated data. Are you sure?")
        }
        .alert("Delete \(viewModel.selectedFileMetadata.count) files?", isPresented: $viewModel.isShowingMultiDeleteAlert) {
            Button("Delete", role: .destructive) { viewModel.deleteSelectedFiles() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Create New Folder", isPresented: $viewModel.isShowingCreateFolderAlert) {
            TextField("Folder Name", text: $viewModel.newFolderName)
            Button("Create") {
                viewModel.createFolder(named: viewModel.newFolderName)
                viewModel.newFolderName = ""
            }
            Button("Cancel", role: .cancel) {
                viewModel.newFolderName = ""
            }
        } message: {
            Text("Enter a name for the new folder")
        }
        .alert("Rename Folder", isPresented: $isShowingRenameFolderAlert) {
            TextField("Folder Name", text: $newFolderNameForRename)
            Button("Save") {
                if let folder = folderBeingRenamed {
                    folder.name = newFolderNameForRename.trimmingCharacters(in: .whitespacesAndNewlines)
                    do {
                        try modelContext.save()
                    } catch {
                        // Handle save error if needed
                    }
                }
                folderBeingRenamed = nil
                newFolderNameForRename = ""
            }
            Button("Cancel", role: .cancel) {
                folderBeingRenamed = nil
                newFolderNameForRename = ""
            }
        }
        .fileImporter(
            isPresented: $viewModel.isShowingFileImporter,
            allowedContentTypes: [
                UTType.pdf,
                UTType(filenameExtension: "docx")!
            ],
            allowsMultipleSelection: true,
            onCompletion: viewModel.handleFileImport
        )
        .fullScreenCover(item: $viewModel.documentToPreview) { document in
            // This is the new part for the Share Sheet
            PreviewWithShareView(
                document: document,
                onDismiss: { viewModel.documentToPreview = nil }
            )
        }
        .sheet(isPresented: $viewModel.isShowingMultiShareSheet) {
            ShareSheetView(activityItems: viewModel.urlsToShare)
        }
        .fullScreenCover(isPresented: $viewModel.isShowingCamera) {
            ImagePicker(sourceType: .camera, onImageSelected: viewModel.handleImageSelected)
        }
        .fullScreenCover(isPresented: $viewModel.isShowingCropper) {
            if let imageToCrop = viewModel.imageToCrop {
                ImageCropService(image: imageToCrop, onCrop: viewModel.handleCroppedImage, isPresented: $viewModel.isShowingCropper)
            }
        }
        .fullScreenCover(isPresented: $viewModel.isShowingEditView) {
            EditSubjectView(subject: viewModel.subject, isShowingEditSubjectView: $viewModel.isShowingEditView)
        }
        .photosPicker(
            isPresented: $viewModel.isShowingPhotoPicker,
            selection: $viewModel.selectedPhotoItems,
            matching: .images
        )
        .onChange(of: viewModel.selectedFilter) {
            viewModel.filterFileMetadata()
        }
        .sheet(isPresented: $viewModel.isShowingFolderPicker) {
            FolderPickerView(
                subjectName: viewModel.subject.name,
                folders: viewModel.availableFolders,
                onFolderSelected: { folder in
                    viewModel.moveSelectedFiles(to: folder)
                    viewModel.isShowingFolderPicker = false
                },
                onCancel: {
                    viewModel.isShowingFolderPicker = false
                }
            )
        }
    }
    
    // MARK: - Subviews
    
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search in \(viewModel.subject.name)...", text: $viewModel.searchText)
                .focused($isSearchFocused)
                .onSubmit { viewModel.performSearch() }
                .onChange(of: viewModel.searchText) { viewModel.performSearch() }
            
            if !viewModel.searchText.isEmpty {
                Button(action: viewModel.clearSearch) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .zIndex(1) // Ensures search bar animates over other content
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    private var filterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: gridSpacing) {
                ForEach(NoteFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        playTapSoundAndVibrate()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedFilter = filter
                        }
                    }) {
                        Text(filter.rawValue)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(viewModel.selectedFilter == filter ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundColor(viewModel.selectedFilter == filter ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }
    
    private var breadcrumbView: some View {
        Group {
            if !viewModel.folderPath.isEmpty || viewModel.isSearching {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if viewModel.isSearching {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                Text("Search Results for \"\(viewModel.searchText)\"")
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                        } else {
                            Button(action: viewModel.navigateToRoot) {
                                HStack {
                                    Image(systemName: "house.fill")
                                    Text(viewModel.subject.name)
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(viewModel.folderPath.isEmpty ? Color.blue : Color.gray.opacity(0.3))
                                .foregroundColor(viewModel.folderPath.isEmpty ? .white : .primary)
                                .clipShape(Capsule())
                            }
                            
                            ForEach(Array(viewModel.folderPath.enumerated()), id: \.element.id) { index, folder in
                                HStack {
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    
                                    Button(action: {
                                        viewModel.navigateToFolder(at: index)
                                    }) {
                                        Text(folder.name)
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(index == viewModel.folderPath.count - 1 ? Color.blue : Color.gray.opacity(0.3))
                                            .foregroundColor(index == viewModel.folderPath.count - 1 ? .white : .primary)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        ZStack {
            if viewModel.filteredFileMetadata.isEmpty && viewModel.subfolders.isEmpty {
                noNotesView
            } else {
                enhancedGrid
            }
            
            if viewModel.isImportingFile {
                importingOverlay
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }
    
    private var importingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            ProgressView("Importing...").progressViewStyle(.circular).scaleEffect(1.5)
                .tint(.white)
        }
    }
    
    private var noNotesView: some View {
        ScrollView {
            VStack {
                Spacer(minLength: UIScreen.main.bounds.height / 6)
                if viewModel.isSearching {
                    Text("No results found for \"\(viewModel.searchText)\"")
                        .font(.headline)
                        .foregroundColor(.secondary)
                } else {
                    NoNotesView()
                }
                Spacer()
            }
        }
    }
    
    private var enhancedGrid: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: gridSpacing) {
                ForEach(viewModel.subfolders, id: \.id) { folder in
                    folderView(for: folder)
                        .onTapGesture {
                            if viewModel.isEditing {
                                // Folder selection in edit mode is not supported
                            } else {
                                playNavigationHaptic()
                                viewModel.navigateToFolder(folder)
                            }
                        }
                }
                
                ForEach(viewModel.filteredFileMetadata, id: \.id) { fileMetadata in
                    fileMetadataView(for: fileMetadata)
                        .onTapGesture { handleTapForMetadata(fileMetadata) }
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical)
            .padding(.horizontal)
            Spacer(minLength: 170)
        }
    }
    
    private func folderView(for folder: Folder) -> some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: tileSize, height: tileSize * 0.75)
                
                FilesFolderIcon(size: tileSize)
                
                if folder.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(3)
                        .background(.thinMaterial)
                        .clipShape(Circle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(4)
                }
            }
            
            Text(folder.name)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: tileSize + 20)
            
            Text("\(folder.files.count) files")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .contextMenu {
            if !viewModel.isEditing {
                folderContextMenu(for: folder)
            }
        }
    }
    
    private func fileMetadataView(for fileMetadata: FileMetadata) -> some View {
        VStack {
            ZStack(alignment: .bottom) {
                // File icon/thumbnail based on type
                switch fileMetadata.fileType {
                case .image:
                    if let fileURL = fileMetadata.getFileURL(),
                       let imageData = try? Data(contentsOf: fileURL),
                       let image = UIImage(data: imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: tileSize, height: tileSize)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: "photo.fill")
                            .font(.largeTitle)
                            .foregroundColor(.green)
                            .frame(width: tileSize, height: tileSize)
                            .background(Color.green.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                case .pdf:
                    if let fileURL = fileMetadata.getFileURL(), let pdfThumbnail = viewModel.generatePDFThumbnail(from: fileURL) {
                        Image(uiImage: pdfThumbnail)
                            .resizable()
                            .scaledToFit()
                            .frame(width: tileSize, height: tileSize)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(radius: 2)
                    } else {
                        Image(systemName: "doc.richtext.fill")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                            .frame(width: tileSize, height: tileSize)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                case .docx:
                    if let fileURL = fileMetadata.getFileURL() {
                        DocxThumbnailView(fileURL: fileURL, viewModel: viewModel, size: tileSize)
                    } else {
                        Image(systemName: "doc.text.fill")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                            .frame(width: tileSize, height: tileSize)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                case .unknown:
                    Image(systemName: "doc.fill")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                        .frame(width: tileSize, height: tileSize)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Favorite indicator
                if fileMetadata.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(3)
                        .background(.thinMaterial)
                        .clipShape(Circle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(4)
                }
            }
            .frame(width: tileSize, height: tileSize)
            
            // Never show image names; show names only for non-image files
            if fileMetadata.fileType != .image {
                Text((fileMetadata.fileName as NSString).deletingPathExtension)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
        .contextMenu {
            if !viewModel.isEditing {
                fileMetadataContextMenu(for: fileMetadata)
            }
        }
        .selectionOverlay(
            isSelected: viewModel.selectedFileMetadata.contains(fileMetadata),
            isEditing: viewModel.isEditing
        )
    }
    
    private func handleTapForMetadata(_ fileMetadata: FileMetadata) {
        if viewModel.isEditing {
            viewModel.toggleSelectionForMetadata(fileMetadata)
        } else {
            if let fileURL = fileMetadata.getFileURL() {
                viewModel.documentToPreview = PreviewableDocument(url: fileURL)
            }
        }
    }
    
    @ViewBuilder
    private func folderContextMenu(for folder: Folder) -> some View {
        Button {
            viewModel.shareFolder(folder)
        } label: {
            Label("Share Folder", systemImage: "square.and.arrow.up")
        }
        
        Button {
            viewModel.toggleFavorite(for: folder)
        } label: {
            Label(folder.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                  systemImage: folder.isFavorite ? "heart.slash" : "heart")
        }

        Button {
            folderBeingRenamed = folder
            newFolderNameForRename = folder.name
            isShowingRenameFolderAlert = true
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        
        Button(role: .destructive) {
            viewModel.deleteFolder(folder)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    
    @ViewBuilder
    private func fileMetadataContextMenu(for fileMetadata: FileMetadata) -> some View {
        Button {
            if let url = fileMetadata.getFileURL() {
                // Prepare single-file share using existing ShareSheetView
                viewModel.urlsToShare = [url]
                viewModel.isShowingMultiShareSheet = true
            }
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        
        Divider()
        
        Button {
            viewModel.toggleFavorite(for: fileMetadata)
        } label: {
            Label(fileMetadata.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                  systemImage: fileMetadata.isFavorite ? "heart.slash" : "heart")
        }
        
        Button {
            if fileMetadata.fileType == .image {
                viewModel.newFileName = "" // start empty so user types caption
            }
            viewModel.renamingFileMetadata = fileMetadata
        } label: {
            if fileMetadata.fileType == .image {
                Label("Add Caption", systemImage: "pencil")
            } else {
                Label("Rename", systemImage: "pencil")
            }
        }
        
        Button(role: .destructive) {
            viewModel.deleteFileMetadata(fileMetadata)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    
    private var addButton: some View {
        Menu {
            if viewModel.currentFolder == nil {
                Button("New Folder", systemImage: "folder.badge.plus") {
                    viewModel.isShowingCreateFolderAlert = true
                }
            }
            Button("Camera", systemImage: "camera.fill") { viewModel.isShowingCamera = true }
            Button("Images from Photos", systemImage: "photo.on.rectangle.angled") {
                viewModel.isShowingPhotoPicker = true
            }
            Button("Document from Files", systemImage: "doc.fill") { viewModel.isShowingFileImporter = true }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 60, height: 60)
                .background(
                    ZStack {
                        // Base frosted glass
                        Circle().fill(.ultraThinMaterial)
                        
                        // Subtle tint to give the glass a hue
                        Circle().fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.08), Color.blue.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        
                        // Inner highlight (specular)
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.55), Color.white.opacity(0.2), .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                ),
                                lineWidth: 1.2
                            )
                            .blur(radius: 0.5)
                            .blendMode(.plusLighter)
                        
                        // Inner shadow ring to add depth
                        Circle()
                            .stroke(Color.black.opacity(0.15), lineWidth: 1)
                            .blur(radius: 1.2)
                            .opacity(0.6)
                    }
                )
                .overlay(
                    // Glass rim
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.45), Color.white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.6
                        )
                )
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                .shadow(color: Color.blue.opacity(0.18), radius: 16, x: 0, y: 6)
                .contentShape(Circle())
                .padding(14)
                .compositingGroup()
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                .animation(.easeInOut(duration: 0.15), value: viewModel.isEditing)
                .accessibilityLabel("Add")
        }
        .padding()
        .transition(.scale.combined(with: .opacity))
        .frame(maxWidth: .infinity, alignment: .bottomTrailing)
    }
    
    private var editingBottomBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Move Button
                Button {
                    viewModel.showFolderPickerForSelection()
                } label: {
                    Label("Move", systemImage: "folder")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.selectedFileMetadata.isEmpty ? Color.gray : Color.orange)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .disabled(viewModel.selectedFileMetadata.isEmpty)
                
                // Delete Button
                Button(role: .destructive) {
                    viewModel.isShowingMultiDeleteAlert = true
                } label: {
                    Label("Delete (\(viewModel.selectedFileMetadata.count))", systemImage: "trash")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.selectedFileMetadata.isEmpty ? Color.gray : Color.red)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .disabled(viewModel.selectedFileMetadata.isEmpty)
            }
        }
        .padding()
        .background(.thinMaterial) // Adding a background for better visual separation
        .transition(.move(edge: .bottom))
    }
    
    private var deleteAlertContent: some View {
        Button("Delete", role: .destructive) {
            playDeleteSound()
            viewModel.deleteSubject { dismiss() }
        }
    }
    
    // MARK: - Feedback Helpers
    
    private func triggerHapticFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
    
    private func playDeleteSound() {
        SoundService.shared.playDeleteSound()
    }

    private func playTapSoundAndVibrate() {
        // Haptic feedback for selection change
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Play a more audible system tap sound
        AudioServicesPlaySystemSound(1306)
    }
    
    private func playNavigationHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - PreviewWithShareView
struct PreviewWithShareView: View {
    let document: PreviewableDocument
    let onDismiss: () -> Void
    
    @State private var isShowingShareSheet = false
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .topTrailing) {
                DocumentPreviewView(url: document.url)
                    .ignoresSafeArea()
                    .toolbar {
                        ToolbarItem(placement: .bottomBar) {
                            Button(action: { isShowingShareSheet = true }) {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        ToolbarItem(placement: .bottomBar) {
                            Spacer() // To push the share button to the left
                        }
                    }

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.largeTitle)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.black, Color(.systemGray5).opacity(0.8))
                }
                .padding()
            }
        }
        // This modifier prevents the sheet from being dismissed by swiping down
        .interactiveDismissDisabled()
        .sheet(isPresented: $isShowingShareSheet) {
            ShareSheetView(activityItems: [document.url])
        }
    }
}


// MARK: - DocxThumbnailView
struct DocxThumbnailView: View {
    let fileURL: URL
    @ObservedObject var viewModel: CardDetailViewModel
    let size: CGFloat
    
    @State private var thumbnail: UIImage? = nil
    
    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 2)
            } else {
                Image(systemName: "doc.text.fill")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                    .frame(width: size, height: size)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .onAppear {
            viewModel.generateDocxThumbnail(from: fileURL) { image in
                self.thumbnail = image
            }
        }
    }
}

// MARK: - Files-style Folder Icon
struct FilesFolderIcon: View {
    var size: CGFloat

    var body: some View {
        // Size the icon slightly smaller than the tile
        let iconSize = size * 0.62
        ZStack {
            // Base filled folder with a blue gradient, similar to Files app
            Image(systemName: "folder.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.74, green: 0.86, blue: 1.0), // light blue top
                            Color(red: 0.20, green: 0.56, blue: 1.0)  // deeper blue bottom
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.blue.opacity(0.25), radius: 6, x: 0, y: 3)

            // Subtle top highlight to give a modern glossy feel
            Image(systemName: "folder.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.white.opacity(0.45), Color.white.opacity(0.15), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .blendMode(.plusLighter)
                .opacity(0.8)
        }
        .accessibilityHidden(true)
    }
}


// MARK: - SelectionOverlay
struct SelectionOverlay: ViewModifier {
    let isSelected: Bool
    let isEditing: Bool

    func body(content: Content) -> some View {
        ZStack {
            content
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                )
            if isEditing {
                Rectangle()
                    .fill(Color.black.opacity(isSelected ? 0.2 : 0))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .blue)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(4)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: isEditing)
    }
}

extension View {
    func selectionOverlay(isSelected: Bool, isEditing: Bool) -> some View {
        self.modifier(SelectionOverlay(isSelected: isSelected, isEditing: isEditing))
    }
}

// MARK: - DocumentPreviewView & ShareSheet
struct DocumentPreviewView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let parent: DocumentPreviewView

        init(parent: DocumentPreviewView) {
            self.parent = parent
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return parent.url as QLPreviewItem
        }
    }
}

struct ShareSheetView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}


// MARK: - ImagePicker
struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType
    var onImageSelected: (UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) { self.parent = parent }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageSelected(image)
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onImageSelected(nil)
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - FolderPickerView
struct FolderPickerView: View {
    let subjectName: String
    let folders: [Folder]
    let onFolderSelected: (Folder?) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                Button(action: {
                    onFolderSelected(nil) // `nil` represents the root
                }) {
                    HStack {
                        Image(systemName: "house.fill")
                            .foregroundColor(.blue)
                        Text(subjectName) // Show Subject name for root
                        Spacer()
                    }
                }
                
                ForEach(folders, id: \.id) { folder in
                    Button(action: {
                        onFolderSelected(folder)
                    }) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                            Text(folder.name) // Just show the folder name, not the full path
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Move to Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
}


// MARK: - Helper function for placeholder image names

private func isPlaceholderImageName(_ fileName: String) -> Bool {
    let lower = fileName.lowercased()
    // Strip extension
    let base = (lower as NSString).deletingPathExtension

    // 1) Explicit default name
    if base == "default" { return true }

    // 2) Auto-generated patterns we create in this app
    //    e.g., image_<uuid>.jpg
    if base.hasPrefix("image_") { return true }

    // 3) Common camera patterns (imported from Photos or elsewhere)
    //    e.g., img_1234, img_20231009, img-1234, img1234
    if base.hasPrefix("img_") || base.hasPrefix("img-") || base.hasPrefix("img") { return true }

    // 4) Very short or meaningless names like "y", "x", etc. (length <= 2)
    if base.count <= 2 { return true }

    // 5) Mostly numeric or UUID-like (heuristic)
    let digits = base.filter { $0.isNumber }.count
    if digits >= max(4, base.count - 2) { return true }

    return false
}

