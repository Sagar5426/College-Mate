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
                                    // Make sure folders are loaded correctly if needed
                                    // You might need to fetch folders based on selectedSubject if they aren't loaded automatically
                                    ForEach(subject.rootFolders.sorted(by: { $0.name < $1.name })) { folder in
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
        guard let subject = selectedSubject, // subject is non-optional here
              let context = modelContainer?.mainContext else {
            print("[ShareExt] Save aborted: Subject or context is nil.")
            errorMessage = "Cannot save: Subject or database context missing."
            return
        }

        isSaving = true
        errorMessage = nil

        Task {
            do {
                print("[ShareExt] Checking attachment type...")
                var dataToSave: Data?
                var fileNameToSave: String?

                // 1. PRIORITIZE loading as IMAGE DATA if the type conforms to image
                if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    print("[ShareExt] Attachment conforms to image type. Trying loadImageData...")
                    if let imageData = try await loadImageData(from: attachment) {
                        dataToSave = imageData
                        // Generate a unique name for images from Photos
                        fileNameToSave = "image_\(UUID().uuidString).jpg"
                        print("[ShareExt] Successfully loaded image data.")
                    } else {
                        print("[ShareExt] loadImageData returned nil despite type conformance.")
                    }
                }

                // 2. If NOT loaded as image data, try loading as a FILE URL (PDF, DOCX, or Image File)
                if dataToSave == nil {
                    print("[ShareExt] Not loaded as image data or type mismatch. Trying loadFileURL...")
                    if let fileURL = try await loadFileURL(from: attachment) {
                        // Securely access the file URL
                        let accessing = fileURL.startAccessingSecurityScopedResource()
                        defer {
                            if accessing {
                                fileURL.stopAccessingSecurityScopedResource()
                            }
                        }

                        dataToSave = try Data(contentsOf: fileURL)
                        fileNameToSave = fileURL.lastPathComponent
                        print("[ShareExt] Successfully loaded file URL data: \(fileNameToSave ?? "Unknown")")
                    } else {
                        print("[ShareExt] loadFileURL returned nil.")
                    }
                }

                // 3. Ensure we have data and a filename
                guard let data = dataToSave, let fileName = fileNameToSave else {
                    throw NSError(
                        domain: "ShareError",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Unsupported item type or failed to load data."]
                    )
                }

                // 4. Save using FileDataService
                print("[ShareExt] Data ready (\(data.count) bytes, name: \(fileName)). Calling FileDataService.saveFile...")

                // --- CORRECTED ACCESS ---
                // Access persistentModelID directly, no need for guard let
                let subjectID = subject.persistentModelID
                // --- END CORRECTION ---

                // Fetch the subject *within the current context* to ensure it's managed
                 guard let subjectInContext = context.model(for: subjectID) as? Subject else {
                      throw NSError(domain: "ShareError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not find selected subject in context."])
                 }

                 var folderInContext: Folder? = nil
                 // Only unwrap the optional selectedFolder
                 if let currentSelectedFolder = selectedFolder {
                     // Access persistentModelID directly since currentSelectedFolder is non-optional here
                     let folderID = currentSelectedFolder.persistentModelID
                     folderInContext = context.model(for: folderID) as? Folder
                     if folderInContext == nil {
                          print("[ShareExt] Warning: Could not find selected folder '\(currentSelectedFolder.name)' in context, saving to root.")
                     }
                 }

                 _ = FileDataService.saveFile(
                     data: data,
                     fileName: fileName,
                     to: folderInContext, // Use the folder fetched in this context
                     in: subjectInContext, // Use the subject fetched in this context
                     modelContext: context
                 )
                print("[ShareExt] File data prepared, attempting to save context...")

                // 5. Save the SwiftData context
                if context.hasChanges {
                    try context.save()
                    print("[ShareExt] Context saved successfully.")
                } else {
                    print("[ShareExt] No changes detected in context, skipping save.")
                }

                // 6. Success feedback and completion
                UINotificationFeedbackGenerator().notificationOccurred(.success)

                await MainActor.run {
                    print("[ShareExt] Save successful, calling onComplete.")
                    onComplete()
                }

            } catch {
                print("[ShareExt] Save failed:", error)
                await MainActor.run {
                    errorMessage = "Failed to save file: \(error.localizedDescription)"
                    isSaving = false
                    // Optional: Add error haptic
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }

    // MARK: - Loaders for NSItemProvider

    private func loadFileURL(from provider: NSItemProvider) async throws -> URL? {
        print("[ShareExt] loadFileURL called")

        // Helper to load file representation and handle security scope
        func loadSecureRepresentation(type: UTType) async -> URL? {
            await withCheckedContinuation { continuation in
                provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
                    if let url = url {
                        continuation.resume(returning: url)
                    } else {
                         print("[ShareExt] Error loading \(type.identifier): \(error?.localizedDescription ?? "Unknown error")")
                        continuation.resume(returning: nil)
                    }
                }
            }
        }

        // Try specific types first
        if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
             print("[ShareExt] Trying PDF representation")
             if let url = await loadSecureRepresentation(type: .pdf) {
                 print("[ShareExt] Got PDF URL")
                 return url
             }
         }

        if let docxType = UTType(filenameExtension: "docx"), provider.hasItemConformingToTypeIdentifier(docxType.identifier) {
             print("[ShareExt] Trying DOCX representation")
             if let url = await loadSecureRepresentation(type: docxType) {
                 print("[ShareExt] Got DOCX URL")
                 return url
             }
         }

        // Check for generic fileURL last (might work for images shared as files)
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            print("[ShareExt] Trying generic fileURL")
            let item = try? await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier)
            if let url = item as? URL {
                print("[ShareExt] Got generic fileURL")
                return url
            } else if let urlData = item as? Data, let urlString = String(data: urlData, encoding: .utf8), let url = URL(string: urlString) {
                 print("[ShareExt] Got generic fileURL from data")
                 return url
             }
        }

        print("[ShareExt] loadFileURL returning nil")
        return nil
    }


    private func loadImageData(from provider: NSItemProvider) async throws -> Data? {
        print("[ShareExt] loadImageData called")
        // Check exact types first for clarity
        let supportedImageTypes = [UTType.jpeg, UTType.png, UTType.heic] // Add others if needed
        var typeToLoad: UTType? = nil

        for type in supportedImageTypes {
            if provider.hasItemConformingToTypeIdentifier(type.identifier) {
                typeToLoad = type
                break
            }
        }
        // Fallback to generic image if specific type not found
        if typeToLoad == nil && provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
             typeToLoad = UTType.image
         }

        guard let finalType = typeToLoad else {
             print("[ShareExt] Provider does not conform to supported image types.")
             return nil
         }

        print("[ShareExt] Attempting to load item for type: \(finalType.identifier)")
        let item = try await provider.loadItem(forTypeIdentifier: finalType.identifier)

        // Handle different possible item types
        if let image = item as? UIImage {
            let data = image.jpegData(compressionQuality: 0.85) // Convert to JPEG
            print("[ShareExt] Converted UIImage to JPEG data (\(data?.count ?? 0) bytes)")
            return data
        } else if let data = item as? Data {
             print("[ShareExt] Loaded image directly as Data (\(data.count) bytes)")
            // You might want to check the data header to confirm it's an image
            return data
        } else if let url = item as? URL {
             print("[ShareExt] Loaded image as URL: \(url.path)")
             // If image comes as URL, read data from it
              let accessing = url.startAccessingSecurityScopedResource()
              defer { if accessing { url.stopAccessingSecurityScopedResource() } }
              let data = try? Data(contentsOf: url)
              print("[ShareExt] Read image data from URL (\(data?.count ?? 0) bytes)")
              return data
          }

        print("[ShareExt] loadImageData failed to get data from item.")
        return nil
    }
}

