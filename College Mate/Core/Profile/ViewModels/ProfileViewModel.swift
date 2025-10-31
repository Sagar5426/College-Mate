import SwiftUI
import SwiftData
import Combine // <-- Import Combine

// The @MainActor attribute ensures that all UI updates happen on the main thread.
@MainActor
class ProfileViewModel: ObservableObject {
    
    // MARK: - Properties
    
    // --- 1. Private iCloud-synced properties ---
    // Renamed to avoid name collisions with the property wrapper's synthesized properties.
    @iCloudStorage("username") private var syncedUsername: String = "Your Name"
    @iCloudStorage("age") private var syncedUserDob: Date = Date()
    @iCloudStorage("collegeName") private var syncedCollegeName: String = "Your College"
    @iCloudStorage("email") private var syncedEmail: String = ""
    @iCloudStorage("profileImage") private var syncedProfileImageData: Data? = nil
    @iCloudStorage("gender") private var syncedGender: Gender = .male
    
    // --- 2. @Published properties for the UI ---
    // These are what your Views will bind to.
    @Published var username: String = "Your Name"
    @Published var userDob: Date = Date()
    @Published var collegeName: String = "Your College"
    @Published var email: String = ""
    @Published var profileImageData: Data? = nil
    @Published var gender: Gender = .male
    
    // --- UI State (from original file) ---
    @Published var isEditingProfile = false
    @Published var isShowingDatePicker = false
    
    // --- Attendance History State & Logic (from original file) ---
    var subjects: [Subject] = []
    @Published var filteredLogs: [AttendanceLogEntry] = []
    @Published var selectedFilter: FilterType = .sevenDays
    @Published var selectedDate: Date = Date()
    @Published var selectedSubjectName: String = "All Subjects"

    // --- 3. Combine cancellables ---
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Enums (from original file)
    
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
    
    // MARK: - Computed Properties (from original file)
    
    var ageCalculated: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: userDob, to: Date())
        return components.year ?? 0
    }
    
    // MARK: - Initializer (This is the fix)
    
    init() {
        // --- 4. Initialize @Published properties from iCloud ---
        // Load the initial values from the renamed @iCloudStorage wrappers
        self.username = syncedUsername
        self.userDob = syncedUserDob
        self.collegeName = syncedCollegeName
        self.email = syncedEmail
        self.profileImageData = syncedProfileImageData
        self.gender = syncedGender
        
        // --- 5. Set up two-way data binding ---
        
        // A. BIND: @Published UI property -> @iCloudStorage
        // When the user edits a @Published property in the UI,
        // we subscribe (sink) to that change and manually set the
        // value of our @iCloudStorage property.
        
        $username
            .dropFirst() // Don't save the initial value on load
            .debounce(for: 0.5, scheduler: DispatchQueue.main) // Wait for user to stop typing
            .sink { [weak self] newValue in
                self?.syncedUsername = newValue
            }
            .store(in: &cancellables)
            
        $userDob
            .dropFirst()
            .sink { [weak self] newValue in
                self?.syncedUserDob = newValue
            }
            .store(in: &cancellables)
            
        $collegeName
            .dropFirst()
            .debounce(for: 0.5, scheduler: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.syncedCollegeName = newValue
            }
            .store(in: &cancellables)
            
        $email
            .dropFirst()
            .debounce(for: 0.5, scheduler: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.syncedEmail = newValue
            }
            .store(in: &cancellables)
            
        $profileImageData
            .dropFirst()
            .sink { [weak self] newValue in
                self?.syncedProfileImageData = newValue
            }
            .store(in: &cancellables)
            
        $gender
            .dropFirst()
            .sink { [weak self] newValue in
                self?.syncedGender = newValue
            }
            .store(in: &cancellables)
            
        // B. BIND: @iCloudStorage publisher -> @Published UI property
        // When iCloud pushes a change, the @iCloudStorage wrapper's publisher
        // (projectedValue) will fire. We subscribe to that and update
        // our @Published property, which updates the UI.
        
        // --- THIS IS THE FIX ---
        // The projected value ($syncedUsername) *is* the publisher.
        // We do not need to add `.publisher` to it.
        
        $syncedUsername // <-- Removed .publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.username = newValue // <-- This is now correctly a String
            }
            .store(in: &cancellables)
            
        $syncedUserDob // <-- Removed .publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.userDob = newValue
            }
            .store(in: &cancellables)
            
        $syncedCollegeName // <-- Removed .publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.collegeName = newValue
            }
            .store(in: &cancellables)
            
        $syncedEmail // <-- Removed .publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.email = newValue
            }
            .store(in: &cancellables)
            
        $syncedProfileImageData // <-- Removed .publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.profileImageData = newValue
            }
            .store(in: &cancellables)
            
        $syncedGender // <-- Removed .publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.gender = newValue
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Methods (from original file)
    
    func filterAttendanceLogs() {
        // Note: 'subject.logs' was not a relationship and should not be optional.
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

