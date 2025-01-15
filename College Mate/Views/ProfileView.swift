//
//  ProfileView.swift
//  College Mate
//
//  Created by Sagar Jangra on 03/01/2025.
//

import SwiftUI

struct ProfileView: View {
    @Binding var isShowingProfileView: Bool
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Profile View")
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "xmark") {
                        isShowingProfileView = false
                    }
                }
            }
        }
        
    }
        
}

#Preview {
    ProfileView(isShowingProfileView: .constant(true))
}
