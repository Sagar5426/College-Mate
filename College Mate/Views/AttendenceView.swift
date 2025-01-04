//
//  AttendenceView.swift
//  College Mate
//
//  Created by Sagar Jangra on 03/01/2025.
//

import SwiftUI

struct AttendenceView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                Text("Attendence View")
            }
            .navigationTitle("Attendence View")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ProfileView()) {
                                            Image(systemName: "person.circle.fill") // Profile icon
                                                .resizable()
                                                .scaledToFit()
                                                .frame(height: 40)
                                                .tint(.blue.opacity(0.8))
                                                .padding(.vertical)
                                        }
                }
            }
        }
        
    }
}

#Preview {
    AttendenceView()
}
