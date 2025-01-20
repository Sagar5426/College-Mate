import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct CardDetailView: View {
    
    @Query var subjects: [Subject]
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @State private var isShowingDeleteAlert = false
    @State private var isShowingEditView = false
    
    @State private var isShowingFileImporter = false
    @State private var isShowingImagePicker = false
    @State private var importedFileData: Data? = nil
    @State private var selectedImage: UIImage? = nil
    
    @State private var selectedFilter: NoteFilter = .all // Default filter
    
    let subject: Subject
    
    var body: some View {
        VStack {
            // Segmented Control
                        Picker("Filter", selection: $selectedFilter) {
                            ForEach(NoteFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding()
            
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3)) {
                ForEach(filteredNotes, id: \.id) { note in
                    if note.type == .image {
                        if let image = UIImage(data: note.content) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 100, maxHeight: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    } else if note.type == .pdf {
                        VStack {
                            Image(systemName: "doc.richtext")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50)
                                .foregroundColor(.blue)
                            Text(note.title)
                                .font(.caption)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }
        
        .overlay(alignment: .bottomTrailing){
            
            Menu {
                Button("Add Image from Photos") {
                    isShowingImagePicker = true
                }
                .tag(0)
                Button("Add PDF from Files") {
                    isShowingFileImporter = true
                }.tag(1)
                
            } label: {
                Image(systemName: "plus")
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .padding(12)
                    .background(Circle().fill(Color.blue.opacity(0.8)))
                    .shadow(radius: 10)
                
            }
            .padding()
            
        }
        .font(.title)
        .navigationTitle(subject.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    isShowingEditView.toggle()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button {
                    isShowingDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .alert("Delete this Subject", isPresented: $isShowingDeleteAlert) {
            Button("Delete", role: .destructive, action: deleteSubject)
            Button("Cancel", role: .cancel, action: {})
        } message: {
            Text("Deleting this subject will remove all associated data. Are you sure?")
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.pdf],
            onCompletion: handleFileImport
        )
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(selectedImage: $selectedImage, onImageSelected: handleImageSelected)
        }
        .fullScreenCover(isPresented: $isShowingEditView) {
            EditSubjectView(subject: subject, isShowingEditSubjectView: $isShowingEditView)
        }
    }
}

extension CardDetailView {
    func deleteSubject() {
        modelContext.delete(subject)
        dismiss()
    }
    
    func handleFileImport(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            if let pdfData = try? Data(contentsOf: url) {
                let newNote = Note(title: url.lastPathComponent, type: .pdf, content: pdfData)
                subject.notes.append(newNote)
                try? modelContext.save()
            }
        case .failure(let error):
            print("Failed to import file: \(error.localizedDescription)")
        }
    }
    
    func handleImageSelected(_ image: UIImage?) {
        guard let image = image, let imageData = image.pngData() else { return }
        let newNote = Note(title: "Image Note", type: .image, content: imageData)
        subject.notes.append(newNote)
        try? modelContext.save()
    }
}

extension CardDetailView {
    var filteredNotes: [Note] {
            switch selectedFilter {
            case .all:
                return subject.notes
            case .images:
                return subject.notes.filter { $0.type == .image }
            case .pdfs:
                return subject.notes.filter { $0.type == .pdf }
            }
        }
    }

    // Enum for Note Filter
    enum NoteFilter: String, CaseIterable {
        case all = "All"
        case images = "Images"
        case pdfs = "PDFs"
        
        
    
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Subject.self, configurations: config)
        let example = Subject(name: "Example")
        
        return NavigationStack {
            CardDetailView(subject: example)
                .modelContainer(container)
        }
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}



// Func to import images
import SwiftUI
import PhotosUI

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
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
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
            
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                DispatchQueue.main.async {
                    self.parent.selectedImage = image as? UIImage
                    self.parent.onImageSelected(self.parent.selectedImage)
                }
            }
        }
    }
}

