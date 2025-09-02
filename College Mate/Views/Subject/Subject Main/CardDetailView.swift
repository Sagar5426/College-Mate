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
    
    init(subject: Subject, modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: CardDetailViewModel(subject: subject, modelContext: modelContext))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            filterView
            Divider()
            contentView
        }
        .background(LinearGradient(colors: [.gray.opacity(0.1), .black.opacity(0.1), .gray.opacity(0.07)], startPoint: .top, endPoint: .bottom))
        .alert("Rename File", isPresented: .constant(viewModel.renamingFileURL != nil)) {
            renameAlertContent
        }
        .overlay(alignment: .bottom) {
            if viewModel.isEditing {
                deleteSelectedButton
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
                    Menu {
                        if !viewModel.filteredFiles.isEmpty {
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
        .alert("Delete this Subject", isPresented: $viewModel.isShowingDeleteAlert) {
            deleteAlertContent
        } message: {
            Text("Deleting this subject will remove all associated data. Are you sure?")
        }
        .alert("Delete \(viewModel.selectedFiles.count) files?", isPresented: $viewModel.isShowingMultiDeleteAlert) {
            Button("Delete", role: .destructive) { viewModel.deleteSelectedFiles() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone.")
        }
        .fileImporter(
            isPresented: $viewModel.isShowingFileImporter,
            allowedContentTypes: [
                UTType.pdf,
                UTType(filenameExtension: "docx")!
            ],
            allowsMultipleSelection: true, // Allow multiple documents
            onCompletion: viewModel.handleFileImport
        )
        // This single previewer now handles all file types
        .fullScreenCover(item: $viewModel.documentToPreview) { document in
            ZStack(alignment: .topTrailing) {
                DocumentPreviewView(url: document.url)
                    .ignoresSafeArea()

                Button {
                    viewModel.documentToPreview = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.largeTitle)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.black, Color(.systemGray5).opacity(0.8))
                }
                .padding()
            }
            .interactiveDismissDisabled()
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
            viewModel.filterNotes()
        }
    }
    
    // MARK: - Subviews
    
    private var filterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(NoteFilter.allCases, id: \.self) { filter in
                    Button(action: {
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
    
    @ViewBuilder
    private var contentView: some View {
        ZStack {
            if viewModel.filteredFiles.isEmpty {
                noNotesView
            } else {
                notesGrid
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
                NoNotesView()
                Spacer()
            }
        }
    }
    
    private var notesGrid: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3)) {
                ForEach(viewModel.filteredFiles, id: \.self) { fileURL in
                    if fileURL.isImage {
                        imageView(for: fileURL)
                            .onTapGesture { handleTap(for: fileURL) }
                            .transition(.scale.combined(with: .opacity))
                    } else if fileURL.isPDF {
                        pdfView(for: fileURL)
                            .onTapGesture { handleTap(for: fileURL) }
                    } else if fileURL.isDocx {
                        documentView(for: fileURL, icon: "doc.text.fill", color: .blue)
                            .onTapGesture { handleTap(for: fileURL) }
                    }
                }
            }
            .padding(.vertical)
            .padding(.horizontal)
            Spacer(minLength: 100)
        }
    }
    
    private func handleTap(for fileURL: URL) {
        if viewModel.isEditing {
            viewModel.toggleSelection(for: fileURL)
        } else {
            viewModel.documentToPreview = PreviewableDocument(url: fileURL)
        }
    }
    
    private func imageView(for fileURL: URL) -> some View {
        Group {
            if let imageData = try? Data(contentsOf: fileURL), let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable().scaledToFit().frame(maxWidth: 100, maxHeight: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contextMenu {
                        if !viewModel.isEditing {
                            imageContextMenu(for: fileURL)
                        }
                    }
                    .selectionOverlay(isSelected: viewModel.selectedFiles.contains(fileURL), isEditing: viewModel.isEditing)
            }
        }
    }
    
    private func pdfView(for fileURL: URL) -> some View {
        VStack {
            if let pdfThumbnail = viewModel.generatePDFThumbnail(from: fileURL) {
                Image(uiImage: pdfThumbnail)
                    .resizable().scaledToFit().frame(width: 80, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8)).shadow(radius: 2)
            } else {
                Image(systemName: "doc.richtext").resizable().scaledToFit().frame(width: 50, height: 50)
            }
            Text(fileURL.lastPathComponent)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(maxWidth: 100)
        }
        .contextMenu {
            if !viewModel.isEditing {
                fileContextMenu(for: fileURL)
            }
        }
        .selectionOverlay(isSelected: viewModel.selectedFiles.contains(fileURL), isEditing: viewModel.isEditing)
    }
    
    private func documentView(for fileURL: URL, icon: String, color: Color) -> some View {
        DocumentThumbnailView(
            fileURL: fileURL,
            icon: icon,
            color: color,
            viewModel: viewModel
        )
        .contextMenu {
            if !viewModel.isEditing {
                fileContextMenu(for: fileURL)
            }
        }
        .selectionOverlay(isSelected: viewModel.selectedFiles.contains(fileURL), isEditing: viewModel.isEditing)
    }
    
    @ViewBuilder
    private func fileContextMenu(for fileURL: URL) -> some View {
        Button { viewModel.renamingFileURL = fileURL } label: { Label("Rename", systemImage: "pencil") }
        Button(role: .destructive) { viewModel.deleteFile(at: fileURL) } label: { Label("Delete", systemImage: "trash") }
    }
    
    @ViewBuilder
    private func imageContextMenu(for fileURL: URL) -> some View {
        Button(role: .destructive) { viewModel.deleteFile(at: fileURL) } label: { Label("Delete", systemImage: "trash") }
    }
    
    private var renameAlertContent: some View {
        Group {
            TextField("New Name", text: $viewModel.newFileName)
            Button("Cancel", role: .cancel) { viewModel.renamingFileURL = nil }
            Button("Save") { viewModel.renameFile() }
        }
    }
    
    private var addButton: some View {
        Menu {
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
    
    private var deleteSelectedButton: some View {
        Button(role: .destructive) {
            viewModel.isShowingMultiDeleteAlert = true
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("Delete (\(viewModel.selectedFiles.count))")
            }
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.selectedFiles.isEmpty ? Color.gray.opacity(0.8) : Color.red)
            .foregroundColor(.white)
            .clipShape(Capsule())
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .disabled(viewModel.selectedFiles.isEmpty)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(), value: viewModel.selectedFiles.isEmpty)
    }
    
    private var deleteAlertContent: some View {
        Button("Delete", role: .destructive) {
            playDeleteSound()
            viewModel.deleteSubject { dismiss() }
        }
    }

    private func triggerHapticFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
    
    private func playDeleteSound() {
        SoundManager.shared.playDeleteSound()
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

// MARK: - DocumentThumbnailView
struct DocumentThumbnailView: View {
    let fileURL: URL
    let icon: String
    let color: Color
    @ObservedObject var viewModel: CardDetailViewModel
    
    @State private var thumbnail: UIImage? = nil
    
    var body: some View {
        VStack {
            ZStack {
                Image(systemName: icon)
                    .resizable().scaledToFit().frame(width: 50, height: 50)
                    .foregroundColor(color)
                    .padding(25)
                    .background(color.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable().scaledToFit().frame(width: 80, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 2)
                }
            }
            .frame(width: 80, height: 100)

            Text(fileURL.lastPathComponent)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(maxWidth: 100)
        }
        .onAppear {
            viewModel.generateDocxThumbnail(from: fileURL) { image in
                self.thumbnail = image
            }
        }
    }
}

// MARK: - DocumentPreviewView (for DOCX, PDF, etc.)
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

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return parent.url as QLPreviewItem
        }
    }
}


// MARK: - ImagePicker (For Camera)
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
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
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

// MARK: - Preview
#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Subject.self, configurations: config)
        let example = Subject(name: "Example")
        container.mainContext.insert(example)
        
        return NavigationStack {
            CardDetailView(subject: example, modelContext: container.mainContext)
                .modelContainer(container)
        }
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}

