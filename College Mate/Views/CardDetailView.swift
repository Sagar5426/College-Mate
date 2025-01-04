//
//  DetailView.swift
//  College Mate
//
//  Created by Sagar Jangra on 03/01/2025.
//


import SwiftUI

struct CardDetailView: View {
    var subject: String
    
    var body: some View {
        Text("\(subject) Details")
            .font(.title)
            .navigationTitle(subject)
    }
}


