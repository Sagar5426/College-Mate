//
//  HomeView.swift
//  College Mate
//
//  Created by Sagar Jangra on 03/01/2025.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Query var subjects: [Subject]
    var body: some View {
        TabView {
            Tab("Subjects", systemImage: "book.closed") {
                SubjectsView()
            }
            
            Tab("Attendence", systemImage: "chart.bar.fill") {
                AttendanceView(viewModel: AttendanceViewModel(subjects: subjects))
            }
            Tab("TimeTable", systemImage: "calendar") {
                TimeTableView()
            }
            
         }
     }
}

#Preview {
    HomeView()
}




