//
//  SubjectCardView.swift
//  College Mate
//
//  Created by Sagar Jangra on 15/01/2025.
//

import SwiftUI
import SwiftData

// MARK: Main View SubjectCardView
struct SubjectCardView: View {
    @Bindable var subject: Subject // Binding to update the model dynamically
    
    var body: some View {
        VStack(spacing: 7) {
            // Main card
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(subject.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            AttendanceStatView(label: "Attended", value: subject.attendance.attendedClasses)
                            AttendanceStatView(label: "Missed", value: subject.attendance.totalClasses - subject.attendance.attendedClasses)
                            AttendanceStatView(label: "Total", value: subject.attendance.totalClasses)
                        }
                        AttendanceInfoView(
                            totalClasses: subject.attendance.totalClasses,
                            attendedClasses: subject.attendance.attendedClasses,
                            minimumRequiredPercentage: subject.attendance.minimumPercentageRequirement
                        )
                    }
                    
                    Spacer()
                    
                    CircularProgressView(percentage: subject.attendance.percentage, totalClasses: subject.attendance.totalClasses, attendedClasses: subject.attendance.attendedClasses, minimumRequiredPercentage: subject.attendance.minimumPercentageRequirement)
                    
                        .frame(width: 120, height: 120)
                }
            }
            
            .padding()
            .frame(maxHeight: 210)
            .padding(.vertical, 10)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(16)
            .shadow(radius: 4)
            
            // Controls
            HStack(spacing: 16) {
                AttendanceControl(label: "Attended", onIncrement: incrementAttended, onDecrement: decrementAttended)
                
                Spacer()
                
                AttendanceControl(label: "Missed", onIncrement: incrementMissed, onDecrement: decrementMissed)
            }
        }
    }
    
}

// MARK: Preview
#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Subject.self, configurations: config)
        let subject = Subject(name: "Math", startDateOfSubject: Date(), schedules: [])
        subject.attendance.totalClasses = 5
        subject.attendance.attendedClasses = 3
        return SubjectCardView(subject: subject)
            .modelContainer(container)
            .background(.black.opacity(0.2))
    } catch {
        return Text("Failed to create container: \(error.localizedDescription)")
    }
}

// MARK: SubjectCardView Extension
extension SubjectCardView {
    struct CircularProgressView: View {
        var percentage: Double
        var totalClasses: Int
        var attendedClasses: Int
        var minimumRequiredPercentage: Double
        
        // Calculate skippable classes dynamically
        private var skippableClasses: Int {
            let requiredClasses = Int(ceil((minimumRequiredPercentage / 100) * Double(totalClasses)))
            return max(0, attendedClasses - requiredClasses)
        }
        
        // Determine the gradient color based on percentage and skippable classes
        private var gradientColors: [Color] {
            if skippableClasses > 0 && percentage >= minimumRequiredPercentage {
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
                    Button{
                        provideHapticFeedback()
                        onDecrement()
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.title2)
                            .foregroundStyle(.red)
                            .frame(width: 35, height: 35)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                            )
                        
                    }
                    
                    
                    
                    Button {
                        provideHapticFeedback()
                        onIncrement()
                    } label:  {
                        Image(systemName: "plus.circle")
                            .font(.title2)
                            .foregroundStyle(.green)
                            .frame(width: 35, height: 35)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                            )
                    }
                }
            }
        }
        private func provideHapticFeedback() {
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
        }
    }
    
    struct AttendanceInfoView: View {
        let totalClasses: Int
        let attendedClasses: Int
        let minimumRequiredPercentage: Double
        
        var body: some View {
            VStack(alignment: .leading, spacing: 3) {
                // Calculate future classes needed to meet the requirement
                let futureClassesToAttend: Int = {
                    var futureClasses = 0
                    while Double(attendedClasses + futureClasses) / Double(totalClasses + futureClasses) * 100 < minimumRequiredPercentage {
                        futureClasses += 1
                    }
                    return futureClasses
                }()
                
                // Calculate the required number of classes to meet the minimum attendance percentage
                let requiredClasses = Int(ceil((Double(minimumRequiredPercentage) / 100) * Double(totalClasses)))
                let skippableClasses = max(0, attendedClasses - requiredClasses)
                
                // Calculate the potential attendance percentage if a class is skipped
                let newPercentageIfSkipped = Double(attendedClasses - 1) / Double(totalClasses) * 100
                
                // Display appropriate messages
                if futureClassesToAttend > 0 {
                    Text("Need to attend \(futureClassesToAttend) \(futureClassesToAttend == 1 ? "class" : "classes").")
                        .font(.footnote)
                        .foregroundColor(.yellow)
                        .lineLimit(2)
                } else if newPercentageIfSkipped >= minimumRequiredPercentage {
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


// MARK: SubjectCardView Update
extension SubjectCardView {
    // Increment attended
    private func incrementAttended() {
        for schedule in subject.schedules {
            if isClassToday(schedule: schedule) {
                for classTime in schedule.classTimes {
                    if classTime.label == "Canceled" || classTime.label == "Not Attended" {
                        // Ensure this classTime is for today only and hasn't been updated yet
                        if !isUpdatedToday(classTime: classTime) && isToday(classTime: classTime) {
                            classTime.label = "Attended" // Update label
                            classTime.lastUpdatedDate = Date() // Mark as updated for today
                        }
                    }
                }
            }
        }

        // Update attendance
        subject.attendance.attendedClasses += 1
        subject.attendance.totalClasses += 1
    }

    // Decrement attended
    private func decrementAttended() {
        if subject.attendance.attendedClasses > 0 {
            for schedule in subject.schedules {
                if isClassToday(schedule: schedule) {
                    for classTime in schedule.classTimes {
                        if classTime.label == "Attended" {
                            // Ensure this classTime is for today only and was updated today
                            if isUpdatedToday(classTime: classTime) && isToday(classTime: classTime) {
                                classTime.label = "Not Attended" // Revert to Not Attended
                                classTime.lastUpdatedDate = Date() // Update timestamp
                            }
                        }
                    }
                }
            }

            subject.attendance.attendedClasses -= 1
            subject.attendance.totalClasses -= 1
        }
    }

    // Increment missed
    private func incrementMissed() {
        for schedule in subject.schedules {
            if isClassToday(schedule: schedule) {
                for classTime in schedule.classTimes {
                    if classTime.label == "Canceled" {
                        // Ensure this classTime is for today only and hasn't been updated yet
                        if !isUpdatedToday(classTime: classTime) && isToday(classTime: classTime) {
                            classTime.label = "Not Attended" // Update label
                            classTime.lastUpdatedDate = Date() // Mark as updated for today
                        }
                    }
                }
            }
        }

        // Update missed
        subject.attendance.totalClasses += 1
    }

    // Decrement missed
    private func decrementMissed() {
        if subject.attendance.totalClasses > subject.attendance.attendedClasses {
            subject.attendance.totalClasses -= 1
        }
    }

    // Helper: Check if the class matches today's schedule
    private func isClassToday(schedule: Schedule) -> Bool {
        guard let scheduleDayInt = weekdayStringToInt(schedule.day) else { return false }
        let todayInt = Calendar.current.component(.weekday, from: Date())
        return scheduleDayInt == todayInt
    }

    // Helper: Convert weekday string to integer
    private func weekdayStringToInt(_ day: String) -> Int? {
        let daysOfWeek = [
            "Sunday": 1,
            "Monday": 2,
            "Tuesday": 3,
            "Wednesday": 4,
            "Thursday": 5,
            "Friday": 6,
            "Saturday": 7
        ]
        return daysOfWeek[day]
    }

    // Helper: Check if classTime was updated today
    private func isUpdatedToday(classTime: ClassTime) -> Bool {
        guard let lastUpdated = classTime.lastUpdatedDate else { return false }
        let today = Calendar.current.startOfDay(for: Date())
        let lastUpdatedDay = Calendar.current.startOfDay(for: lastUpdated)
        return today == lastUpdatedDay
    }

    // Helper: Ensure this classTime is specifically for today
    private func isToday(classTime: ClassTime) -> Bool {
        // Add a `date` property to `ClassTime` to hold the specific date of this entry
        guard let classDate = classTime.date else { return false }
        let today = Calendar.current.startOfDay(for: Date())
        let classDay = Calendar.current.startOfDay(for: classDate)
        return today == classDay
    }
}

