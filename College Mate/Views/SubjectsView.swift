//
//  ContentView.swift
//  College Mate
//
//  Created by Sagar Jangra on 03/01/2025.
//

import SwiftUI

struct SubjectsView: View {
    // Array of beautiful colors
    let cardColors: [Color] = [
        Color.pink.opacity(0.2),
        Color.blue.opacity(0.2),
        Color.green.opacity(0.2),
        Color.orange.opacity(0.2),
        Color.purple.opacity(0.2),
        Color.yellow.opacity(0.2)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) { // Add spacing between cards
                    ForEach(0..<5, id: \.self) { index in // Example loop for multiple cards
                        NavigationLink(destination: CardDetailView(subject: "Subject \(index + 1)")) {
                            HStack {
                                // Text Details
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Subject \(index + 1)")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                    
                                    Text("No of Notes: 12")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                
                                // Progress View
                                PieProgressView(total: 10, completed: 7)
                            }
                            .padding() // Padding inside card
                            .frame(maxWidth: .infinity, alignment: .leading) // Full-width card
                            .background(cardColors[index % cardColors.count]) // Random color from array
                            .cornerRadius(12) // Rounded corners
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 5) // Soft shadow
                        }
                        .buttonStyle(.plain) // Removes arrow from NavigationLink
                    }
                }
                .padding() // Padding outside the cards
            }
            .overlay(alignment: .bottomTrailing) {
                NavigationLink {
                    // Add your button action here
                    AddSubjectView()
                } label: {
                    Image(systemName: "plus")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(.white) // Ensures the icon is white
                        .frame(width: 30, height: 30)
                        .padding(12) // Padding around the icon
                        .background(
                            Circle()
                                .fill(Color.blue.opacity(0.8)) // Background color with opacity
                        )
                        .shadow(radius: 10) // Optional shadow for better visibility
                }
                .padding() // Optional: Adds padding around the button
            }

            .navigationTitle("My Subjects")
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
    SubjectsView()
}
