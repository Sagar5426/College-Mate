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
                LinearGradient(colors: [.gray.opacity(0.1), .black.opacity(0.1), .gray.opacity(0.07)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                Form {
                    Section(header: Text("Subject Details")) {
                        TextField("Subject Name (Max 20 Characters)", text: $subject.name)
                            .onChange(of: subject.name) {
                                subject.name = String(subject.name.prefix(characterLimit))
                            }
                    }
                    FirstSubjectDatePicker(startDateOfSubject: $subject.startDateOfSubject)
                    MinimumAttendenceStepper(MinimumAttendancePercentage: Binding<Int>(
                        get: { Int(subject.attendance.minimumPercentageRequirement) }, // Convert Double to Int
                        set: { subject.attendance.minimumPercentageRequirement = Double($0) } // Convert Int back to Double
                    ))
                    
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
        let newName = subject.name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for duplicates only if the name has changed
        if newName.lowercased() != originalSubjectName.lowercased() {
            if subjects.contains(where: { $0.name.lowercased() == newName.lowercased() }) {
                isShowingDuplicateAlert = true
                subject.name = originalSubjectName // Revert to original name
                return
            }
        }
        
        // If validation passes, move files and dismiss
        if originalSubjectName != newName {
            moveFilesToNewFolder(oldName: originalSubjectName, newName: newName)
        }
        isShowingEditSubjectView = false
    }
    
    private func populateExistingData() {
        for schedule in subject.schedules {
            selectedDays.insert(schedule.day)
            // Convert ClassTime to ClassPeriodTime
            classTimes[schedule.day] = schedule.classTimes.map { classTime in
                ClassPeriodTime(startTime: classTime.startTime, endTime: classTime.endTime)
            }
            classCount[schedule.day] = schedule.classTimes.count
        }
    }
    
    private func saveUpdatedData() {
        subject.schedules = selectedDays.map { day in
            Schedule(
                day: day,
                classTimes: classTimes[day]?.map { classPeriodTime in
                    ClassTime(startTime: classPeriodTime.startTime, endTime: classPeriodTime.endTime, date: Date())
                } ?? []
            )
        }
    }
    
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Subject.self, configurations: config)
        let subject = Subject(name: "Math", startDateOfSubject: Date(), schedules: [])
        return EditSubjectView(subject: subject, isShowingEditSubjectView: .constant(true))
            .modelContainer(container)
    } catch {
        return Text("Failed to create container: \(error.localizedDescription)")
    }
}

// MARK: Helper Views
extension EditSubjectView {
    func moveFilesToNewFolder(oldName: String, newName: String) {
        let fileManager = FileManager.default
        let oldFolderURL = getFolderURL(for: oldName)
        let newFolderURL = getFolderURL(for: newName)
        
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
    
    func getFolderURL(for subjectName: String) -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("Subjects").appendingPathComponent(subjectName)
    }
}
