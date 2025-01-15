import SwiftUI
import SwiftData

struct SubjectsView: View {
    @Environment(\.modelContext) var modelContext
    @Query var subjects: [Subject]
    @State var isShowingAddSubject: Bool = false
    @State var isShowingProfileView = false // Keep this as @State to modify it
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ForEach(subjects, id: \.id) { subject in
                            SubjectCardView(subject: subject)
                        }
                    } header: {
                        GeometryReader { proxy in
                            HeaderView(size: proxy.size, title: "My Subjects 📚", isShowingProfileView: $isShowingProfileView) // Pass binding here
                        }
                        .frame(height: 60) // Adjust header height as needed
                    }
                }
                .padding()
            }
            .background(.gray.opacity(0.15))
            .frame(maxWidth: .infinity)
            .overlay(alignment: .bottomTrailing) {
                AddSubjectButton(isShowingAddSubject: $isShowingAddSubject)
            }
            .fullScreenCover(isPresented: $isShowingAddSubject) {
                AddSubjectView(isShowingAddSubjectView: $isShowingAddSubject)
            }
            // Full screen cover for Profile View
            .fullScreenCover(isPresented: $isShowingProfileView) {
                ProfileView(isShowingProfileView: $isShowingProfileView)
            }
        }
    }
}

struct SubjectCardView: View {
    let subject: Subject
    
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
            .background(Color.white) // Use a solid background color if needed
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

// Preview
#Preview {
    SubjectsView()
}
