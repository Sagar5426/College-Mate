import SwiftUI
import SwiftData

struct SubjectsView: View {
    // Array of beautiful colors
    let cardColors: [Color] = [
        Color.pink.opacity(0.3),
        Color.blue.opacity(0.3),
        Color.green.opacity(0.3),
        Color.orange.opacity(0.3),
        Color.purple.opacity(0.3),
        Color.yellow.opacity(0.3)
    ]
    
    @Environment(\.modelContext) var modelContext
    @Query var subjects: [Subject]
    @State var isShowingAddSubject: Bool = false
    
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
                                HeaderView(proxy.size, title: "My Subjects 📚") // Pass title here
                            }
                            .frame(height: 100) // Adjust header height as needed
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



extension SubjectsView {
    // Updated Profile Icon in Header View
    @ViewBuilder
    func HeaderView(_ size: CGSize, title: String) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.title.bold())
            
            Spacer(minLength: 0)
            
            NavigationLink(destination: ProfileView()) {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 45, height: 45)
                    .foregroundStyle(.white)
                    .background(
                        Circle()
                            .fill(Color.blue.gradient)
                            .frame(width: 55, height: 55) // Larger circle for profile
                    )
                    .shadow(radius: 5)
            }
        }
        .padding(.bottom, 10)
        .background {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                
                Divider()
            }
            .visualEffect { content, geometryProxy in
                content
                    .opacity(headerBGOpacity(geometryProxy))
            }
            .padding(.horizontal, -15)
            .padding(.top, -(safeArea.top + 15))
        }
    }
    
    func headerBGOpacity(_ proxy: GeometryProxy) -> CGFloat {
        // Since we ignored the safe area by applying the negative padding, the minY starts with the safe area top value instead of zero.
        
        let minY = proxy.frame(in: .scrollView).minY + safeArea.top
        return minY > 0 ? 0 : (-minY/15)
        //Instead of applying opacity instantly, l converted the minY into a series of progress ranging from 0 to 1, so the opacity effect will be more subtle.
    }
    
    func headerScale(_ size: CGSize, proxy: GeometryProxy) -> CGFloat {
        let minY = proxy.frame(in: .scrollView).minY
        let screenHeight = size.height
        
        let progress = minY / screenHeight
        let scale = (min(max(progress,0),1)) * 0.4
        
        return 1 + scale
    }
}



// Preview
#Preview {
    SubjectsView()
}
