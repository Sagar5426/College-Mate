import SwiftUI
import PhotosUI
import SwiftData

struct ProfileView: View {
    @Binding var isShowingProfileView: Bool
    @Query var subjects: [Subject]
    
    @StateObject private var viewModel = ProfileViewModel()
    
    // State to control the PhotosPicker is now here, in the parent view.
    @State private var isShowingPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Using a darker, more solid background for better contrast
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()

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
                    // We now pass a binding to our new state variable into the sheet.
                    EditProfileView(viewModel: viewModel, isShowingPhotoPicker: $isShowingPhotoPicker)
                }
                .sheet(isPresented: $viewModel.isShowingDatePicker) {
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
                .onAppear {
                    viewModel.subjects = subjects
                    viewModel.filterAttendanceLogs()
                }
                .onChange(of: subjects) {
                    viewModel.subjects = subjects
                    viewModel.filterAttendanceLogs()
                }
                .onChange(of: viewModel.selectedFilter) {
                    // We only need to filter if the selection is NOT for a specific date,
                    // as that case is handled by its own button and the sheet's Done button.
                    if viewModel.selectedFilter != .selectDate {
                        viewModel.filterAttendanceLogs()
                    }
                }
                .onChange(of: viewModel.selectedSubjectName) { viewModel.filterAttendanceLogs() }
            }
        }
        // The PhotosPicker is now attached to the main view, not the sheet.
        // It is presented when isShowingPhotoPicker becomes true.
        .photosPicker(isPresented: $isShowingPhotoPicker, selection: $selectedPhoto, matching: .images)
        // When a photo is selected, this modifier handles the data loading.
        .onChange(of: selectedPhoto) {
            Task {
                if let data = try? await selectedPhoto?.loadTransferable(type: Data.self) {
                    viewModel.profileImageData = data
                }
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
                            .foregroundColor(.primary) // Ensure primary visibility
                        
                        // FIX: Using .secondary semantic color for guaranteed visibility.
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
                        // Displaying the updated filter options
                        Button(ProfileViewModel.FilterType.oneDay.rawValue) { viewModel.selectedFilter = .oneDay }
                        Button(ProfileViewModel.FilterType.sevenDays.rawValue) { viewModel.selectedFilter = .sevenDays }
                        Button(ProfileViewModel.FilterType.oneMonth.rawValue) { viewModel.selectedFilter = .oneMonth }
                        Button(ProfileViewModel.FilterType.allHistory.rawValue) { viewModel.selectedFilter = .allHistory }
                        
                        // Select Date option is now separate and at the bottom
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
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                // --- Profile Image Section ---
                Button(action: {
                    isShowingPhotoPicker = true
                    dismiss()
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
                
                // --- TextFields Section ---
                VStack(spacing: 16) {
                    // FIX: Simplified TextField and used semantic system colors for background.
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
                Spacer()
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


#Preview {
    ProfileView(isShowingProfileView: .constant(true))
        .modelContainer(for: Subject.self, inMemory: true)
        .preferredColorScheme(.dark)
}

