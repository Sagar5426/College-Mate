import SwiftUI
import SwiftData
import PhotosUI // Keep for ImagePicker

// MARK: - CardDetailView
struct CardDetailView: View {
    
    // MARK: - Properties
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // The View now owns the ViewModel as its single source of truth for state and logic.
    // @StateObject ensures the ViewModel's lifecycle is tied to the View.
    @StateObject private var viewModel: CardDetailViewModel
    
    // MARK: - Initializer
    // The View's initializer now creates its ViewModel, injecting any dependencies it needs,
    // like the 'subject' model and the 'modelContext'.
    init(subject: Subject, modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: CardDetailViewModel(subject: subject, modelContext: modelContext))
    }
    
    // MARK: - Main View
    var body: some View {
        VStack {
            filterPicker
            contentView
        }
        .background(LinearGradient(colors: [.gray.opacity(0.1), .black.opacity(0.1), .gray.opacity(0.07)], startPoint: .top, endPoint: .bottom))
        // All UI elements now bind directly to the ViewModel's @Published properties.
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
            // The ImagePicker now only needs the callback function from the ViewModel.
            ImagePicker(onImageSelected: viewModel.handleImageSelected)
        }
        .fullScreenCover(isPresented: $viewModel.isShowingEditView) {
            EditSubjectView(subject: viewModel.subject, isShowingEditSubjectView: $viewModel.isShowingEditView)
        }
        .fullScreenCover(item: $viewModel.selectedImageForPreview) { identifiableImage in
            imagePreviewView(for: identifiableImage)
        }
        // When the filter changes, we explicitly tell the ViewModel to re-filter the notes.
        .onChange(of: viewModel.selectedFilter) {
            viewModel.filterNotes()
        }
    }
    
    // MARK: - Subviews (UI Components)
    
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
            // The view is now declarative, showing UI based on ViewModel state.
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
                // The grid now reads from the ViewModel's 'filteredFiles' property.
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
                        // Action: Tell the ViewModel to show the image preview.
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
                // The view asks the ViewModel to generate the thumbnail.
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
        Button { viewModel.isShowingEditView.toggle() } label: { Label("Edit", systemImage: "pencil") }
    }
    
    private var deleteButton: some View {
        Button(role: .destructive) { viewModel.isShowingDeleteAlert = true } label: { Label("Delete", systemImage: "trash") }
    }
    
    private var deleteAlertContent: some View {
        Button("Delete", role: .destructive) {
            // Action: Tell the ViewModel to delete the subject and pass the dismiss
            // action from the environment as a callback.
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
}

// MARK: - ImagePicker (Slightly Simplified)
struct ImagePicker: UIViewControllerRepresentable {
    // We no longer need the @Binding, the closure is sufficient.
    var onImageSelected: (UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
                parent.onImageSelected(nil)
                return
            }
            
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                DispatchQueue.main.async {
                    self.parent.onImageSelected(image as? UIImage)
                }
            }
        }
    }
}

// MARK: - Preview
// The preview needs to be updated to inject the modelContext into the view's new initializer.
#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Subject.self, configurations: config)
        let example = Subject(name: "Example")
        container.mainContext.insert(example) // Insert for the preview
        
        return NavigationStack {
            CardDetailView(subject: example, modelContext: container.mainContext)
                .modelContainer(container)
        }
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
