import SwiftUI
import SwiftData
import Combine

// The @MainActor attribute ensures that all UI updates happen on the main thread.
@MainActor
class ProfileViewModel: ObservableObject {
    
    // MARK: - Properties
    
    // --- Notification Settings ---
    @AppStorage("notificationsEnabled") var notificationsEnabled: Bool = false
    @AppStorage("notificationLeadMinutes") var notificationLeadMinutes: Int = 10
    
    // --- 1. Private iCloud-synced properties ---
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
    
    // --- 4. ADDED: Sync State Properties ---
    @Published var isSyncing: Bool = false
    @Published var lastSyncedTime: Date?
    
    // --- 5. UPDATED: Removed notification observer, kept task manager ---
    private var syncTask: Task<Void, Error>?

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
            case .selectDate: return nil
            }
        }
    }
    
    // MARK: - Notification Lead Time Options
    enum NotificationLeadOption: Int, CaseIterable, Identifiable {
        case five = 5
        case ten = 10
        case fifteen = 15
        case twenty = 20
        
        var id: Int { rawValue }
        var title: String { "\(rawValue) min" }
    }
    
    var leadOptions: [NotificationLeadOption] { NotificationLeadOption.allCases }
    
    var leadTimeInSeconds: TimeInterval { TimeInterval(notificationLeadMinutes * 60) }
    
    // MARK: - Computed Properties (from original file)
    
    var ageCalculated: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: userDob, to: Date())
        return components.year ?? 0
    }
    
    // MARK: - Initializer 
    
    init() {
        // --- 4. Initialize @Published properties from iCloud ---
        // Load the initial values from the renamed @iCloudStorage wrappers
        self.username = syncedUsername
        self.userDob = syncedUserDob
        self.collegeName = syncedCollegeName
        self.email = syncedEmail
        self.profileImageData = syncedProfileImageData
        self.gender = syncedGender
        
        // --- ADDED: Load last synced time from UserDefaults
        let lastSyncTimestamp = UserDefaults.standard.double(forKey: "profileLastSyncedTime")
        if lastSyncTimestamp > 0 {
            self.lastSyncedTime = Date(timeIntervalSince1970: lastSyncTimestamp)
        }
        
        // --- 5. Set up two-way data binding ---
        
        $username
            .dropFirst() // Don't save the initial value on load
            .debounce(for: 0.5, scheduler: DispatchQueue.main)
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
        
        
        $syncedUsername
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.username = newValue
            }
            .store(in: &cancellables)
            
        $syncedUserDob
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.userDob = newValue
            }
            .store(in: &cancellables)
            
        $syncedCollegeName
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.collegeName = newValue
            }
            .store(in: &cancellables)
            
        $syncedEmail
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.email = newValue
            }
            .store(in: &cancellables)
            
        $syncedProfileImageData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.profileImageData = newValue
            }
            .store(in: &cancellables)
            
        $syncedGender
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                self?.gender = newValue
            }
            .store(in: &cancellables)
            
        // Now that all observers are set up, request an initial sync
        // to populate the UI with the latest data.
        print("[ProfileViewModel] Init: Requesting initial sync...")
        NSUbiquitousKeyValueStore.default.synchronize()
    }
    
    // MARK: - UPDATED: Sync Method
    
    @MainActor
    func triggerSync() {
        guard !isSyncing else { return }
        
        isSyncing = true
        
        // Cancel any previous sync task that might be lingering
        syncTask?.cancel()
        
        let store = NSUbiquitousKeyValueStore.default
        
        // 1. Request the sync.
        store.synchronize()
        print("[ProfileViewModel] triggerSync: Requesting sync...")

        // 2. Start an async task to wait, then force re-read the data.
        syncTask = Task {
            do {
                // Give the OS 10 seconds to fetch the data from iCloud.
                // This matches your observation that the sync
                // takes about 5-10 seconds to complete.
                try await Task.sleep(for: .seconds(10))
                
                // If the task wasn't cancelled, proceed to stop.
                await MainActor.run {
                    print("[ProfileViewModel] 10s delay complete. Forcing UI refresh from store.")
                    self.forceReadFromStore()
                    self.stopSyncing()
                }
                
            } catch {
                // This catches the cancellation, which is normal.
                print("[ProfileViewModel] Sync task was cancelled.")
                await MainActor.run {
                    self.isSyncing = false // Ensure spinner stops if cancelled
                }
            }
        }
    }
    
    // --- UPDATED: New helper function ---
    @MainActor
    private func forceReadFromStore() {
        print("[ProfileViewModel] forceReadFromStore: Re-reading all values directly from store.")
        
        let store = NSUbiquitousKeyValueStore.default
        
        // This explicitly bypasses the @iCloudStorage wrappers and reads
        // the latest values directly from the key-value store.
        self.username = (store.object(forKey: "username") as? String) ?? self.username
        self.userDob = (store.object(forKey: "age") as? Date) ?? self.userDob
        self.collegeName = (store.object(forKey: "collegeName") as? String) ?? self.collegeName
        self.email = (store.object(forKey: "email") as? String) ?? self.email
        self.profileImageData = store.object(forKey: "profileImage") as? Data
        self.gender = (store.object(forKey: "gender") as? Gender.RawValue)
            .flatMap(Gender.init) ?? self.gender
    }
    
    @MainActor
    private func stopSyncing() {
        guard isSyncing else { return }
        
        print("[ProfileViewModel] Sync complete. Updating UI.")
        isSyncing = false
        
        let now = Date()
        self.lastSyncedTime = now
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: "profileLastSyncedTime")
        
        // Clean up task
        syncTask = nil
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







