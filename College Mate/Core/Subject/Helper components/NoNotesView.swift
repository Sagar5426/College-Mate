import SwiftUI

struct NoNotesView: View {
    let imageName: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundStyle(.white)
                
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white.opacity(0.6))
                
            Text(message)
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
                        NoNotesView(imageName: "doc.text.magnifyingglass", title: "No Notes Added", message: "Click on the add button to start adding notes.")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        Spacer(minLength: UIScreen.main.bounds.height / 4) // Adjust for vertical centering
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .ignoresSafeArea()
}
