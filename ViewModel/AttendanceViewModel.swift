import SwiftUI
import SwiftData

@MainActor
class AttendanceViewModel: ObservableObject {
    
    // MARK: - Properties
    @Published var selectedDate = Date()
    @Published var isHoliday = false
    @Published var isShowingDatePicker = false
    @Published var isShowingProfileView = false
    @Published var scheduledSubjects: [Subject] = []
    
    private var allSubjects: [Subject] = []
    private var modelContext: ModelContext?
    
    // MARK: - Initializer
    init() {}
    
    // MARK: - Public Methods
    
    func setup(subjects: [Subject], modelContext: ModelContext) {
        self.allSubjects = subjects
        self.modelContext = modelContext
        filterScheduledSubjects()
    }

    func moveToPreviousDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        isHoliday = false
        filterScheduledSubjects()
    }
    
    func moveToNextDay() {
        let today = Calendar.current.startOfDay(for: Date())
        let nextDay = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate)
        
        if nextDay <= today {
            selectedDate = nextDay
            isHoliday = false
            filterScheduledSubjects()
        }
    }
    
    // --- Core Logic ---
    
    // For a given class, find its unique record for the selected date.
    // If it doesn't exist, create it.
    func record(for classTime: ClassTime, in subject: Subject) -> AttendanceRecord {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: selectedDate)
        
        if let existingRecord = subject.records.first(where: { record in
            let recordDate = calendar.startOfDay(for: record.date)
            return record.classTimeID == classTime.id && recordDate == targetDate
        }) {
            return existingRecord
        } else {
            // Create a new record on-demand if one doesn't exist for this day.
            let newRecord = AttendanceRecord(date: targetDate, status: "Canceled", classTimeID: classTime.id)
            newRecord.subject = subject
            modelContext?.insert(newRecord)
            // subject.records.append(newRecord) // SwiftData handles this via relationship
            return newRecord
        }
    }
    
    func updateAttendance(for record: AttendanceRecord, in subject: Subject, to newStatus: String) {
        let oldStatus = record.status
        guard oldStatus != newStatus else { return }

        // --- Attendance Calculation Logic ---
        // Attended
        if newStatus == "Attended" {
            if oldStatus == "Not Attended" { subject.attendance.attendedClasses += 1 }
            else if oldStatus == "Canceled" {
                subject.attendance.attendedClasses += 1
                subject.attendance.totalClasses += 1
            }
        }
        // Not Attended
        else if newStatus == "Not Attended" {
            if oldStatus == "Attended" { subject.attendance.attendedClasses -= 1 }
            else if oldStatus == "Canceled" { subject.attendance.totalClasses += 1 }
        }
        // Canceled
        else if newStatus == "Canceled" {
            if oldStatus == "Attended" {
                subject.attendance.attendedClasses -= 1
                subject.attendance.totalClasses -= 1
            } else if oldStatus == "Not Attended" {
                subject.attendance.totalClasses -= 1
            }
        }
        
        // Update the record's status
        record.status = newStatus
        
        // Log the change
        let logAction = newStatus == "Attended" ? "+ Attended" : (newStatus == "Not Attended" ? "- Missed" : "ø Canceled")
        let log = AttendanceLogEntry(timestamp: Date(), subjectName: subject.name, action: logAction)
        subject.logs.append(log)
    }
    
    private func filterScheduledSubjects() {
        let dayOfWeek = selectedDate.formatted(Date.FormatStyle().weekday(.wide))
        scheduledSubjects = allSubjects.filter { subject in
            guard selectedDate >= subject.startDateOfSubject else { return false }
            return subject.schedules.contains { $0.day == dayOfWeek }
        }
    }
}
