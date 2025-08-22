import SwiftUI
import SwiftData

// The @MainActor attribute ensures that all UI updates happen on the main thread.
@MainActor
class ProfileViewModel: ObservableObject {
    
    // MARK: - Properties
    
    // --- User Profile Data ---
    @AppStorage("username") var username: String = "Your Name"
    @AppStorage("age") var userDob: Date = Date()
    @AppStorage("collegeName") var collegeName: String = "Your College"
    @AppStorage("email") var email: String = ""
    @AppStorage("profileImage") var profileImageData: Data?
    @AppStorage("gender") var gender: Gender = .male
    
    // --- UI State ---
    @Published var isEditingProfile = false
    
    // --- Attendance History State & Logic ---
    // This is now a 'var' and will be updated by the View.
    var subjects: [Subject] = []
    @Published var filteredLogs: [AttendanceLogEntry] = []
    @Published var selectedFilter: FilterType = .sevenDays
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
        case sixMonths = "6 Months"
        case oneYear = "1 Year"
        case allTime = "All Time"

        var id: String { rawValue }

        func dateThreshold(from date: Date = Date()) -> Date? {
            let calendar = Calendar.current
            switch self {
            case .oneDay: return calendar.date(byAdding: .day, value: -1, to: date)
            case .sevenDays: return calendar.date(byAdding: .day, value: -7, to: date)
            case .oneMonth: return calendar.date(byAdding: .month, value: -1, to: date)
            case .sixMonths: return calendar.date(byAdding: .month, value: -6, to: date)
            case .oneYear: return calendar.date(byAdding: .year, value: -1, to: date)
            case .allTime: return nil
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
    
    // The initializer is now empty.
    init() {}
    
    // MARK: - Methods
    
    func filterAttendanceLogs() {
        let allLogs = subjects.flatMap { subject in
            selectedSubjectName == "All Subjects" || selectedSubjectName == subject.name
                ? subject.logs
                : []
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
