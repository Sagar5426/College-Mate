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
                LazyVStack(spacing: 20, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ForEach(subjects, id: \.id) { subject in
                            NavigationLink {
                                CardDetailView(subject: subject)
                            } label: {
                                SubjectCardView(subject: subject)
                            }

                            
                                
                        }
                        Spacer(minLength: 45)
                    } header: {
                        GeometryReader { proxy in
                            HeaderView(size: proxy.size, title: "My Subjects 📚", isShowingProfileView: $isShowingProfileView) // Pass binding here
                        }
                        .frame(height: 60) // Adjust header height as needed
                    }
                }
                .padding()
            }
            .background(.black.opacity(0.2))
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



