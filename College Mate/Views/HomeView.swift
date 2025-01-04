//
//  HomeView.swift
//  College Mate
//
//  Created by Sagar Jangra on 03/01/2025.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        TabView {
            Tab("Subjects", systemImage: "book.closed") {
                SubjectsView()
            }
            
            Tab("Attendence", systemImage: "chart.bar.fill") {
                AttendenceView()
            }
            
         }
     }
}

#Preview {
    HomeView()
}
