import SwiftUI

struct PieProgressView: View {
    var total: Int
    var completed: Int
    
    var body: some View {
        let progress: Double = Double(completed) / Double(total)
        
        ZStack {
            // Background Circle
            Circle()
                .trim(from: 0, to: 1) // Full circle as background
                .stroke(Color.gray.opacity(0.3), lineWidth: 15) // Gray outline
            
            // Progress Circle
            Circle()
                .trim(from: 0, to: CGFloat(progress)) // Trim based on progress
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [.blue, .purple]),
                        center: .center,
                        startAngle: .degrees(-90), // Start at top
                        endAngle: .degrees(270)   // Complete the circle
                    ),
                    style: StrokeStyle(lineWidth: 15, lineCap: .round)
                )
                .rotationEffect(.degrees(-90)) // Ensure starting point aligns

            // Display percentage in the center
            VStack {
                Text("\(completed)/\(total)") // Display completed/total
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Attendance")
                    .font(.caption)
            }
        }
        .frame(width: 100, height: 100) // Adjust size
        .padding()
    }
}

#Preview {
    PieProgressView(total: 10, completed: 7)
}

extension PieProgressView {
    func CalculateProgress(total: Int, completed: Int) -> Double {
        return Double(completed) / Double(total)
    }
    
    var myProgress: Double {
        return Double(completed)/Double(total)
    }
}
