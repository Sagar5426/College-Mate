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
        viewBodyContent
            .alert(viewModel.renamingFileMetadata?.fileType == .image ? "Add Caption" : "Rename File", isPresented: $viewModel.isShowingRenameView) {
                if viewModel.renamingFileMetadata?.fileType == .image {
                    TextField("e.g. Important Formulas", text: $viewModel.newFileName)
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
    
    private var viewBodyContent: some View {
        VStack(spacing: 0) {
            if viewModel.isSearchBarVisible {
                searchBarView
            }
            filterView
            breadcrumbView
            Divider()
            contentView
        }
        .background(LinearGradient.appBackground.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if viewModel.isEditing {
                editingBottomBar
            } else {
                addButton
            }
        }
    }
    
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
        
        VStack(alignment: .leading, spacing: gridSpacing) {
            HStack(spacing: gridSpacing) {
                Menu {
                    Picker("Filter", selection: $viewModel.selectedFilter) {
                        ForEach(NoteFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }

                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease")
                        Text(viewModel.selectedFilter.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                }
                
                Spacer()
                
                Menu {
                    // Sorting Options
                    Button(action: { viewModel.selectSortOption(.date) }) {
                          HStack {
                              Text(CardDetailViewModel.SortType.date.rawValue)
                              Spacer()
                              if viewModel.sortType == .date {
                                  Image(systemName: viewModel.sortAscending ? "chevron.up" : "chevron.down")
                              }
                          }
                    }
                   Button(action: { viewModel.selectSortOption(.name) }) {
                       HStack {
                           Text(CardDetailViewModel.SortType.name.rawValue)
                           Spacer()
                           if viewModel.sortType == .name {
                               Image(systemName: viewModel.sortAscending ? "chevron.up" : "chevron.down")
                           }
                       }
                   }

                    if !viewModel.filteredFileMetadata.isEmpty {
                        Divider()
                        Button {
                            viewModel.toggleEditMode()
                        } label: {
                            Label("Select Files", systemImage: "checkmark.circle")
                        }
                    }

                    Divider()

                    // Layout Picker
                    Picker("Layout", selection: $viewModel.layoutStyle) {
                        Label("Grid", systemImage: "square.grid.2x2")
                            .tag(CardDetailViewModel.LayoutStyle.grid)
                        Label("List", systemImage: "list.bullet")
                            .tag(CardDetailViewModel.LayoutStyle.list)
                    }
                    .pickerStyle(.inline)
                    
                } label: {
                    Image(systemName: viewModel.layoutStyle.rawValue == "Grid" ? "square.grid.2x2" : "list.bullet")
                }

            }
            
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
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
                if viewModel.layoutStyle == .grid {
                    enhancedGrid
                } else {
                    enhancedList
                }
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
                    switch viewModel.selectedFilter {
                    case .all:
                        NoNotesView(
                            imageName: "doc.text.magnifyingglass",
                            title: "No Files Added",
                            message: "Click on the add button to start adding files."
                        )
                    case .images:
                        NoNotesView(
                            imageName: "photo.on.rectangle.angled",
                            title: "No Images",
                            message: "Click on the add button to start adding images from your photos or camera."
                        )
                    case .pdfs:
                        NoNotesView(
                            imageName: "doc.richtext",
                            title: "No PDFs",
                            message: "Click on the add button to import PDF documents."
                        )
                    case .docs:
                        NoNotesView(
                            imageName: "doc.text",
                            title: "No Documents",
                            message: "Click on the add button to import Word documents."
                        )
                    case .favorites:
                        NoNotesView(
                            imageName: "heart.slash",
                            title: "No Favorites",
                            message: "You haven't added any files or folders to your favorites yet."
                        )
                    }
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

    private var enhancedList: some View {
        List {
            ForEach(viewModel.subfolders, id: \.id) { folder in
                folderRow(for: folder)
            }
            
            ForEach(viewModel.filteredFileMetadata, id: \.id) { fileMetadata in
                fileRow(for: fileMetadata)
            }
            // Custom spacer to prevent overlap with the bottom bar/button
                        Color.clear
                            .frame(height: 120)
                            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
    }

    private func folderRow(for folder: Folder) -> some View {
        HStack {
            Image(systemName: "folder.fill")
                .font(.title)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading) {
                Text(folder.name)
                    .font(.headline)
                Text("\(folder.files.count) files")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if folder.isFavorite {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !viewModel.isEditing {
                playNavigationHaptic()
                viewModel.navigateToFolder(folder)
            }
        }
        .contextMenu {
            if !viewModel.isEditing {
                folderContextMenu(for: folder)
            }
        }
    }
    
    private func fileRow(for fileMetadata: FileMetadata) -> some View {
        HStack {
            listThumbnail(for: fileMetadata)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading) {
                if fileMetadata.fileType == .image && isPlaceholderImageName(fileMetadata.fileName) {
                    Text("Image")
                        .font(.headline)
                        .lineLimit(1)
                } else {
                    Text((fileMetadata.fileName as NSString).deletingPathExtension)
                        .font(.headline)
                        .lineLimit(1)
                }
                Text(fileMetadata.createdDate, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if fileMetadata.isFavorite {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            handleTapForMetadata(fileMetadata)
        }
        .contextMenu {
            if !viewModel.isEditing {
                fileMetadataContextMenu(for: fileMetadata)
            }
        }
        .selectionOverlay(isSelected: viewModel.selectedFileMetadata.contains(fileMetadata), isEditing: viewModel.isEditing)
    }

    @ViewBuilder
    private func listThumbnail(for fileMetadata: FileMetadata) -> some View {
        ZStack {
            switch fileMetadata.fileType {
            case .image:
                if let fileURL = fileMetadata.getFileURL(),
                   let imageData = try? Data(contentsOf: fileURL),
                   let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Image(systemName: "photo.fill")
                }
            case .pdf:
                Image(systemName: "doc.richtext.fill")
                    .font(.title)
                    .foregroundColor(.red)
            case .docx:
                Image(systemName: "doc.text.fill")
                    .font(.title)
                    .foregroundColor(.blue)
            case .unknown:
                Image(systemName: "doc.fill")
                    .font(.title)
                    .foregroundColor(.gray)
            }
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
            viewModel.toggleFavorite(for: fileMetadata)
        } label: {
            Label(fileMetadata.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                  systemImage: fileMetadata.isFavorite ? "heart.slash" : "heart")
        }
        
        Button {
            viewModel.renamingFileMetadata = fileMetadata
        } label: {
            if fileMetadata.fileType == .image {
                Label("Add Caption", systemImage: "pencil")
            } else {
                Label("Rename", systemImage: "pencil")
            }
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
                    .allowsHitTesting(false)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .blue)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(4)
                        .allowsHitTesting(false)
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
    let base = (lower as NSString).deletingPathExtension

    // 1) Explicit default name
    if base == "default" { return true }

    // 2) App-generated pattern: image_<uuid>-like (strict regex)
    // Accepts common UUID-ish segments (8+ hex/dash characters)
    if base.range(of: #"^image_[0-9a-f-]{8,}$"#, options: [.regularExpression]) != nil {
        return true
    }

    // 3) Classic camera names only when the whole string matches a known pattern
    //    Examples: IMG_1234, IMG-20231009, img12345
    if base.range(of: #"^(?i:img)[_-]?\d{3,}$"#, options: [.regularExpression]) != nil {
        return true
    }

    // Do NOT block short, numeric, or other user-provided captions.
    return false
}

#Preview("Card Detail Preview") {
    if let container = try? ModelContainer(for: Subject.self, Folder.self, FileMetadata.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)) {
        let context = container.mainContext
        let subject = Subject(name: "Physics", startDateOfSubject: Date(), schedules: [])
        context.insert(subject)

        let notesFolder = Folder(name: "Notes", parentFolder: nil, subject: subject)
        let refsFolder = Folder(name: "References", parentFolder: nil, subject: subject)
        context.insert(notesFolder)
        context.insert(refsFolder)

        // Ensure the subject's root directory exists before saving files to it
        _ = FileDataService.subjectFolder(for: subject)

        func writeMockFile(named fileName: String, data: Data, folder: Folder?) {
            _ = FileDataService.saveFile(
                data: data,
                fileName: fileName,
                to: folder,
                in: subject,
                modelContext: context
            )
        }

        let tinyJPEG: Data = Data([0xFF, 0xD8, 0xFF, 0xDB, 0x00, 0x43, 0x00, 0xFF, 0xD9])
        let tinyPDF: Data = Data([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34, 0x0A])
        let tinyDOCX: Data = Data([0x50, 0x4B, 0x03, 0x04])

        writeMockFile(named: "image_\(UUID().uuidString).jpg", data: tinyJPEG, folder: notesFolder)
        writeMockFile(named: "Syllabus.pdf", data: tinyPDF, folder: refsFolder)
        writeMockFile(named: "Assignment.docx", data: tinyDOCX, folder: nil)

        return AnyView(
            NavigationStack {
                CardDetailView(subject: subject, modelContext: context)
            }
            .modelContainer(container)
        )
    } else {
        return AnyView(Text("Failed to create preview container."))
    }
}
