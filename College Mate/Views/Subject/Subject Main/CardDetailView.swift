import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation

// MARK: - CardDetailView
struct CardDetailView: View {
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel: CardDetailViewModel
    
    init(subject: Subject, modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: CardDetailViewModel(subject: subject, modelContext: modelContext))
    }
    
    var body: some View {
        VStack {
            filterPicker
            contentView
        }
        .background(LinearGradient(colors: [.gray.opacity(0.1), .black.opacity(0.1), .gray.opacity(0.07)], startPoint: .top, endPoint: .bottom))
        .alert("Rename PDF", isPresented: .constant(viewModel.renamingFileURL != nil)) {
            renameAlertContent
        }
        .overlay(alignment: .bottomTrailing) {
            addButton
        }
        .navigationTitle(viewModel.subject.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                editButton
                deleteButton
            }
        }
        .alert("Delete this Subject", isPresented: $viewModel.isShowingDeleteAlert) {
            deleteAlertContent
        } message: {
            Text("Deleting this subject will remove all associated data. Are you sure?")
        }
        .fileImporter(isPresented: $viewModel.isShowingFileImporter, allowedContentTypes: [.pdf], onCompletion: viewModel.handleFileImport)
        .sheet(isPresented: $viewModel.isShowingImagePicker) {
            ImagePicker(sourceType: .photoLibrary, onImageSelected: viewModel.handleImageSelected)
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
            // This line is correct and relies on the button to work.
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
    
    private var filterPicker: some View {
        Picker("Filter", selection: $viewModel.selectedFilter) {
            ForEach(NoteFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding()
    }
    
    @ViewBuilder
    private var contentView: some View {
        ZStack {
            if viewModel.allFiles.isEmpty {
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
                        pdfView(for: fileURL).transition(.slide.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal)
            Spacer(minLength: 70)
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
                    .contextMenu {
                        Button(role: .destructive) { viewModel.deleteFile(at: fileURL) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
    }
    
    private func pdfView(for fileURL: URL) -> some View {
        NavigationLink(destination: PDFViewer(url: fileURL)) {
            VStack {
                if let pdfThumbnail = viewModel.generatePDFThumbnail(from: fileURL) {
                    Image(uiImage: pdfThumbnail)
                        .resizable().scaledToFit().frame(width: 80, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8)).shadow(radius: 2)
                } else {
                    Image(systemName: "doc.richtext").resizable().scaledToFit().frame(width: 50, height: 50)
                }
                Text(fileURL.lastPathComponent).font(.caption).lineLimit(1).frame(maxWidth: 100)
            }
        }
        .contextMenu {
            Button { viewModel.renamingFileURL = fileURL } label: { Label("Rename", systemImage: "pencil") }
            Button(role: .destructive) { viewModel.deleteFile(at: fileURL) } label: { Label("Delete", systemImage: "trash") }
        }
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
            Button("Camera", systemImage: "camera.fill") {
                viewModel.isShowingCamera = true
            }
            Button("Image from Photos", systemImage: "photo.fill") {
                viewModel.isShowingImagePicker = true
            }
            Button("PDF from Files", systemImage: "text.document.fill") {
                viewModel.isShowingFileImporter = true
            }
        } label: {
            Image(systemName: "document.badge.plus.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundColor(.white)
                .frame(width: 35, height: 35, alignment: .leading)
                .padding(12)
                .background(Circle().fill(Color.blue.opacity(0.8)))
                .shadow(radius: 10)
        }
        .padding()
    }
    
    private var editButton: some View {
        // --- DEFINITIVE FIX ---
        // This structure is the most reliable for toolbar buttons.
        // It provides a clear tap target and works correctly with .tint().
        Button(action: {
            viewModel.isShowingEditView.toggle()
        }) {
            Image(systemName: "pencil")
        }
        .tint(.blue)
    }
    
    private var deleteButton: some View {
        // Applying the same robust structure for consistency.
        Button(action: {
            triggerHapticFeedback()
            viewModel.isShowingDeleteAlert = true
        }) {
            Image(systemName: "trash")
        }
        .tint(.red)
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

// MARK: - ImagePicker (Updated)
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
