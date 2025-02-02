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
            Form {
                Section {
                    Button {
                        isEditingProfile = true
                    } label: {
                        HStack(spacing: 12) {
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
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(username)
                                    .font(.headline)
                                Text(collegeName)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .center, spacing: 4) {
                                if ageCalculated != 0 {
                                    Text("\(ageCalculated) yrs old")
                                        .foregroundStyle(.gray)
                                        .font(.caption)
                                }
                                Text("\(gender)")
                                    .foregroundStyle(.gray)
                                    .font(.caption)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section("User Details") {
                    TextField("Email", text: $email)
                    DatePicker("Date of Birth", selection: $userDob, displayedComponents: .date)
                    Picker("Gender", selection: $gender) {
                        ForEach(Gender.allCases, id: \.self) { genderOption in
                            Text(genderOption.rawValue)
                        }
                    }
                }
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

struct EditProfileView: View {
    @AppStorage("username") private var username: String = ""
    @AppStorage("collegeName") private var collegeName: String = ""
    @Binding var profileImageData: Data?

    @State private var selectedPhoto: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        if let imageData = profileImageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)

                    PhotosPicker("Change Profile Photo", selection: $selectedPhoto, matching: .images)
                        .onChange(of: selectedPhoto) { _ , _ in
                            Task {
                                if let data = try? await selectedPhoto?.loadTransferable(type: Data.self) {
                                    profileImageData = data
                                }
                            }
                        }
                    
                }

                Section("Edit Details") {
                    TextField("Enter your name", text: $username)
                    TextField("College name", text: $collegeName)
                }
            }
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}


#Preview {
    ProfileView(isShowingProfileView: .constant(true))
}
