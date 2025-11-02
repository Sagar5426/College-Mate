import SwiftUI
import SwiftData
import CoreData // Import CoreData for the notification name

struct SubjectsView: View {
    @Environment(\.modelContext) var modelContext
    @Query var subjects: [Subject]
    @State var isShowingAddSubject: Bool = false
    @State var isShowingProfileView = false // Keep this as @State to modify it
    
    // This is used to force the view to refresh
    @State private var viewID = UUID()

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                LazyVStack(spacing: 20, pinnedViews: [.sectionHeaders]) {
                    // Always show the header
                    Section(header:
                                GeometryReader { proxy in
                        HeaderView(
                            size: proxy.size,
                            title: "My Subjects 📚",
                            isShowingProfileView: $isShowingProfileView
                        )
                    }
                        .frame(height: 60) // Adjust header height as needed
                    ) {
                        if subjects.isEmpty {
                            NoItemsView(isShowingAddSubject: $isShowingAddSubject)
                                .transition(AnyTransition.opacity.animation(.easeIn))
                        } else {
                            // Show list of subjects if available
                            ForEach(subjects, id: \.id) { subject in
                                NavigationLink {
                                    CardDetailView(subject: subject, modelContext: modelContext)
                                } label: {
                                    SubjectCardView(subject: subject)
                                }
                            }
                            Spacer(minLength: 45)
                        }
                    }
                }
                .padding()
            }
            // Add the view ID here
            .id(viewID)
            .background(LinearGradient.appBackground)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .bottomTrailing) {
                AddSubjectButton(isShowingAddSubject: $isShowingAddSubject)
            }
            .fullScreenCover(isPresented: $isShowingAddSubject) {
                AddSubjectView(isShowingAddSubjectView: $isShowingAddSubject)
            }
            .fullScreenCover(isPresented: $isShowingProfileView) {
                ProfileView(isShowingProfileView: $isShowingProfileView)
            }
            // --- THIS IS THE CORRECTED SYNC LISTENER ---
            .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange)) { notification in
                // Check if the notification is from a background thread
                if !Thread.isMainThread {
                    // This is a remote sync.
                    // Dispatch the UI update to the main thread.
                    DispatchQueue.main.async {
                        print("[SubjectsView] Received REMOTE modelContext did change. Forcing refresh.")
                        viewID = UUID()
                    }
                }
                // If the notification was on the main thread, it was a local change
                // (like tapping a button). We do nothing, to prevent lag.
            }
            // --- END CORRECTION ---
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
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 60, height: 60)
                .background(
                    // This creates the frosted glass effect
                    .ultraThinMaterial, in: Circle()
                )
                .overlay(
                    // This adds a subtle "glass" border
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.4), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 5)
        }
        .padding() // Reverted to original padding
        .sensoryFeedback(.impact(weight: .medium), trigger: isShowingAddSubject)
    }
}

// Preview
#Preview {
    SubjectsView()
}

