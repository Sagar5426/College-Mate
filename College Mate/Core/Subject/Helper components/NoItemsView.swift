import SwiftUI

struct NoItemsView: View {
    
    @State var animate: Bool = false
    @Binding var isShowingAddSubject: Bool
    let secondaryAccentColor: Color = Color("secondaryAccentColor")
    let primaryAccentColor: Color = Color("primaryAccentColor")
    
    var body: some View {
        VStack(spacing: 10) {
            Text("No Subjects Yet!")
                .font(.title)
                .fontWeight(.semibold)
            
            Text("Start organizing your subjects and never miss important notes or track attendance again. Tap the button below to add your first subject!")
                .padding(.bottom, 20)
                .foregroundStyle(.secondary)
            
            Text("Add Subject 📚")
                .foregroundStyle(.white)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 55)
                .background(animate ? secondaryAccentColor : primaryAccentColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .onTapGesture {
                    isShowingAddSubject.toggle()
                }
                .padding(.horizontal, animate ? 30 : 50)
                .offset(y: animate ? -10 : 0)
                .shadow(
                    color: animate ? secondaryAccentColor.opacity(0.7) : primaryAccentColor.opacity(0.7),
                    radius: animate ? 30 : 10,
                    x: 0,
                    y: animate ? 50 : 30
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .multilineTextAlignment(.center)
        .padding(40)
        .onAppear(perform: addAnimation)
    }
    
    func addAnimation() {
        guard !animate else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(
                Animation
                    .easeInOut(duration: 2)
                    .repeatForever()
            ) {
                animate.toggle()
            }
        }
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            NoItemsView(isShowingAddSubject: .constant(true))
                .navigationTitle("Subjects")
        }
    }
}
