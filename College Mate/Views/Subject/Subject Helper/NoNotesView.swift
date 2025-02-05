import SwiftUI

struct NoNotesView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundStyle(.white)
                
            Text("No Notes Added")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.6))
                
            Text("Click on the add button to start adding notes.")
                .font(.body)
                .foregroundStyle(.gray.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding()
    }
}

#Preview {
    ZStack {
                // Background (optional)
                Color.clear // Replace with your desired background color if needed
                
                ScrollView {
                    VStack {
                        Spacer(minLength: UIScreen.main.bounds.height / 4) // Adjust for vertical centering
                        NoNotesView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        Spacer(minLength: UIScreen.main.bounds.height / 4) // Adjust for vertical centering
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .ignoresSafeArea()
}
