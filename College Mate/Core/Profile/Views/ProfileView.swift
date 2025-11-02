import SwiftUI
import PhotosUI
import SwiftData

// ADDED: A helper to format the time nicely
extension DateFormatter {
    static let shortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

struct ProfileView: View {
    @Binding var isShowingProfileView: Bool
    @Query var subjects: [Subject]
    
    @EnvironmentObject var authService: AuthenticationService
    
    @StateObject private var viewModel = ProfileViewModel()
    
    // State to control the PhotosPicker is now here, in the parent view.
    @State private var isShowingPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isShowingCropper = false
    @State private var imageToCrop: UIImage? = nil
    
    // MARK: 1. ADDED State for Sign Out Animation
    @State private var isSigningOut = false
    
    var body: some View {
        // MARK: 2. ADDED ZStack wrapper for overlay
        ZStack {
            NavigationStack {
                ZStack {
                    Color(UIColor.systemGroupedBackground).ignoresSafeArea()

                    VStack {
                        Form {
                            ProfileHeaderView(viewModel: viewModel)
                            UserDetailsSection(viewModel: viewModel)
                            
                            Section {
                                Toggle(isOn: $viewModel.notificationsEnabled) {
                                    Label("Send Notifications", systemImage: "bell")
                                }
                                
                                // Lead time picker appears only when notifications are enabled
                                if viewModel.notificationsEnabled {
                                    Picker("Prior notification time", selection: $viewModel.notificationLeadMinutes) {
                                        ForEach(viewModel.leadOptions) { option in
                                            Text(option.title).tag(option.rawValue)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    Text("This sets how long before class you’ll receive a prior notification.")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            } header: {
                                Text("Notifications")
                                    .foregroundColor(.gray)
                            }
                            .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
                            
                            Section {
                                HStack {
                                    if viewModel.isSyncing {
                                        ProgressView()
                                            .padding(.trailing, 4)
                                        Text("Syncing Profile...")
                                            .foregroundColor(.secondary)
                                    } else {
                                        Button(action: { viewModel.triggerSync() }) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "arrow.clockwise")
                                                Text("Sync Now")
                                            }
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .foregroundColor(.accentColor)
                                    }
                                    
                                    Spacer()
                                    
                                    if let lastSyncedTime = viewModel.lastSyncedTime {
                                        Text("Last: \(lastSyncedTime, formatter: DateFormatter.shortTime)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("Ready to sync")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            } header: {
                                Text("Profile Sync (iCloud)")
                                    .foregroundColor(.gray)
                            }
                            .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
                            
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
                        // MARK: 3. UPDATED to pass isSigningOut binding
                        EditProfileView(
                            viewModel: viewModel,
                            isShowingPhotoPicker: $isShowingPhotoPicker,
                            authService: authService,
                            isSigningOut: $isSigningOut
                        )
                    }
                    .sheet(isPresented: $viewModel.isShowingDatePicker) {
                        ProfileDatePickerSheet(viewModel: viewModel)
                    }
                    .onAppear {
                        viewModel.subjects = subjects
                        viewModel.filterAttendanceLogs()
                    }
                    .onChange(of: subjects) {
                        viewModel.subjects = subjects
                        viewModel.filterAttendanceLogs()
                    }
                    .onChange(of: viewModel.selectedFilter) {
                        if viewModel.selectedFilter != .selectDate {
                            viewModel.filterAttendanceLogs()
                        }
                    }
                    .onChange(of: viewModel.selectedSubjectName) { viewModel.filterAttendanceLogs() }
                }
            }
            .photosPicker(isPresented: $isShowingPhotoPicker, selection: $selectedPhoto, matching: .images)
            .onChange(of: selectedPhoto) {
                Task {
                    if let data = try? await selectedPhoto?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        imageToCrop = uiImage
                        isShowingCropper = true
                    }
                }
            }
            .fullScreenCover(isPresented: $isShowingCropper) {
                if let imageToCrop {
                    ProfileImageCropperFullScreen(image: imageToCrop, viewModel: viewModel, isPresented: $isShowingCropper)
                }
            }
            .onChange(of: isShowingCropper) {
                if !isShowingCropper {
                    imageToCrop = nil
                    selectedPhoto = nil
                }
            }
            
            // MARK: 4. ADDED overlay for signing out
            if isSigningOut {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity.animation(.easeIn(duration: 0.2)))
                
                ProgressView("Signing Out...")
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(10)
                    .foregroundColor(.white)
                    .transition(.opacity.animation(.easeIn(duration: 0.2)))
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
                        Text(viewModel.username.isEmpty ? "Your Name" : viewModel.username)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(viewModel.collegeName.isEmpty ? "Your College" : viewModel.collegeName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
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
        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
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
        Section {
            TextField("Email", text: $viewModel.email)
            DatePicker("Date of Birth", selection: $viewModel.userDob, displayedComponents: .date)
            Picker("Gender", selection: $viewModel.gender) {
                ForEach(ProfileViewModel.Gender.allCases, id: \.self) { genderOption in
                    Text(genderOption.rawValue)
                }
            }
        } header: {
            Text("User Details")
                .foregroundColor(.gray)
        }
        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
    }
}

// MARK: - Attendance History Section
struct AttendanceHistorySection: View {
    @ObservedObject var viewModel: ProfileViewModel

    var body: some View {
        Section {
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
                        Button(ProfileViewModel.FilterType.oneDay.rawValue) { viewModel.selectedFilter = .oneDay }
                        Button(ProfileViewModel.FilterType.sevenDays.rawValue) { viewModel.selectedFilter = .sevenDays }
                        Button(ProfileViewModel.FilterType.oneMonth.rawValue) { viewModel.selectedFilter = .oneMonth }
                        Button(ProfileViewModel.FilterType.allHistory.rawValue) { viewModel.selectedFilter = .allHistory }
                        
                        Divider()
                        Button(ProfileViewModel.FilterType.selectDate.rawValue) {
                            viewModel.selectedFilter = .selectDate
                            viewModel.isShowingDatePicker = true
                        }

                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text(viewModel.selectedFilter == .selectDate ? viewModel.selectedDate.formatted(.dateTime.day().month().year()) : viewModel.selectedFilter.rawValue)
                        }
                        .foregroundColor(.blue)
                    }
                }
                .padding(.bottom, 8)

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
        } header: {
            Text("Attendance History")
                .foregroundColor(.gray)
        }
        .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
    }
}

// MARK: - Edit Profile View (UI Updated)
struct EditProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Binding var isShowingPhotoPicker: Bool
    @ObservedObject var authService: AuthenticationService
    
    // MARK: 1. ADDED binding for sign out animation
    @Binding var isSigningOut: Bool
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            // 2. Adjusted spacing for the new button
            VStack(spacing: 20) {
                // Use a small spacer for top padding
                Spacer().frame(height: 32)
                
                // --- Profile Image Section ---
                Button(action: {
                    // Dismiss the edit sheet first, then present the photo picker slightly later
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        isShowingPhotoPicker = true
                    }
                }) {
                    ZStack(alignment: .bottomTrailing) {
                        if let imageData = viewModel.profileImageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable().scaledToFill()
                                .frame(width: 120, height: 120).clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable().scaledToFill()
                                .frame(width: 120, height: 120).foregroundColor(.gray.opacity(0.5))
                        }

                        Image(systemName: "camera.circle.fill")
                            .font(.system(size: 32)).foregroundColor(.accentColor)
                            .background(Circle().fill(Color(UIColor.systemGroupedBackground)))
                            .offset(x: 4, y: 4)
                    }
                }
                .padding(.bottom, 20) // Add padding after image
                
                // --- TextFields Section ---
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "person.fill").foregroundColor(.gray)
                        TextField("Enter your name", text: $viewModel.username)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .background(Color(UIColor.tertiarySystemFill))
                    .cornerRadius(12)
                    
                    HStack {
                        Image(systemName: "graduationcap.fill").foregroundColor(.gray)
                        TextField("Enter your college name", text: $viewModel.collegeName)
                             .foregroundColor(.primary)
                    }
                    .padding()
                    .background(Color(UIColor.tertiarySystemFill))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // MARK: 2. UPDATED Sign Out Button Action
                Button(role: .destructive) {
                    // 1. Dismiss the sheet
                    dismiss()
                    
                    // 2. Wait for sheet to dismiss, then trigger animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        // 3. Fade in the overlay
                        withAnimation(.easeIn(duration: 0.2)) {
                            isSigningOut = true
                        }
                        
                        // 4. Wait for "medium speed" animation, then log out
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            authService.logout()
                            // No need to set isSigningOut = false, the view will be gone
                        }
                    }
                } label: {
                    Text("Sign Out")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(UIColor.tertiarySystemFill))
                        .foregroundColor(.red)
                        .cornerRadius(12)
                }
                .padding(.horizontal) // Match text fields
                .padding(.bottom, 20) // Padding from bottom edge
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { dismiss() }.bold() }
            }
        }
    }
}

// MARK: - Date Picker Sheet (extracted)
private struct ProfileDatePickerSheet: View {
    @ObservedObject var viewModel: ProfileViewModel

    var body: some View {
        VStack {
            DatePicker(
                "Select a Date",
                selection: $viewModel.selectedDate,
                in: ...Date(), // Users can't select a future date
                displayedComponents: .date
            )
            .datePickerStyle(GraphicalDatePickerStyle())
            .padding() // Added padding around the date picker
            
            Button(action: {
                viewModel.isShowingDatePicker = false
                viewModel.filterAttendanceLogs()
            }) {
                Text("Done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal) // Padding for the button
        }
        .padding(.vertical) // Overall vertical padding for the sheet content
        .presentationDetents([.medium])
    }
}

// MARK: - Image Cropper Full Screen
private struct ProfileImageCropperFullScreen: View {
    let image: UIImage
    @ObservedObject var viewModel: ProfileViewModel
    @Binding var isPresented: Bool

    var body: some View {
        // Replaced the placeholder VStack with the actual ImageCropService call
        ImageCropService(
            image: image,
            onCrop: { cropped in
                if let data = cropped.jpegData(compressionQuality: 0.5) {
                    viewModel.profileImageData = data
                }
            },
            isPresented: $isPresented
        )
        .ignoresSafeArea()
    }
}


#Preview {
    ProfileView(isShowingProfileView: .constant(true))
        .modelContainer(for: Subject.self, inMemory: true)
        // 4. Added auth service to preview
        .environmentObject(AuthenticationService())
        .preferredColorScheme(.dark)
}

