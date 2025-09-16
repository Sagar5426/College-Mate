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
        .background(LinearGradient(colors: [.gray.opacity(0.1), .black.opacity(0.1), .gray.opacity(0.07)], startPoint: .top, endPoint: .bottom))
        .alert("Rename File", isPresented: .constant(viewModel.renamingFileMetadata != nil)) {
            renameAlertContent
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
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.isEditing {
                    Button("Cancel") {
                        viewModel.toggleEditMode()
                    }
                } else {
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
        .alert("Rename File", isPresented: .constant(viewModel.renamingFileMetadata != nil)) {
            TextField("New Name", text: $viewModel.newFileName)
            Button("Cancel", role: .cancel) {
                viewModel.renamingFileMetadata = nil
            }
            Button("Save") {
                viewModel.renameFile()
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
                onDismiss: { viewModel.documentToPreview = nil },
                onShare: {
                    viewModel.urlToShare = document.url
                    viewModel.isShowingShareSheet = true
                }
            )
        }
        .sheet(isPresented: $viewModel.isShowingShareSheet) {
            if let url = viewModel.urlToShare {
                ShareSheetView(activityItems: [url])
            }
        }
        .fullScreenCover(isPresented: $viewModel.isShowingCamera) {
            ImagePicker(sourceType: .camera, onImageSelected: viewModel.handleImageSelected)
        }
        .fullScreenCover(isPresented: $viewModel.isShowingCropper) {
            if let imageToCrop = viewModel.imageToCrop {
                ImageCropperView(image: imageToCrop, onCrop: viewModel.handleCroppedImage, isPresented: $viewModel.isShowingCropper)
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
            HStack(spacing: 12) {
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
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3)) {
                if !viewModel.isSearching {
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
                }
                
                ForEach(viewModel.filteredFileMetadata, id: \.id) { fileMetadata in
                    fileMetadataView(for: fileMetadata)
                        .onTapGesture { handleTapForMetadata(fileMetadata) }
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical)
            .padding(.horizontal)
            Spacer(minLength: 100)
        }
    }
    
    private func folderView(for folder: Folder) -> some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 80, height: 60)
                
                Image(systemName: "folder.fill")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                
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
                .frame(maxWidth: 100)
            
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
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: "photo.fill")
                            .font(.largeTitle)
                            .foregroundColor(.green)
                            .frame(width: 80, height: 80)
                            .background(Color.green.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                case .pdf:
                     if let fileURL = fileMetadata.getFileURL(), let pdfThumbnail = viewModel.generatePDFThumbnail(from: fileURL) {
                        Image(uiImage: pdfThumbnail)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(radius: 2)
                    } else {
                        Image(systemName: "doc.richtext.fill")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                            .frame(width: 80, height: 80)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                case .docx:
                    if let fileURL = fileMetadata.getFileURL() {
                        DocxThumbnailView(fileURL: fileURL, viewModel: viewModel)
                    } else {
                         Image(systemName: "doc.text.fill")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                            .frame(width: 80, height: 80)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                case .unknown:
                    Image(systemName: "doc.fill")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                        .frame(width: 80, height: 80)
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
            .frame(width: 80, height: 80)
            
            Text(fileMetadata.fileName)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: 100)
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
            viewModel.toggleFavorite(for: folder)
        } label: {
            Label(folder.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                  systemImage: folder.isFavorite ? "heart.slash" : "heart")
        }

        Button {
            // Rename folder functionality
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
            viewModel.showFolderPicker(for: fileMetadata)
        } label: {
            Label("Move to Folder", systemImage: "folder")
        }
        
        Button {
            viewModel.renamingFileMetadata = fileMetadata
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        
        Button(role: .destructive) {
            viewModel.deleteFileMetadata(fileMetadata)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    
    private var renameAlertContent: some View {
        Group {
            TextField("New Name", text: $viewModel.newFileName)
            Button("Cancel", role: .cancel) { viewModel.renamingFileMetadata = nil }
            Button("Save") { viewModel.renameFile() }
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
                .font(.title.weight(.semibold))
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(Circle())
                .shadow(radius: 4, x: 0, y: 2)
        }
        .padding()
        .transition(.scale.combined(with: .opacity))
        .frame(maxWidth: .infinity, alignment: .bottomTrailing)
    }
    
    private var editingBottomBar: some View {
        HStack(spacing: 16) {
            // Move Button
            Button {
                viewModel.showFolderPickerForSelection()
            } label: {
                Label("Move", systemImage: "folder")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.selectedFileMetadata.isEmpty ? Color.gray : Color.blue)
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
        .padding(.horizontal)
        .padding(.bottom, 8)
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
        SoundManager.shared.playDeleteSound()
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
    let onShare: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .topTrailing) {
                DocumentPreviewView(url: document.url)
                    .ignoresSafeArea()
                    .toolbar {
                        ToolbarItem(placement: .bottomBar) {
                            Button(action: onShare) {
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
            .interactiveDismissDisabled()
        }
    }
}


// MARK: - DocxThumbnailView
struct DocxThumbnailView: View {
    let fileURL: URL
    @ObservedObject var viewModel: CardDetailViewModel
    
    @State private var thumbnail: UIImage? = nil
    
    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 2)
            } else {
                Image(systemName: "doc.text.fill")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
                    .frame(width: 80, height: 80)
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

