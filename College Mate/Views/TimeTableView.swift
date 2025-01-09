import SwiftUI
import SwiftData

struct TimeTableView: View {
    @Environment(\.modelContext) var modelContext
    @Query var subjects: [Subject]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"], id: \.self) { day in
                    Section(header: DayHeaderView(day: day)) {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(subjects) { subject in
                                ForEach(subject.schedules) { schedule in
                                    if schedule.day == day {
                                        ScheduleCard(subject: subject, schedule: schedule)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct DayHeaderView: View {
    let day: String

    var body: some View {
        Text(day)
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.8))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

struct ScheduleCard: View {
    let subject: Subject
    let schedule: Schedule

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(subject.name)
                    .foregroundStyle(.black)
                    .font(.title3.bold())
                Spacer()
                if let classTime = schedule.classTimes.first {
                    if let startTime = classTime.startTime, let endTime = classTime.endTime {
                        Text("\(formattedTime(startTime)) - \(formattedTime(endTime))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            HStack {
                Text("Notes: \(subject.numberOfNotes)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Attendance: \(Int(subject.attendance.attendancePercentage))%")
                    .font(.footnote)
                    .foregroundColor(subject.attendance.attendancePercentage >= 75 ? .green : .red)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
