//
//  ProfileView.swift
//  College Mate
//
//  Created by Sagar Jangra on 03/01/2025.
//

import SwiftUI
import PhotosUI

struct ProfileView: View {
    @Binding var isShowingProfileView: Bool
    @AppStorage("username") private var username: String = "Your Name"
    @AppStorage("age") private var userDob: Date = Date()
    @AppStorage("collegeName") private var collegeName: String = "Your College"
    @AppStorage("email") private var email: String = ""
    @AppStorage("profileImage") private var profileImageData: Data?
    @AppStorage("gender") private var gender: Gender = .male
    
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
                    
                    AttendanceHistorySection()
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
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
    var body: some View {
        Section("History of Attendance changed") {
            List {
                ForEach(1..<10) { _ in
                    Text("Attendance +")
                }
            }
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
    ProfileView(isShowingProfileView: .constant(true))
}
