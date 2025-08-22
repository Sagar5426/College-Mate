import SwiftUI
import PhotosUI
import SwiftData

struct ProfileView: View {
    @Binding var isShowingProfileView: Bool
    @Query var subjects: [Subject]
    
    // The ViewModel is now initialized directly.
    @StateObject private var viewModel = ProfileViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.gray.opacity(0.1), .black.opacity(0.1), .gray.opacity(0.07)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                VStack {
                    Form {
                        ProfileHeaderView(viewModel: viewModel)
                        UserDetailsSection(viewModel: viewModel)
                        AttendanceHistorySection(viewModel: viewModel)
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                }
                .navigationTitle("Profile")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close", systemImage: "xmark") {
                            isShowingProfileView = false
                        }
                    }
                }
                .sheet(isPresented: $viewModel.isEditingProfile) {
                    EditProfileView(viewModel: viewModel)
                }
                // --- FIX IS HERE ---
                // This block ensures the ViewModel always has the latest data.
                .onAppear {
                    // Update the ViewModel when the view first appears.
                    viewModel.subjects = subjects
                    viewModel.filterAttendanceLogs()
                }
                .onChange(of: subjects) {
                    // Update the ViewModel whenever the @Query data changes.
                    viewModel.subjects = subjects
                    viewModel.filterAttendanceLogs()
                }
                .onChange(of: viewModel.selectedFilter) { viewModel.filterAttendanceLogs() }
                .onChange(of: viewModel.selectedSubjectName) { viewModel.filterAttendanceLogs() }
            }
        }
    }
}

// MARK: - Profile Header View
struct ProfileHeaderView: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        Section {
            Button {
                viewModel.isEditingProfile = true
            } label: {
                HStack(spacing: 12) {
                    ProfileImageView(profileImageData: viewModel.profileImageData)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.username).font(.headline)
                        Text(viewModel.collegeName).font(.subheadline).foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .center, spacing: 4) {
                        if viewModel.ageCalculated != 0 {
                            Text("\(viewModel.ageCalculated) yrs old").foregroundStyle(.gray).font(.caption)
                        }
                        Text(viewModel.gender.rawValue).foregroundStyle(.gray).font(.caption)
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
                .resizable().scaledToFill().frame(width: 60, height: 60).clipShape(Circle())
        } else {
            Image(systemName: "person.circle.fill")
                .resizable().scaledToFill().frame(width: 60, height: 60).foregroundColor(.gray)
        }
    }
}

// MARK: - User Details Section
struct UserDetailsSection: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    var body: some View {
        Section("User Details") {
            TextField("Email", text: $viewModel.email)
            DatePicker("Date of Birth", selection: $viewModel.userDob, displayedComponents: .date)
            Picker("Gender", selection: $viewModel.gender) {
                ForEach(ProfileViewModel.Gender.allCases, id: \.self) { genderOption in
                    Text(genderOption.rawValue)
                }
            }
        }
    }
}

// MARK: - Attendance History Section
struct AttendanceHistorySection: View {
    @ObservedObject var viewModel: ProfileViewModel

    var body: some View {
        Section(header: Text("Attendance History")) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Menu {
                        Button("All Subjects") { viewModel.selectedSubjectName = "All Subjects" }
                        ForEach(viewModel.subjects, id: \.id) { subject in
                            Button(subject.name) { viewModel.selectedSubjectName = subject.name }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "book.closed")
                            Text(viewModel.selectedSubjectName)
                        }
                        .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    Menu {
                        ForEach(ProfileViewModel.FilterType.allCases) { filter in
                            Button(filter.rawValue) { viewModel.selectedFilter = filter }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text(viewModel.selectedFilter.rawValue)
                        }
                        .foregroundColor(.blue)
                    }
                }

                if viewModel.filteredLogs.isEmpty {
                    Text("No attendance changes in this period.")
                        .foregroundColor(.gray).padding(.vertical)
                } else {
                    ForEach(viewModel.filteredLogs) { log in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(log.action)
                                Spacer()
                                Text(log.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundColor(.gray)
                            }
                            Text(log.subjectName)
                                .font(.caption).foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
}

// MARK: - Edit Profile View
struct EditProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    @State private var selectedPhoto: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                ProfileImagePicker(profileImageData: $viewModel.profileImageData, selectedPhoto: $selectedPhoto)
                
                Section("Edit Details") {
                    TextField("Enter your name", text: $viewModel.username)
                    TextField("College name", text: $viewModel.collegeName)
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
                .onChange(of: selectedPhoto) {
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
    // The preview no longer needs to manually fetch and pass subjects.
    // The @Query inside ProfileView will handle it within the preview context.
    ProfileView(isShowingProfileView: .constant(true))
        .modelContainer(for: Subject.self, inMemory: true)
}
