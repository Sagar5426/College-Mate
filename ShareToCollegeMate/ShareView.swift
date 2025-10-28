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

    // --- FINAL ROBUST SAVE LOGIC ---
    private func saveFile() {
        print("[ShareExt] Save tapped")
        guard let subject = selectedSubject,
              let context = modelContainer?.mainContext else {
            print("[ShareExt] Save aborted: Subject or context is nil.")
            errorMessage = "Cannot save: Subject or database context missing."
            return
        }

        isSaving = true
        errorMessage = nil

        // --- Path A: Prioritize known NON-IMAGE file types first ---
        let fileTypeToLoad: UTType?
        
        if attachment.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
            fileTypeToLoad = UTType.pdf
        } else if let docxType = UTType(filenameExtension: "docx"), attachment.hasItemConformingToTypeIdentifier(docxType.identifier) {
            fileTypeToLoad = docxType
        } else {
            fileTypeToLoad = nil
        }

        if let fileType = fileTypeToLoad {
            print("[ShareExt] Path A: Detected file type: \(fileType.identifier). Loading as file...")
            attachment.loadFileRepresentation(forTypeIdentifier: fileType.identifier) { [self] (url, error) in
                if let url = url {
                    handleFileURL(url, subject: subject, folder: selectedFolder, context: context)
                } else {
                    handleSaveError(error ?? NSError(domain: "ShareError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load file for type \(fileType.identifier)."]))
                }
            }
            return // We are done.
        }

        // --- Path B: It's not a known file. Check if it's an image. ---
        // This is the correct path for all images, from Photos or Files.
        if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            print("[ShareExt] Path B: Detected image. Starting multi-step image load...")
            loadImageData(subject: subject, folder: selectedFolder, context: context)
            return
        }
        
        // --- Path C: It's not a known file or an image. ---
        // This is the final fallback. Try to get the best data representation.
        print("[ShareExt] Path C: Not a file or image. Using best data representation fallback...")
        self.loadBestDataRepresentation(
             preferring: [UTType.data], // Prefer any data
             subject: subject,
             folder: selectedFolder,
             context: context
         )
    }
    
    // --- FINAL MULTI-STEP IMAGE LOADER ---
    private func loadImageData(subject: Subject, folder: Folder?, context: ModelContext) {
        
        // Step 1: Try to load as a UIImage object. (Best for Photos app)
        if attachment.canLoadObject(ofClass: UIImage.self) {
            attachment.loadObject(ofClass: UIImage.self) { [self] (item, error) in
                if let image = item as? UIImage {
                    // Success! We got a UIImage.
                    print("[ShareExt] ImageLoad Step 1: Success. Loaded UIImage object.")
                    guard let dataToSave = image.jpegData(compressionQuality: 0.85) else {
                        handleSaveError(NSError(domain: "ShareError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to convert UIImage to JPEG data."]))
                        return
                    }
                    let fileNameToSave = "image_\(UUID().uuidString).jpg"
                    performSave(data: dataToSave, fileName: fileNameToSave, subject: subject, folder: folder, context: context)
                } else {
                    // It said it could load a UIImage, but failed.
                    // This happens when sharing a file (like a JPEG) that *could* be a UIImage.
                    // We must not stop. We proceed to Step 2.
                    print("[ShareExt] ImageLoad Step 1: Failed to load UIImage object (Error: \(error?.localizedDescription ?? "Unknown")). Proceeding to Step 2...")
                    self.loadImageAsFile(subject: subject, folder: folder, context: context)
                }
            }
        } else {
            // It's an image, but not a UIImage object.
            // This is typical for files. Proceed to Step 2.
            print("[ShareExt] ImageLoad Step 1: Cannot load as UIImage object. Proceeding to Step 2...")
            self.loadImageAsFile(subject: subject, folder: folder, context: context)
        }
    }
    
    private func loadImageAsFile(subject: Subject, folder: Folder?, context: ModelContext) {
        
        // Step 2: Try to load as a JPEG file. (Best for JPEG files)
        if attachment.hasItemConformingToTypeIdentifier(UTType.jpeg.identifier) {
            print("[ShareExt] ImageLoad Step 2: Trying to load as JPEG file...")
            attachment.loadFileRepresentation(forTypeIdentifier: UTType.jpeg.identifier) { [self] (url, error) in
                if let url = url {
                    print("[ShareExt] ImageLoad Step 2: Success. Loaded JPEG file URL.")
                    handleFileURL(url, subject: subject, folder: folder, context: context)
                } else {
                    // Failed to load as JPEG. Proceed to Step 3.
                    print("[ShareExt] ImageLoad Step 2: Failed to load JPEG file (Error: \(error?.localizedDescription ?? "Unknown")). Proceeding to Step 3...")
                    self.loadImageAsPngFile(subject: subject, folder: folder, context: context)
                }
            }
        } else {
            // Not a JPEG. Proceed to Step 3.
            print("[ShareExt] ImageLoad Step 2: Not a JPEG. Proceeding to Step 3...")
            self.loadImageAsPngFile(subject: subject, folder: folder, context: context)
        }
    }
    
    private func loadImageAsPngFile(subject: Subject, folder: Folder?, context: ModelContext) {
        
        // Step 3: Try to load as a PNG file. (Best for PNG files)
        if attachment.hasItemConformingToTypeIdentifier(UTType.png.identifier) {
            print("[ShareExt] ImageLoad Step 3: Trying to load as PNG file...")
            attachment.loadFileRepresentation(forTypeIdentifier: UTType.png.identifier) { [self] (url, error) in
                if let url = url {
                    print("[ShareExt] ImageLoad Step 3: Success. Loaded PNG file URL.")
                    handleFileURL(url, subject: subject, folder: folder, context: context)
                } else {
                    // Failed to load as PNG. Proceed to Step 4 (Fallback).
                    print("[ShareExt] ImageLoad Step 3: Failed to load PNG file (Error: \(error?.localizedDescription ?? "Unknown")). Proceeding to Step 4...")
                    self.loadBestDataRepresentation(preferring: [UTType.image], subject: subject, folder: folder, context: context)
                }
            }
        } else {
            // Not a PNG. Proceed to Step 4 (Fallback).
            print("[ShareExt] ImageLoad Step 3: Not a PNG. Proceeding to Step 4...")
            self.loadBestDataRepresentation(preferring: [UTType.image], subject: subject, folder: folder, context: context)
        }
    }

    // Helper to process a file URL
    private func handleFileURL(_ url: URL, subject: Subject, folder: Folder?, context: ModelContext) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let dataToSave = try Data(contentsOf: url)
            let fileNameToSave = url.lastPathComponent
            print("[ShareExt] handleFileURL: Successfully read \(dataToSave.count) bytes from \(fileNameToSave).")
            performSave(data: dataToSave, fileName: fileNameToSave, subject: subject, folder: folder, context: context)
        } catch {
            print("[ShareExt] handleFileURL: Error reading data from URL: \(error)")
            handleSaveError(error)
        }
    }
    
    // Helper to perform the actual save
    private func performSave(data: Data, fileName: String, subject: Subject, folder: Folder?, context: ModelContext) {
        
        // --- MOST ROBUST CRITICAL CHECK ---
        // A real image file (JPG, PNG) is binary and will NOT decode as a UTF-8 string.
        // A proxy file (like "data") WILL decode.
        // We check if it's small AND decodes successfully.
        if data.count < 100, let dataString = String(data: data, encoding: .utf8) {
            // It's small AND it's a valid string. This is a proxy.
            let trimmedString = dataString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            print("[ShareExt] ERROR: Detected proxy data. Decoded as string: '\(trimmedString)'. Aborting save.")
            handleSaveError(NSError(domain: "ShareError", code: 99, userInfo: [NSLocalizedDescriptionKey: "Failed to load full image. Received proxy data."]))
            return
        }
        // --- END CHECK ---
        
        print("[ShareExt] Data ready (\(data.count) bytes, name: \(fileName)). Calling FileDataService.saveFile...")

        do {
            let subjectID = subject.persistentModelID
            guard let subjectInContext = context.model(for: subjectID) as? Subject else {
                throw NSError(domain: "ShareError", code: 9, userInfo: [NSLocalizedDescriptionKey: "Could not find selected subject in context."])
            }

            var folderInContext: Folder? = nil
            if let selectedFolder = folder {
                let folderID = selectedFolder.persistentModelID
                folderInContext = context.model(for: folderID) as? Folder
                if folderInContext == nil {
                    print("[ShareExt] Warning: Could not find selected folder '\(selectedFolder.name)' in context, saving to root.")
                }
            }

            _ = FileDataService.saveFile(
                data: data,
                fileName: fileName,
                to: folderInContext,
                in: subjectInContext,
                modelContext: context
            )
            print("[ShareExt] File data prepared, attempting to save context...")

            if context.hasChanges {
                try context.save()
                print("[ShareExt] Context saved successfully.")
            } else {
                print("[ShareExt] No changes detected in context, skipping save.")
            }
            
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.async {
                print("[ShareExt] Save successful, calling onComplete.")
                onComplete()
            }
            
        } catch {
            print("[ShareExt] performSave: Error during FileDataService.saveFile or context.save: \(error)")
            handleSaveError(error)
        }
    }
    
    // Step 4: HELPER FUNCTION to load the best available data representation (FALLBACK)
    private func loadBestDataRepresentation(preferring preferredTypes: [UTType], subject: Subject, folder: Folder?, context: ModelContext) {
        
        // Get all types the provider says it has
        let availableTypes = attachment.registeredTypeIdentifiers.compactMap { UTType($0) }
        print("[ShareExt] loadBestData: Available types: \(availableTypes.map { $0.identifier })")
        
        // Find the best type to load based on our preferred order
        var typeToLoad: UTType? = nil
        for type in preferredTypes {
            // Check if any available type *conforms* to our preferred type
            if let specificType = availableTypes.first(where: { $0.conforms(to: type) }) {
                typeToLoad = specificType // We found our best match
                print("[ShareExt] loadBestData: Found match for \(type.identifier), will load \(specificType.identifier)")
                break
            }
        }
        
        // If we didn't find any match, fail
        guard let finalType = typeToLoad else {
            print("[ShareExt] loadBestData: No suitable data representation found in preferred list: \(preferredTypes.map { $0.identifier })")
            handleSaveError(NSError(domain: "ShareError", code: 10, userInfo: [NSLocalizedDescriptionKey: "No compatible data representation found."]))
            return
        }

        print("[ShareExt] loadBestData: Trying loadDataRepresentation(forTypeIdentifier: \(finalType.identifier))...")
        attachment.loadDataRepresentation(forTypeIdentifier: finalType.identifier) { [self] (data, error) in
            if let dataToSave = data {
                // Use the file extension from the *actual* type we loaded
                let fileExtension = finalType.preferredFilenameExtension ?? "data" // Use "data" as a generic extension
                let fileNameToSave = "image_\(UUID().uuidString).\(fileExtension)"
                
                // Now call the save operation
                self.performSave(data: dataToSave, fileName: fileNameToSave, subject: subject, folder: folder, context: context)
            } else {
                let dataError = error ?? NSError(domain: "ShareError", code: 11, userInfo: [NSLocalizedDescriptionKey: "Failed to load data for type \(finalType.identifier)."])
                self.handleSaveError(dataError)
            }
        }
    }


    // Helper to show errors on the main thread
    private func handleSaveError(_ error: Error) {
        print("[ShareExt] Save failed:", error.localizedDescription)
        DispatchQueue.main.async {
            errorMessage = "Failed to save file: \(error.localizedDescription)"
            isSaving = false
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

