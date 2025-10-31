import SwiftUI
import SwiftData

// The @MainActor attribute ensures that all UI updates happen on the main thread.
@MainActor
class ProfileViewModel: ObservableObject {
    
    // MARK: - Properties
    
    // --- User Profile Data ---
    @iCloudStorage("username") var username: String = "Your Name"
    @iCloudStorage("age") var userDob: Date = Date()
    @iCloudStorage("collegeName") var collegeName: String = "Your College"
    @iCloudStorage("email") var email: String = ""
    @iCloudStorage("profileImage") var profileImageData: Data? = nil
    @iCloudStorage("gender") var gender: Gender = .male
    
    // --- UI State ---
    @Published var isEditingProfile = false
    @Published var isShowingDatePicker = false
    
    // --- Attendance History State & Logic ---
    var subjects: [Subject] = []
    @Published var filteredLogs: [AttendanceLogEntry] = []
    @Published var selectedFilter: FilterType = .sevenDays
    @Published var selectedDate: Date = Date()
    @Published var selectedSubjectName: String = "All Subjects"

    // MARK: - Enums
    
    enum Gender: String, CaseIterable {
        case male = "Male"
        case female = "Female"
        case others = "Others"
    }
    
    enum FilterType: String, CaseIterable, Identifiable {
        case oneDay = "1 Day"
        case sevenDays = "7 Days"
        case oneMonth = "1 Month"
        case allHistory = "All History"
        case selectDate = "Select Date"

        var id: String { rawValue }

        func dateThreshold(from date: Date = Date()) -> Date? {
            let calendar = Calendar.current
            switch self {
            case .oneDay: return calendar.date(byAdding: .day, value: -1, to: date)
            case .sevenDays: return calendar.date(byAdding: .day, value: -7, to: date)
            case .oneMonth: return calendar.date(byAdding: .month, value: -1, to: date)
            case .allHistory: return nil
            case .selectDate: return nil // Special handling
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var ageCalculated: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: userDob, to: Date())
        return components.year ?? 0
    }
    
    // MARK: - Initializer
    
    init() {}
    
    // MARK: - Methods
    
    func filterAttendanceLogs() {
        let allLogs = subjects.flatMap { subject in
            selectedSubjectName == "All Subjects" || selectedSubjectName == subject.name
                ? subject.logs
                : []
        }

        if selectedFilter == .selectDate {
            filteredLogs = allLogs
                .filter { Calendar.current.isDate($0.timestamp, inSameDayAs: selectedDate) }
                .sorted { $0.timestamp > $1.timestamp }
            return
        }

        guard let threshold = selectedFilter.dateThreshold() else {
            filteredLogs = allLogs.sorted { $0.timestamp > $1.timestamp }
            return
        }

        filteredLogs = allLogs
            .filter { $0.timestamp >= threshold }
            .sorted { $0.timestamp > $1.timestamp }
    }
}

