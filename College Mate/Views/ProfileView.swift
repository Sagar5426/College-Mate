//
//  ProfileView.swift
//  College Mate
//
//  Created by Sagar Jangra on 03/01/2025.
//

import SwiftUI
import PhotosUI
import SwiftData

struct ProfileView: View {
    @Binding var isShowingProfileView: Bool
    @AppStorage("username") private var username: String = "Your Name"
    @AppStorage("age") private var userDob: Date = Date()
    @AppStorage("collegeName") private var collegeName: String = "Your College"
    @AppStorage("email") private var email: String = ""
    @AppStorage("profileImage") private var profileImageData: Data?
    @AppStorage("gender") private var gender: Gender = .male
    
    @Query var subjects: [Subject]
    private var allAttendanceLogs: [AttendanceLogEntry] {
           subjects.flatMap { $0.logs }
               .sorted(by: { $0.timestamp > $1.timestamp }) // Most recent first
       }
    
    enum Gender: String, CaseIterable {
        case male = "Male"
        case female = "Female"
        case others = "Others"
    }
    
    var ageCalculated: Int {
        let calendar = Calendar.current
        let currentDate = Date()
        let components = calendar.dateComponents([.year], from: userDob, to: currentDate)
        return components.year ?? 0
    }
    
    @State private var isEditingProfile = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.gray.opacity(0.1), .black.opacity(0.1), .gray.opacity(0.07)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack {
                    Form {
                        ProfileHeaderView(
                            username: username,
                            collegeName: collegeName,
                            profileImageData: profileImageData,
                            ageCalculated: ageCalculated,
                            gender: gender,
                            isEditingProfile: $isEditingProfile
                        )

                        UserDetailsSection(email: $email, userDob: $userDob, gender: $gender)
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)

                    AttendanceHistorySection(subjects: subjects)
                        .padding(20)
                }
                .navigationTitle("Profile")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close", systemImage: "xmark") {
                            isShowingProfileView = false
                        }
                    }
                }
                .sheet(isPresented: $isEditingProfile) {
                    EditProfileView(profileImageData: $profileImageData)
                }
            }
        }

    }
}

// MARK: - Profile Header View
struct ProfileHeaderView: View {
    let username: String
    let collegeName: String
    let profileImageData: Data?
    let ageCalculated: Int
    let gender: ProfileView.Gender
    @Binding var isEditingProfile: Bool
    
    var body: some View {
        Section {
            Button {
                isEditingProfile = true
            } label: {
                HStack(spacing: 12) {
                    ProfileImageView(profileImageData: profileImageData)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(username).font(.headline)
                        Text(collegeName).font(.subheadline).foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .center, spacing: 4) {
                        if ageCalculated != 0 {
                            Text("\(ageCalculated) yrs old").foregroundStyle(.gray).font(.caption)
                        }
                        Text(gender.rawValue).foregroundStyle(.gray).font(.caption)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Profile Image View
struct ProfileImageView: View {
    let profileImageData: Data?
    
    var body: some View {
        if let imageData = profileImageData, let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.circle.fill")
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - User Details Section
struct UserDetailsSection: View {
    @Binding var email: String
    @Binding var userDob: Date
    @Binding var gender: ProfileView.Gender
    
    var body: some View {
        Section("User Details") {
            TextField("Email", text: $email)
            DatePicker("Date of Birth", selection: $userDob, displayedComponents: .date)
            Picker("Gender", selection: $gender) {
                ForEach(ProfileView.Gender.allCases, id: \.self) { genderOption in
                    Text(genderOption.rawValue)
                }
            }
        }
    }
}

// MARK: - Attendance History Section
struct AttendanceHistorySection: View {
    let subjects: [Subject]

    @State private var selectedFilter: FilterType = .sevenDays

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

    var filteredLogs: [AttendanceLogEntry] {
        let allLogs = subjects.flatMap { $0.logs }
        guard let threshold = selectedFilter.dateThreshold() else {
            return allLogs.sorted { $0.timestamp > $1.timestamp }
        }
        return allLogs
            .filter { $0.timestamp >= threshold }
            .sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Filter:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    Menu {
                        ForEach(FilterType.allCases) { filter in
                            Button {
                                selectedFilter = filter
                            } label: {
                                Text(filter.rawValue)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            Text(selectedFilter.rawValue)
                                .font(.subheadline)
                        }
                        .foregroundColor(.blue)
                    }
                }

                ScrollView {
                    LazyVStack(spacing: 0) {
                        if filteredLogs.isEmpty {
                            Text("No attendance changes in this period.")
                                .foregroundColor(.gray)
                                .padding(.vertical)
                        } else {
                            ForEach(filteredLogs.indices, id: \.self) { index in
                                let log = filteredLogs[index]
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(log.action)
                                            .font(.body)
                                        Spacer()
                                        Text(log.timestamp.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    Text(log.subjectName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 10)

                                if index < filteredLogs.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                }
                .frame(minHeight: 150, maxHeight: 350)
            }
        } header: {
            Text("Attendance History")
        }
    }
}






// MARK: - Edit Profile View
struct EditProfileView: View {
    @AppStorage("username") private var username: String = ""
    @AppStorage("collegeName") private var collegeName: String = ""
    @Binding var profileImageData: Data?
    
    @State private var selectedPhoto: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                ProfileImagePicker(profileImageData: $profileImageData, selectedPhoto: $selectedPhoto)
                
                Section("Edit Details") {
                    TextField("Enter your name", text: $username)
                    TextField("College name", text: $collegeName)
                }
            }
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { dismiss() }.bold()
                }
            }
        }
    }
}

// MARK: - Profile Image Picker
struct ProfileImagePicker: View {
    @Binding var profileImageData: Data?
    @Binding var selectedPhoto: PhotosPickerItem?
    
    var body: some View {
        Section {
            HStack {
                Spacer()
                ProfileImageView(profileImageData: profileImageData)
                    .frame(width: 100, height: 100)
                Spacer()
            }
            .padding(.vertical, 8)
            
            PhotosPicker("Change Profile Photo", selection: $selectedPhoto, matching: .images)
                .onChange(of: selectedPhoto) { _, _ in
                    Task {
                        if let data = try? await selectedPhoto?.loadTransferable(type: Data.self) {
                            profileImageData = data
                        }
                    }
                }
        }
    }
}



#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Subject.self, configurations: config)
        
        let subject = Subject(name: "Math", startDateOfSubject: Date(), schedules: [])
        subject.attendance.totalClasses = 5
        subject.attendance.attendedClasses = 3
        subject.logs = [
            AttendanceLogEntry(timestamp: Date(), subjectName: "Math", action: "+ Attended"),
            AttendanceLogEntry(timestamp: Date().addingTimeInterval(-3600), subjectName: "Math", action: "- Missed")
        ]
        
        try container.mainContext.insert(subject)
        
        return ProfileView(isShowingProfileView: .constant(true))
            .modelContainer(container)
    } catch {
        return Text("Failed to create container: \(error.localizedDescription)")
    }
}



