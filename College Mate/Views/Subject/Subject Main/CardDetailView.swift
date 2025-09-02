import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers
import QuickLook // Import for document previews

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
        .overlay(alignment: .bottomTrailing) {
            addButton
        }
        .navigationTitle(viewModel.subject.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
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
        .alert("Delete this Subject", isPresented: $viewModel.isShowingDeleteAlert) {
            deleteAlertContent
        } message: {
            Text("Deleting this subject will remove all associated data. Are you sure?")
        }
        .fileImporter(
            isPresented: $viewModel.isShowingFileImporter,
            allowedContentTypes: [
                UTType(filenameExtension: "pdf")!,
                UTType(filenameExtension: "docx")!
            ],
            onCompletion: viewModel.handleFileImport
        )
        .sheet(isPresented: $viewModel.isShowingImagePicker) {
            ImagePicker(sourceType: .photoLibrary, onImageSelected: viewModel.handleImageSelected)
        }
        .fullScreenCover(item: $viewModel.documentToPreview) { document in
            ZStack(alignment: .topTrailing) {
                DocumentPreviewView(url: document.url)
                    .ignoresSafeArea()

                // FIXED: Updated button style for high contrast on any background
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
        .fullScreenCover(item: $viewModel.selectedImageForPreview) { identifiableImage in
            imagePreviewView(for: identifiableImage)
        }
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
            ProgressView().progressViewStyle(.circular).scaleEffect(2)
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
                        imageView(for: fileURL).transition(.scale.combined(with: .opacity))
                    } else if fileURL.isPDF {
                        pdfView(for: fileURL).onTapGesture {
                            viewModel.documentToPreview = PreviewableDocument(url: fileURL)
                        }
                    } else if fileURL.isDocx {
                        documentView(for: fileURL, icon: "doc.text.fill", color: .blue).onTapGesture {
                            viewModel.documentToPreview = PreviewableDocument(url: fileURL)
                        }
                    }
                }
            }
            .padding(.vertical)
            .padding(.horizontal)
            Spacer(minLength: 100)
        }
    }
    
    private func imageView(for fileURL: URL) -> some View {
        Group {
            if let imageData = try? Data(contentsOf: fileURL), let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable().scaledToFit().frame(maxWidth: 100, maxHeight: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onTapGesture {
                        viewModel.selectedImageForPreview = IdentifiableImage(image: image)
                    }
                    .contextMenu { fileContextMenu(for: fileURL) }
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
            // FIXED: Allowed text to wrap up to 3 lines
            Text(fileURL.lastPathComponent)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(maxWidth: 100)
        }
        .contextMenu { fileContextMenu(for: fileURL) }
    }
    
    private func documentView(for fileURL: URL, icon: String, color: Color) -> some View {
        // This view wrapper handles the asynchronous loading of the thumbnail.
        DocumentThumbnailView(
            fileURL: fileURL,
            icon: icon,
            color: color,
            viewModel: viewModel
        )
    }
    
    @ViewBuilder
    private func fileContextMenu(for fileURL: URL) -> some View {
        Button { viewModel.renamingFileURL = fileURL } label: { Label("Rename", systemImage: "pencil") }
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
            Button("Image from Photos", systemImage: "photo.fill") { viewModel.isShowingImagePicker = true }
            Button("Document from Files", systemImage: "doc.fill") { viewModel.isShowingFileImporter = true }
        } label: {
            Image(systemName: "plus.circle.fill")
                .resizable().aspectRatio(contentMode: .fit).foregroundColor(.blue)
                .background(Circle().fill(.white)).frame(width: 55, height: 55).shadow(radius: 8)
        }
        .padding()
    }
    
    private var deleteAlertContent: some View {
        Button("Delete", role: .destructive) {
            playDeleteSound()
            viewModel.deleteSubject { dismiss() }
        }
    }
    
    private func imagePreviewView(for identifiableImage: IdentifiableImage) -> some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                Image(uiImage: identifiableImage.image)
                    .resizable().aspectRatio(contentMode: .fit)
                    .scaleEffect(viewModel.scale)
                    .offset(viewModel.imageOffset)
                    .onAppear(perform: viewModel.onImagePreviewAppear)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in viewModel.adjustDragOffset(gesture: gesture, geometrySize: geometry.size) }
                            .onEnded { _ in viewModel.onDragEnded() }
                    )
                    .gesture(
                        MagnificationGesture()
                            .onChanged(viewModel.adjustScale)
                            .onEnded { _ in viewModel.onMagnificationEnded() }
                    )

                VStack {
                    HStack {
                        Spacer()
                        Button { viewModel.selectedImageForPreview = nil } label: {
                            Image(systemName: "xmark.circle.fill").font(.largeTitle).foregroundColor(.white.opacity(0.7))
                        }
                        .padding()
                    }
                    Spacer()
                }
            }
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

// MARK: - DocumentThumbnailView
// A new helper view to manage loading and displaying docx thumbnails.
struct DocumentThumbnailView: View {
    let fileURL: URL
    let icon: String
    let color: Color
    @ObservedObject var viewModel: CardDetailViewModel
    
    @State private var thumbnail: UIImage? = nil
    
    var body: some View {
        VStack {
            ZStack {
                // Show the placeholder icon by default.
                Image(systemName: icon)
                    .resizable().scaledToFit().frame(width: 50, height: 50)
                    .foregroundColor(color)
                    .padding(25)
                    .background(color.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // If a thumbnail has been loaded, display it on top.
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
            // When the view appears, ask the ViewModel to generate the thumbnail.
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


