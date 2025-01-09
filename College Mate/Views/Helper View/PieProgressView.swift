import SwiftUI

struct PieProgressView: View {
    var total: Int
    var completed: Int
    
    var body: some View {
        let progress: Double = total > 0 ? Double(completed) / Double(total) : 0
        
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let lineWidth = size * 0.15 // Adjust line width relative to size
            
            ZStack {
                if completed == 0 {
                    // Subtle and aesthetic design for zero progress
                    Circle()
                        .stroke(
                            LinearGradient(colors: [Color.blue.opacity(0.5), Color.purple.opacity(0.4)], startPoint: .trailing, endPoint: .bottom)
                        , lineWidth: lineWidth)
                    
                    
                    VStack(spacing: size * 0.02) {
                        Image(systemName: "calendar.badge.plus")
                            .resizable()
                            .scaledToFit()
                            .frame(width: size * 0.35, height: size * 0.35) // Icon fits perfectly inside
                            .foregroundStyle(
                                AngularGradient(gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)]), center: .bottom)
                            )
                            
                        
                        Text("Start Tracking")
                            .font(.system(size: size * 0.12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, size * 0.1)
                    }
                } else {
                    // Standard progress view design
                    Circle()
                        .trim(from: 0, to: 1)
                        .stroke(Color.gray.opacity(0.3), lineWidth: lineWidth)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                center: .center,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(270)
                            ),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: size * 0.02) {
                        Text("\(completed)/\(total)")
                            .font(.system(size: size * 0.20, weight: .bold))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Text("Attendance")
                            .font(.system(size: size * 0.1))
                            .foregroundColor(.secondary)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                    }
                }
            }
            .frame(width: size, height: size)
        }
        .frame(width: 100, height: 100)
        .padding()
    }
}

#Preview {
    VStack(spacing: 20) {
        PieProgressView(total: 10, completed: 7) // Example with progress
        PieProgressView(total: 10, completed: 0) // Example with zero progress
    }
}
