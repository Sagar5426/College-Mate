//
//  DetailView.swift
//  College Mate
//
//  Created by Sagar Jangra on 03/01/2025.
//


import SwiftUI
import SwiftData

struct CardDetailView: View {
    
    @Query var subjects: [Subject]
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @State private var isShowingDeleteAlert = false
    
    let subject: Subject
    
    var body: some View {
        Form {
            Section("Subject Details") {
                Text("\(subject.name) Details")
            }
        }
        .font(.title)
        .navigationTitle(subject.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Delete", systemImage: "trash") {
                    isShowingDeleteAlert = true
                }
            }
        }
        .alert("Delete this Subject", isPresented: $isShowingDeleteAlert) {
            Button("Delete", role: .destructive, action: deleteSubject)
            Button("Cancel", role: .cancel, action: { })
        } message: {
            Text("Are you sure?")
        }
    }
}


extension CardDetailView{
    func deleteSubject() {
        modelContext.delete(subject)
        dismiss()
    }

}

#Preview {
    
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Subject.self, configurations: config)
        let example = Subject(name: "Example")
        
        return NavigationStack {
            CardDetailView(subject: example)
                .modelContainer(container)
        }
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}

