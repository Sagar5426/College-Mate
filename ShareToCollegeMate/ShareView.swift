import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ShareView: View {
    let attachment: NSItemProvider
    let onComplete: () -> Void
    
    @State private var subjects: [Subject] = []
    @State private var selectedSubject: Subject?
    @State private var selectedFolder: Folder?
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    private var modelContainer: ModelContainer?
    
    init(attachment: NSItemProvider, onComplete: @escaping () -> Void) {
        self.attachment = attachment
        self.onComplete = onComplete
        
        // Initialize the SwiftData container within the App Group
        do {
            // IMPORTANT: Replace "group.com.sagarjangra.College-Mate" with your actual App Group ID
            let storeURL = URL.storeURL(for: "group.com.sagarjangra.College-Mate", databaseName: "CollegeMate")
            let config = ModelConfiguration(url: storeURL)
            self.modelContainer = try ModelContainer(for: Subject.self, configurations: config)
        } catch {
            errorMessage = "Could not load database."
            print("Failed to create ModelContainer for extension: \(error)")
        }
    }
    
    var body: some View {
        VStack {
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            } else {
                NavigationView {
                    Form {
                        Section(header: Text("Select Destination")) {
                            Picker("Subject", selection: $selectedSubject) {
                                Text("Select a Subject").tag(nil as Subject?)
                                ForEach(subjects) { subject in
                                    Text(subject.name).tag(subject as Subject?)
                                }
                            }
                            
                            if let subject = selectedSubject {
                                Picker("Folder (Optional)", selection: $selectedFolder) {
                                    Text("Root of \(subject.name)").tag(nil as Folder?)
                                    ForEach(subject.rootFolders) { folder in
                                        Text(folder.name).tag(folder as Folder?)
                                    }
                                }
                            }
                        }
                    }
                    .navigationTitle("Save to College Mate")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel", action: onComplete)
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                saveFile()
                            }
                            .disabled(selectedSubject == nil || isSaving)
                        }
                    }
                }
            }
            
            if isSaving {
                ProgressView("Saving...")
                    .padding()
            }
        }
        .onAppear(perform: loadSubjects)
    }
    
    private func loadSubjects() {
        guard let context = modelContainer?.mainContext else { return }
        let descriptor = FetchDescriptor<Subject>(sortBy: [SortDescriptor(\.name)])
        do {
            subjects = try context.fetch(descriptor)
        } catch {
            errorMessage = "Could not fetch subjects."
            print("Failed to fetch subjects: \(error)")
        }
    }
    
    private func saveFile() {
        guard let subject = selectedSubject, let context = modelContainer?.mainContext else { return }
        
        isSaving = true
        
        Task {
            do {
                // Determine the type of the shared item
                if let item = try await attachment.loadItem(forTypeIdentifier: UTType.fileURL.identifier) as? URL {
                    let data = try Data(contentsOf: item)
                    let fileName = item.lastPathComponent
                    _ = FileDataService.saveFile(data: data, fileName: fileName, to: selectedFolder, in: subject, modelContext: context)
                } else if let item = try await attachment.loadItem(forTypeIdentifier: UTType.image.identifier) as? UIImage,
                          let data = item.jpegData(compressionQuality: 0.8) {
                    let fileName = "Image \(Date().formatted()).jpg"
                    _ = FileDataService.saveFile(data: data, fileName: fileName, to: selectedFolder, in: subject, modelContext: context)
                } else {
                    throw NSError(domain: "ShareError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported file type"])
                }
                
                try context.save()
                
                // Vibrate on success
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                
                onComplete()
                
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save file: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Helper Extension
extension URL {
    /// Returns a URL for the given app group and database naming convention.
    static func storeURL(for appGroup: String, databaseName: String) -> URL {
        guard let fileContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            fatalError("Shared file container could not be created.")
        }
        return fileContainer.appendingPathComponent("\(databaseName).sqlite")
    }
}

