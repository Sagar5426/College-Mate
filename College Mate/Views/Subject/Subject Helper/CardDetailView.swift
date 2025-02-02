import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PDFKit

struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}



struct CardDetailView: View {
    
    @Query var subjects: [Subject]
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @State private var isShowingDeleteAlert = false
    @State private var isShowingEditView = false
    
    @State private var selectedImageForPreview: IdentifiableImage? = nil
    @State private var zoomScale: CGFloat = 1.0

    
    
    @State private var isShowingFileImporter = false
    @State private var isShowingImagePicker = false
    @State private var importedFileData: Data? = nil
    @State private var selectedImage: UIImage? = nil
    
    @State private var selectedFilter: NoteFilter = .all // Default filter
    @State private var renamingFileURL: URL? = nil
    @State private var newFileName: String = ""

    func renamePDF(_ fileURL: URL) {
        renamingFileURL = fileURL
        newFileName = fileURL.deletingPathExtension().lastPathComponent
    }
    func deletePDF(_ fileURL: URL) {
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            print("Failed to delete file: \(error.localizedDescription)")
        }
    }
    
    func deleteFile(_ fileURL: URL) {
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            print("Failed to delete file: \(error.localizedDescription)")
        }
    }



    
    let subject: Subject
    
    // MARK: MainView
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
                    ForEach(filteredNotes, id: \.self) { fileURL in
                        if fileURL.pathExtension == "jpg" || fileURL.pathExtension == "png" {
                            if let imageData = try? Data(contentsOf: fileURL), let image = UIImage(data: imageData) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: 100, maxHeight: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .onTapGesture {
                                        selectedImageForPreview = IdentifiableImage(image: image)
                                    }
                                    .contextMenu {
                                        Button(role: .destructive, action: { deleteFile(fileURL) }) {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        } else if fileURL.pathExtension == "pdf" {
                            NavigationLink(destination: PDFViewer(url: fileURL)) {
                                VStack {
                                    if let pdfThumbnail = generatePDFThumbnail(from: fileURL) {
                                        Image(uiImage: pdfThumbnail)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 80, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        Image(systemName: "doc.richtext")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 50, height: 50)
                                            .foregroundColor(.blue)
                                    }

                                    Text(fileURL.lastPathComponent)
                                        .font(.caption)
                                        .lineLimit(1)
                                        .frame(maxWidth: 100)
                                }
                            }
                            .contextMenu {
                                Button(action: { renamePDF(fileURL) }) {
                                    Label("Rename", systemImage: "pencil")
                                }
                                Button(role: .destructive, action: { deleteFile(fileURL) }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }




            }
        }
        .alert("Rename PDF", isPresented: Binding<Bool>(
            get: { renamingFileURL != nil },
            set: { _ in renamingFileURL = nil }
        )) {
            TextField("New Name", text: $newFileName)
            Button("Cancel", role: .cancel) { renamingFileURL = nil }
            Button("Save") {
                if let oldURL = renamingFileURL {
                    let newURL = oldURL.deletingLastPathComponent().appendingPathComponent("\(newFileName).pdf")
                    do {
                        try FileManager.default.moveItem(at: oldURL, to: newURL)
                    } catch {
                        print("Rename failed: \(error.localizedDescription)")
                    }
                }
                renamingFileURL = nil
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
            onCompletion: { result in
                DispatchQueue.main.async {
                    do {
                        let fileURL = try result.get()
                        print("Selected PDF URL: \(fileURL)") // Debugging
                        
                        // 🔥 Request permission to access the file
                        guard fileURL.startAccessingSecurityScopedResource() else {
                            print("Failed to access security-scoped resource.")
                            return
                        }

                        defer { fileURL.stopAccessingSecurityScopedResource() } // Release access when done
                        
                        let data = try Data(contentsOf: fileURL)
                        let fileName = "pdf_\(UUID().uuidString).pdf"
                        
                        if let savedURL = FileHelper.saveFile(data: data, fileName: fileName, to: subject) {
                            print("PDF saved at: \(savedURL)") // Debugging

                            let newNote = Note(title: fileName, type: .pdf, content: Data(savedURL.absoluteString.utf8))
                            subject.notes.append(newNote)
                            try? modelContext.save()
                        }
                    } catch {
                        print("Failed to import PDF: \(error.localizedDescription)")
                    }
                }
            }
        )




        
        
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(selectedImage: $selectedImage, onImageSelected: handleImageSelected)
        }
        
        .fullScreenCover(isPresented: $isShowingEditView) {
            EditSubjectView(subject: subject, isShowingEditSubjectView: $isShowingEditView)
        }
        .onAppear {
            print("CardDetailView appeared, ready for file import.")
        }

        
        .fullScreenCover(item: $selectedImageForPreview) { identifiableImage in
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack {
                    Spacer() // Pushes image to the center
                    Image(uiImage: identifiableImage.image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(zoomScale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    zoomScale = value
                                }
                                .onEnded { _ in
                                    zoomScale = 1.0
                                }
                        )
                    Spacer() // Pushes image to the center
                }
                
                // Close Button at Top Trailing
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            selectedImageForPreview = nil  // Dismiss the fullscreen view
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .resizable()
                                .frame(width: 30, height: 30)
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                                .padding()
                        }
                    }
                    .padding(.top, 10) // Avoids notch on iPhones
                    Spacer()
                }
            }
        }




        
        
    }
}

extension CardDetailView {
    func generatePDFThumbnail(from url: URL, pageNumber: Int = 1) -> UIImage? {
        guard let document = PDFDocument(url: url), let page = document.page(at: pageNumber - 1) else {
            return nil
        }

        let pageRect = page.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        
        return renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(pageRect)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }

    func deleteSubject() {
        FileHelper.deleteSubjectFolder(for: subject) // Delete folder
        modelContext.delete(subject)
        dismiss()
    }

    
    
    
    
    
    
    func handleImageSelected(_ image: UIImage?) {
        guard let image = image, let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        let fileName = "image_\(UUID().uuidString).jpg"
        
        if let fileURL = FileHelper.saveFile(data: imageData, fileName: fileName, to: subject) {
            let newNote = Note(title: fileName, type: .image, content: Data(fileURL.absoluteString.utf8))
            subject.notes.append(newNote)
            try? modelContext.save()
        }
    }

}

extension CardDetailView {
    var filteredNotes: [URL] {
        let allFiles = FileHelper.loadFiles(from: subject)

        switch selectedFilter {
        case .all:
            return allFiles
        case .images:
            return allFiles.filter { $0.pathExtension.lowercased() == "jpg" || $0.pathExtension.lowercased() == "png" }
        case .pdfs:
            return allFiles.filter { $0.pathExtension.lowercased() == "pdf" }
        }
    }
}


// MARK: Enum for Note Filter
enum NoteFilter: String, CaseIterable {
    case all = "All"
    case images = "Images"
    case pdfs = "PDFs"
    
    
    
}

//MARK: Preview
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



// MARK: Func to import images
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








