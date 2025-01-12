import SwiftUI
import SwiftData

// Define the Day enum
enum Day: String, CaseIterable {
    case monday = "Monday"
    case tuesday = "Tuesday"
    case wednesday = "Wednesday"
    case thursday = "Thursday"
    case friday = "Friday"
    case saturday = "Saturday"
    
    var displayName: String {
        return self.rawValue
    }
}

struct TimeTableView: View {
    @Environment(\.modelContext) var modelContext
    @Query var subjects: [Subject]
    @State private var expandedDays: Set<Day> = Set(Day.allCases) // All days expanded by default
    @State private var isShowingProfileView = false
    
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            NavigationStack {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 20, pinnedViews: [.sectionHeaders]) {
                        Section {
                            ForEach(Day.allCases, id: \.self) { day in
                                VStack(alignment: .leading, spacing: 10) {
                                    // Day Header
                                    DayHeaderView(
                                        day: day,
                                        isExpanded: expandedDays.contains(day),
                                        toggleExpansion: { toggleDayExpansion(day) }
                                    )
                                    
                                    // Classes for the Day
                                    if expandedDays.contains(day) {
                                        VStack(alignment: .leading, spacing: 10) {
                                            ForEach(subjects) { subject in
                                                ForEach(subject.schedules) { schedule in
                                                    if schedule.day == day.rawValue {
                                                        ScheduleCard(subject: subject, schedule: schedule)
                                                            .frame(maxWidth: .infinity) // Allow centering
                                                            .padding(.horizontal, 20) // Smaller width than DayHeaderView
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        } header: {
                            GeometryReader { proxy in
                                HeaderView(size: proxy.size, title: "Time Table 🗓️", isShowingProfileView: $isShowingProfileView)
                            } // Header that stays pinned
                            .frame(height: 60)
                        }
                    }
                    .padding()
                }
                .fullScreenCover(isPresented: $isShowingProfileView) {
                    ProfileView(isShowingProfileView: $isShowingProfileView)
                }
                .background(.gray.opacity(0.15))
            }
        }
    }

    // MARK: - Toggle Day Expansion
    private func toggleDayExpansion(_ day: Day) {
        if expandedDays.contains(day) {
            expandedDays.remove(day)
        } else {
            expandedDays.insert(day)
        }
    }
}



// MARK: - Day Header View
struct DayHeaderView: View {
    let day: Day
    let isExpanded: Bool
    let toggleExpansion: () -> Void

    var body: some View {
        Button(action: toggleExpansion) {
            HStack {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.headline)
                    .foregroundColor(.white)
                Text(day.displayName)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding()
            .background(Color.green.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Schedule Card
struct ScheduleCard: View {
    let subject: Subject
    let schedule: Schedule

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(subject.name)
                    .font(.title3.bold())
                    .foregroundStyle(.black)
                Spacer()
                if let classTime = schedule.classTimes.first {
                    if let startTime = classTime.startTime, let endTime = classTime.endTime {
                        Text("\(formattedTime(startTime)) - \(formattedTime(endTime))")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                }
            }
            HStack {
                Text("Notes: \(subject.numberOfNotes)")
                    .font(.footnote)
                    .foregroundStyle(.gray)
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

// MARK: - Preview
#Preview {
    TimeTableView()
        .modelContainer(for: Subject.self, inMemory: true)
}
