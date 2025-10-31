import SwiftUI
import SwiftData

struct EditSubjectView: View {
    @Environment(\.modelContext) private var modelContext
    @Query var subjects: [Subject]
    @Bindable var subject: Subject
    @Binding var isShowingEditSubjectView: Bool
    
    @State private var originalSubjectName: String = ""
    @State private var isShowingDuplicateAlert = false
    
    let daysOfWeek = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    let characterLimit = 20 // Stricter character limit
    
    @State private var selectedDays: Set<String> = []
    @State private var classTimes: [String: [ClassPeriodTime]] = [:]
    @State private var classCount: [String: Int] = [:]
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.appBackground.ignoresSafeArea()
                Form {
                    Section(header: Text("Subject Details")) {
                        TextField("Subject Name (Max 20 Characters)", text: $subject.name)
                            .onChange(of: subject.name) {
                                subject.name = String(subject.name.prefix(characterLimit))
                            }
                    }
                    FirstSubjectDatePicker(startDateOfSubject: $subject.startDateOfSubject)
                    
                    // --- CloudKit Fix: Safely unwrap attendance ---
                    MinimumAttendenceStepper(MinimumAttendancePercentage: Binding<Int>(
                        get: { Int(subject.attendance?.minimumPercentageRequirement ?? 75.0) }, // Read from optional
                        set: { subject.attendance?.minimumPercentageRequirement = Double($0) } // Write to optional
                    ))
                    // --- End of Fix ---
                    
                    ClassScheduleSection(
                        daysOfWeek: daysOfWeek,
                        selectedDays: $selectedDays,
                        classTimes: $classTimes,
                        classCount: $classCount
                    )
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .onAppear {
                    originalSubjectName = subject.name
                    populateExistingData()
                }
                
                .onDisappear {
                    saveUpdatedData()
                }
                .navigationTitle("Edit Subject")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            validateAndSaveChanges()
                        }
                    }
                }
                .alert("Duplicate Subject", isPresented: $isShowingDuplicateAlert) {
                    Button("OK") { }
                } message: {
                    Text("A subject with this name already exists. Please choose a different name.")
                }
            }
        }
        
    }
    
    private func validateAndSaveChanges() {
        // Trim whitespace/newlines and enforce character limit again (defensive)
        let trimmedName = subject.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let newName = String(trimmedName.prefix(characterLimit))

        // Prevent empty names
        guard !newName.isEmpty else {
            isShowingDuplicateAlert = true
            // Revert to original valid name
            subject.name = originalSubjectName
            return
        }

        // Determine if name actually changed (case-insensitive for comparison but preserve casing for storage)
        let nameChanged = newName.lowercased() != originalSubjectName.lowercased()

        // Duplicate check should EXCLUDE the current subject
        if nameChanged {
            let lowercasedNew = newName.lowercased()
            let hasDuplicate = subjects.contains { other in
                // Exclude the current subject instance by comparing persistent identifiers
                if other.persistentModelID == subject.persistentModelID { return false }
                return other.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == lowercasedNew
            }

            if hasDuplicate {
                isShowingDuplicateAlert = true
                // Revert visible text to original name
                subject.name = originalSubjectName
                return
            }
        }

        // Apply the normalized name back to the model
        subject.name = newName

        // If validation passes, move files and dismiss
        if nameChanged {
            moveFilesToNewFolder(oldName: originalSubjectName, newName: newName)
        }
        isShowingEditSubjectView = false
    }
    
    private func populateExistingData() {
        // --- CloudKit Fix: Use nil coalescing ---
        for schedule in (subject.schedules ?? []) {
            selectedDays.insert(schedule.day)
            // Convert ClassTime to ClassPeriodTime
            classTimes[schedule.day] = (schedule.classTimes ?? []).map { classTime in
                ClassPeriodTime(startTime: classTime.startTime, endTime: classTime.endTime)
            }
            classCount[schedule.day] = (schedule.classTimes ?? []).count
        }
        // --- End of Fix ---
    }
    
    private func saveUpdatedData() {
        // --- CloudKit Fix: We are assigning a new array, which is fine ---
        subject.schedules = selectedDays.map { day in
            let schedule = Schedule(day: day)
            // Map ClassPeriodTime back to ClassTime
            schedule.classTimes = classTimes[day]?.map { classPeriodTime in
                ClassTime(startTime: classPeriodTime.startTime, endTime: classPeriodTime.endTime, date: Date())
            } ?? []
            return schedule
        }
        // --- End of Fix ---
        
        // Reschedule notifications when data is saved ---
        let subjectToSchedule = subject
        Task {
            await NotificationManager.shared.scheduleNotifications(for: subjectToSchedule)
        }
    }
    
}

// Helper to access a stable identifier when available; optional for SwiftData models
// private extension PersistentModel {
//     var persistentModelID: PersistentIdentifier { self.persistentModelID }
// }

//#Preview {
//    // --- CloudKit Fix: Wrap in helper view to handle do-catch ---
//    struct PreviewWrapper: View {
//        var body: some View {
//            do {
//                // Add ALL models to the container
//                let config = ModelConfiguration(isStoredInMemoryOnly: true)
//                let container = try ModelContainer(for: [
//                    Subject.self,
//                    Attendance.self,
//                    Schedule.self,
//                    ClassTime.self,
//                    Note.self,
//                    Folder.self,
//                    FileMetadata.self,
//                    AttendanceRecord.self
//                ], configurations: config)
//                
//                // Use the default init() and set properties
//                let subject = Subject()
//                subject.name = "Math"
//                subject.startDateOfSubject = Date()
//                subject.schedules = []
//                subject.attendance = Attendance(totalClasses: 10, attendedClasses: 8)
//                
//                container.mainContext.insert(subject)
//                
//                return EditSubjectView(subject: subject, isShowingEditSubjectView: .constant(true))
//                    .modelContainer(container)
//                
//            } catch {
//                return Text("Failed to create container: \(error.localizedDescription)")
//            }
//        }
//    }
//    
//    PreviewWrapper()
//    // --- End of Fix ---
//}

// MARK: Helper Views
extension EditSubjectView {
    func moveFilesToNewFolder(oldName: String, newName: String) {
        let fileManager = FileManager.default
        
        // --- CloudKit Fix: Use FileDataService.baseFolder ---
        let oldFolderURL = FileDataService.baseFolder.appendingPathComponent(oldName)
        let newFolderURL = FileDataService.baseFolder.appendingPathComponent(newName)
        // --- End of Fix ---
        
        do {
            if fileManager.fileExists(atPath: oldFolderURL.path) {
                if !fileManager.fileExists(atPath: newFolderURL.path) {
                    try fileManager.createDirectory(at: newFolderURL, withIntermediateDirectories: true)
                }
                
                let files = try fileManager.contentsOfDirectory(at: oldFolderURL, includingPropertiesForKeys: nil)
                for file in files {
                    let newFileURL = newFolderURL.appendingPathComponent(file.lastPathComponent)
                    try fileManager.moveItem(at: file, to: newFileURL)
                }
                
                // Delete old folder if empty
                let remainingFiles = try fileManager.contentsOfDirectory(atPath: oldFolderURL.path)
                if remainingFiles.isEmpty {
                    try fileManager.removeItem(at: oldFolderURL)
                }
            }
        } catch {
            print("Failed to move files: \(error.localizedDescription)")
        }
    }
    
    // --- CloudKit Fix: This function is now redundant, but we keep it for reference ---
    // We now use FileDataService.baseFolder to get the correct container
    func getFolderURL(for subjectName: String) -> URL {
        // This is the OLD, incorrect path:
        // let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        // return documentsDirectory.appendingPathComponent("Subjects").appendingPathComponent(subjectName)
        
        // This is the NEW, correct path:
        return FileDataService.baseFolder.appendingPathComponent(subjectName)
    }
}
