//
//  SubjectCardView.swift
//  College Mate
//

import SwiftUI
import SwiftData
import UIKit

// MARK: Main View
struct SubjectCardView: View {
    @Bindable var subject: Subject
    
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    
    var body: some View {
        if let attendance = subject.attendance {
            VStack(spacing: 7) {
                // Subject Card
                VStack(alignment: .leading, spacing: isPad ? 20 : 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 20) {
                            Text(subject.name)
                                // If the name is longer than 12 characters, use a smaller font.
                                .font(isPad ? (subject.name.count > 12 ? .title2 : .title) : (subject.name.count > 12 ? .headline : .title2))
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .lineLimit(2) // Allow wrapping to a second line if needed

                            // Pass the unwrapped 'attendance' object
                            AttendanceStatsView(attendance: attendance)

                            AttendanceInfoView(attendance: attendance)
                        }

                        Spacer()

                        // Pass the unwrapped 'attendance' object
                        CircularProgressView(attendance: attendance)
                            .frame(width: isPad ? 160 : 120, height: isPad ? 160 : 120)
                    }
                }
                .frame(minHeight: isPad ? 220 : nil)
                .padding(isPad ? 24 : 16)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(16)
                .shadow(radius: 4)

                // Attendance Controls
                HStack(spacing: 16) {
                    AttendanceControl(label: "Attended", onIncrement: incrementAttended, onDecrement: decrementAttended)
                    Spacer()
                    AttendanceControl(label: "Missed", onIncrement: incrementMissed, onDecrement: decrementMissed)
                }
            }
        } else {
            // Show a placeholder or loading view if attendance is nil
            // This shouldn't happen if the Subject's init is set up correctly,
            // but it's good practice to have a fallback.
            Text("Loading \(subject.name)...")
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(16)
        }
    }

    // MARK: Attendance Modification Functions
    private func addLog(_ action: String) {
        let log = AttendanceLogEntry(timestamp: Date(), subjectName: subject.name, action: action)
        subject.logs.append(log)
    }

    private func incrementAttended() {
        guard let attendance = subject.attendance else { return }
        attendance.attendedClasses += 1
        attendance.totalClasses += 1
        addLog("+ Attended")
    }

    private func decrementAttended() {
        guard let attendance = subject.attendance else { return }
        if attendance.attendedClasses > 0 {
            attendance.attendedClasses -= 1
            attendance.totalClasses -= 1
            addLog("− Attended")
        }
    }

    private func incrementMissed() {
        guard let attendance = subject.attendance else { return }
        attendance.totalClasses += 1
        addLog("+ Missed")
    }

    private func decrementMissed() {
        guard let attendance = subject.attendance else { return }
        let missed = attendance.totalClasses - attendance.attendedClasses
        if missed > 0 {
            attendance.totalClasses -= 1
            addLog("− Missed")
        }
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        // 1. Added Attendance.self to the container
        let container = try ModelContainer(for: Subject.self, Attendance.self, configurations: config)
        
        // 2. Create Subject
        let subject = Subject(name: "Operating Systems", startDateOfSubject: Date(), schedules: [])
        
        // 3. Use optional chaining `?.` to set properties
        subject.attendance?.totalClasses = 6
        subject.attendance?.attendedClasses = 4
        
        return SubjectCardView(subject: subject)
            .modelContainer(container)
            .background(.black.opacity(0.2))
    } catch {
        return Text("Failed to create container: \(error.localizedDescription)")
    }
}

// MARK: Supporting Views
struct AttendanceStatView: View {
    let label: String
    let value: Int

    var body: some View {
        HStack {
            Text("\(value)")
                .fontWeight(.heavy)
                .foregroundColor(.gray)
            Text(label)
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundColor(.gray)
        }
    }
}

struct AttendanceControl: View {
    let label: String
    let onIncrement: () -> Void
    let onDecrement: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.white)

            HStack {
                Button {
                    provideHapticFeedback()
                    onDecrement()
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.title2)
                        .foregroundStyle(.red)
                        .frame(width: 35, height: 35)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.2)))
                }

                Button {
                    provideHapticFeedback()
                    onIncrement()
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                        .foregroundStyle(.green)
                        .frame(width: 35, height: 35)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.2)))
                }
            }
        }
    }

    private func provideHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
}

struct AttendanceStatsView: View {
    @Bindable var attendance: Attendance

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            AttendanceStatView(label: "Attended", value: attendance.attendedClasses)
            AttendanceStatView(label: "Missed", value: attendance.totalClasses - attendance.attendedClasses)
            AttendanceStatView(label: "Total", value: attendance.totalClasses)
        }
    }
}

extension SubjectCardView {
    struct CircularProgressView: View {
        @Bindable var attendance: Attendance
        
        // Derived values
        private var percentage: Double { attendance.percentage }
        private var totalClasses: Int { attendance.totalClasses }
        private var attendedClasses: Int { attendance.attendedClasses }
        private var minimumRequiredPercentage: Double { attendance.minimumPercentageRequirement }
        
        // Calculate skippable classes dynamically
        private var skippableClasses: Int {
            let requiredClasses = Int(ceil((minimumRequiredPercentage / 100) * Double(totalClasses)))
            return max(0, attendedClasses - requiredClasses)
        }
        
        // Determine the gradient color based on percentage and skippable classes
        private var gradientColors: [Color] {
            if percentage >= minimumRequiredPercentage {
                return [Color.green.opacity(0.6), Color.green]
            } else if percentage <= 0.5 * minimumRequiredPercentage {
                return [Color.red.opacity(0.6), Color.red]
            } else {
                return [Color.yellow.opacity(0.6), Color.yellow]
            }
        }
        
        var body: some View {
            ZStack {
                // Background circle
                Circle()
                    .stroke(lineWidth: 13)
                    .opacity(0.3)
                    .foregroundColor(.gray)
                
                // Progress circle with gradient
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(percentage / 100, 1.0)))
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: gradientColors),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(Angle(degrees: 270.0))
                    .shadow(color: gradientColors.last!.opacity(0.6), radius: 10, x: 0, y: 0)
                    .animation(.easeInOut, value: percentage)
                
                // Percentage text
                Text(String(format: "%.0f%%", min(percentage, 100.0)))
                    .font(.title2)
                    .bold()
                    .foregroundColor(.white)
            }
        }
    }
    
    
    struct AttendanceInfoView: View {
        @Bindable var attendance: Attendance
        
        var body: some View {
            VStack(alignment: .leading, spacing: 3) {
                let totalClasses = attendance.totalClasses
                let attendedClasses = attendance.attendedClasses
                let minimumRequiredPercentage = attendance.minimumPercentageRequirement
                
                // Calculate future classes needed to meet the requirement
                let futureClassesToAttend: Int = {
                    var futureClasses = 0
                    var tempTotal = totalClasses
                    var tempAttended = attendedClasses
                    // Avoid division by zero
                    if tempTotal <= 0 {
                        // If no classes, assume 0 needed if req is 0, else 1
                        return minimumRequiredPercentage > 0 ? 1 : 0
                    }
                    
                    while (Double(tempAttended) / Double(tempTotal)) * 100 < minimumRequiredPercentage {
                        futureClasses += 1
                        tempTotal += 1
                        tempAttended += 1
                        // Add a safety break to prevent infinite loops if logic is flawed
                        if futureClasses > 1000 { return 999 }
                    }
                    return futureClasses
                }()
                
                // Calculate the required number of classes to meet the minimum attendance percentage
                let requiredClasses = Int(ceil((Double(minimumRequiredPercentage) / 100) * Double(totalClasses)))
                let skippableClasses = max(0, attendedClasses - requiredClasses)
                
                // Display appropriate messages
                if totalClasses == 0 && minimumRequiredPercentage > 0 {
                    Text("Start by attending a class.")
                        .font(.footnote)
                        .foregroundColor(.blue)
                        .lineLimit(2)
                } else if futureClassesToAttend > 0 {
                    Text("Need to attend \(futureClassesToAttend) \(futureClassesToAttend == 1 ? "class" : "classes").")
                        .font(.footnote)
                        .foregroundColor(.yellow)
                        .lineLimit(2)
                } else if skippableClasses > 0 {
                    Text("Can skip \(skippableClasses) \(skippableClasses == 1 ? "class" : "classes").")
                        .font(.footnote)
                        .foregroundColor(.green)
                        .lineLimit(2)
                } else {
                    Text("Cannot skip classes.")
                        .font(.footnote)
                        .foregroundColor(.blue)
                        .lineLimit(2)
                }
                
                Text("Requirement: \(Int(round(minimumRequiredPercentage)))%")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
    }
    
    
}
