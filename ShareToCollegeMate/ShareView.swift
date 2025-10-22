import SwiftUI
import SwiftData
import Foundation
import UniformTypeIdentifiers
import UIKit

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
        
        do {
            self.modelContainer = try SharedModelContainer.make()
            if let url = (self.modelContainer?.configurations.first?.url) {
                print("[ShareExt] Store URL:", url.path)
            }
        } catch {
            self.modelContainer = nil
            self.errorMessage = "Could not load database. Please open the main app once and ensure App Group entitlements are set for the extension."
            print("[ShareExt] Failed to create ModelContainer:", error)
        }
    }
    
    var body: some View {
        VStack {
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
                Button("Close") { onComplete() }
                    .padding(.top, 8)
            } else {
                NavigationView {
                    Form {
                        Section(header: Text("Select Destination")) {
                            if subjects.isEmpty {
                                Text("No subjects found. Open the main app to create a subject first.")
                                    .foregroundColor(.secondary)
                            }
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
                                if modelContainer == nil {
                                    errorMessage = "Database unavailable in extension. Check App Group setup."
                                    return
                                }
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
            
            if errorMessage == nil && subjects.isEmpty && modelContainer != nil {
                Text("Loading subjects…")
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .onAppear {
            if modelContainer == nil {
                print("[ShareExt] ModelContainer is nil on appear.")
            } else {
                loadSubjects()
            }
        }
    }
    
    private func loadSubjects() {
        guard let context = modelContainer?.mainContext else {
            print("[ShareExt] ModelContainer is nil in loadSubjects()")
            errorMessage = "Could not access database in extension. Verify App Group entitlements."
            return
        }
        let descriptor = FetchDescriptor<Subject>(sortBy: [SortDescriptor(\.name)])
        do {
            subjects = try context.fetch(descriptor)
            print("[ShareExt] Fetched \(subjects.count) subjects")
        } catch {
            errorMessage = "Could not fetch subjects. Open the app once to set up data."
            print("[ShareExt] Failed to fetch subjects:", error)
        }
    }
    
    private func saveFile() {
        print("[ShareExt] Save tapped")
        guard let subject = selectedSubject,
              let context = modelContainer?.mainContext else { return }
        
        isSaving = true
        errorMessage = nil
        
        Task {
            do {
                print("[ShareExt] Attempting to read from NSItemProvider")
                // Try to load a file URL first (covers PDFs, DOCX, images provided as file URLs)
                if let fileURL = try await loadFileURL(from: attachment) {
                    let data = try Data(contentsOf: fileURL)
                    let fileName = fileURL.lastPathComponent
                    _ = FileDataService.saveFile(
                        data: data,
                        fileName: fileName,
                        to: selectedFolder,
                        in: subject,
                        modelContext: context
                    )
                    print("[ShareExt] File data prepared, attempting to save context")
                }
                // Fallback: try loading as image data
                else if let imageData = try await loadImageData(from: attachment) {
                    let fileName = "Image \(Date().formatted()).jpg"
                    _ = FileDataService.saveFile(
                        data: imageData,
                        fileName: fileName,
                        to: selectedFolder,
                        in: subject,
                        modelContext: context
                    )
                    print("[ShareExt] File data prepared, attempting to save context")
                } else {
                    throw NSError(
                        domain: "ShareError",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Unsupported file type"]
                    )
                }
                
                try context.save()
                
                // Success haptic
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                
                await MainActor.run {
                    onComplete()
                }
            } catch {
                print("[ShareExt] Save failed:", error)
                await MainActor.run {
                    errorMessage = "Failed to save file: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }
    
    // MARK: - Loaders for NSItemProvider
    
    private func loadFileURL(from provider: NSItemProvider) async throws -> URL? {
        print("[ShareExt] loadFileURL called")
        // Prefer fileURL if the source app provides it
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            let item = try await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier)
            if let url = item as? URL {
                print("[ShareExt] Got direct fileURL")
                return url
            }
        }
        // Otherwise try specific types (pdf, docx, image) via file representation
        if let url = try await loadFileRepresentation(from: provider, type: .pdf) {
            print("[ShareExt] Got PDF representation")
            return url
        }
        if let docx = UTType(filenameExtension: "docx"),
           let url = try await loadFileRepresentation(from: provider, type: docx) {
            print("[ShareExt] Got DOCX representation")
            return url
        }
        if let url = try await loadFileRepresentation(from: provider, type: .image) {
            print("[ShareExt] Got image file representation")
            return url
        }
        return nil
    }
    
    private func loadFileRepresentation(from provider: NSItemProvider, type: UTType) async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: url)
            }
        }
    }
    
    private func loadImageData(from provider: NSItemProvider) async throws -> Data? {
        print("[ShareExt] loadImageData called")
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            let item = try await provider.loadItem(forTypeIdentifier: UTType.image.identifier)
            if let image = item as? UIImage {
                let data = image.jpegData(compressionQuality: 0.85)
                print("[ShareExt] Converted UIImage to JPEG data")
                return data
            }
        }
        return nil
    }
}
