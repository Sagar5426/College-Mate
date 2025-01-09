import SwiftUI
import SwiftData

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
    
    @Environment(\.modelContext) var modelContext
    @Query var subjects: [Subject]
    @State var isShowingAddSubject: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(Array(subjects.enumerated()), id: \.element.id) { (index, subject) in
                        SubjectCardView(subject: subject, cardColor: cardColors[index % cardColors.count])
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity)
            .overlay(alignment: .bottomTrailing) {
                AddSubjectButton(isShowingAddSubject: $isShowingAddSubject)
            }
            .navigationTitle("My Subjects")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ProfileView()) {
                        ProfileIconView()
                    }
                }
            }
            .fullScreenCover(isPresented: $isShowingAddSubject) {
                AddSubjectView(isShowingAddSubjectView: $isShowingAddSubject)
            }
        }
    }
}

struct SubjectCardView: View {
    let subject: Subject
    let cardColor: Color
    
    var body: some View {
        NavigationLink(destination: CardDetailView(subject: subject)) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(subject.name)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text("Notes: \(subject.numberOfNotes)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                Spacer()
                
                PieProgressView(
                    total: subject.attendance.totalClasses,
                    completed: subject.attendance.attendedClasses
                )
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardColor)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
}

struct AddSubjectButton: View {
    @Binding var isShowingAddSubject: Bool
    
    var body: some View {
        Button {
            isShowingAddSubject = true
        } label: {
            Image(systemName: "plus")
                .resizable()
                .scaledToFit()
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .padding(12)
                .background(Circle().fill(Color.blue.opacity(0.8)))
                .shadow(radius: 10)
        }
        .padding()
    }
}

struct ProfileIconView: View {
    var body: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .scaledToFit()
            .frame(height: 40)
            .tint(.blue.opacity(0.8))
            .padding(.vertical)
    }
}

#Preview {
    SubjectsView()
}

