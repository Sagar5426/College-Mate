import SwiftUI
import SwiftData

struct SubjectsView: View {
    // Array of beautiful colors
    let cardColors: [LinearGradient] = [
        LinearGradient(
            gradient: Gradient(colors: [Color.pink.opacity(0.3), Color.red.opacity(0.3)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        LinearGradient(
            gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.cyan.opacity(0.3)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        LinearGradient(
            gradient: Gradient(colors: [Color.green.opacity(0.3), Color.mint.opacity(0.3)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        LinearGradient(
            gradient: Gradient(colors: [Color.orange.opacity(0.3), Color.yellow.opacity(0.3)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        LinearGradient(
            gradient: Gradient(colors: [Color.purple.opacity(0.3), Color.indigo.opacity(0.3)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        LinearGradient(
            gradient: Gradient(colors: [Color.yellow.opacity(0.3), Color.white.opacity(0.3)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    ]
    
    @Environment(\.modelContext) var modelContext
    @Query var subjects: [Subject]
    @State var isShowingAddSubject: Bool = false
    @State var isShowingProfileView = false // Keep this as @State to modify it
    
    var body: some View {
        GeometryReader {
            // Captures the size of the view for animation or layout adjustments.
            let size = $0.size
            
            NavigationStack {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                        Section {
                            ForEach(Array(subjects.enumerated()), id: \.element.id) { (index, subject) in
                                SubjectCardView(subject: subject, cardColor: cardColors[index % cardColors.count])
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
}

struct SubjectCardView: View {
    let subject: Subject
    let cardColor: LinearGradient // Updated to LinearGradient
    
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
            .background(cardColor) // LinearGradient used here
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
