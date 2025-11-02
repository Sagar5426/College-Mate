//
//  HomeView.swift
//  College Mate
//
//  Created by Sagar Jangra on 03/01/2025.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @EnvironmentObject var authService: AuthenticationService
    @Query var subjects: [Subject]
    
    var body: some View {
        
        TabView {
            Tab("Subjects", systemImage: "book.closed") {
                SubjectsView()
            }
            
            Tab("Daily Log", systemImage: "calendar.circle.fill") {
                AttendanceView()
            }
            
            Tab("TimeTable", systemImage: "calendar") {
                TimeTableView()
            }
            
            
            
        }
        .tint(.cyan)
        .environment(\.colorScheme, .dark)
        
        
    }
}


#Preview {
    HomeView()
}

