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
    @Query var subjects: [Subject]
    @State private var expandedDays: Set<Day> = {
        // Automatically expand the current day of the week on launch.
        let today = Calendar.current.component(.weekday, from: Date())
        let swiftDay: Day? = {
            switch today {
            case 2: return .monday
            case 3: return .tuesday
            case 4: return .wednesday
            case 5: return .thursday
            case 6: return .friday
            case 7: return .saturday
            default: return nil // Sunday or unknown
            }
        }()
        return swiftDay.map { Set([$0]) } ?? []
    }()

    @State private var isShowingProfileView = false
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                    Section {
                        // Show an empty state message if no subjects exist.
                        if subjects.isEmpty {
                            ContentUnavailableView("No Subjects Yet",
                                                   systemImage: "book.closed",
                                                   description: Text("Add a subject to see its schedule here."))
                                .padding(.top, 100)
                        } else {
                            ForEach(Day.allCases, id: \.self) { day in
                                let sortedItems = sortedSchedules(for: day)
                                // Only show days that have classes scheduled.
                                if !sortedItems.isEmpty {
                                    VStack(alignment: .leading, spacing: 12) {
                                        DayHeaderView(
                                            day: day,
                                            classCount: sortedItems.count,
                                            isExpanded: expandedDays.contains(day),
                                            toggleExpansion: { toggleDayExpansion(day) }
                                        )
                                        
                                        if expandedDays.contains(day) {
                                            ForEach(sortedItems, id: \.1.id) { subject, schedule in
                                                ScheduleCard(subject: subject, schedule: schedule)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } header: {
                        HeaderView(size: .zero, title: "Time Table 🗓️", isShowingProfileView: $isShowingProfileView)
                            .frame(height: 60)
                    }
                }
                .padding()
            }
            .fullScreenCover(isPresented: $isShowingProfileView) {
                ProfileView(isShowingProfileView: $isShowingProfileView)
            }
            // FIX 3: The background has been restored to the original gradient.
            .background(LinearGradient(colors: [.gray.opacity(0.1), .black], startPoint: .top, endPoint: .center))
            .navigationTitle("Time Table")
            .navigationBarHidden(true)
        }
    }

    private func toggleDayExpansion(_ day: Day) {
        // Add animation for a smoother expand/collapse transition.
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            if expandedDays.contains(day) {
                expandedDays.remove(day)
            } else {
                expandedDays.insert(day)
            }
        }
    }
    
    private func sortedSchedules(for day: Day) -> [(Subject, Schedule)] {
        var result: [(Subject, Schedule, Date?)] = []
        for subject in subjects {
            for schedule in subject.schedules where schedule.day == day.rawValue {
                result.append((subject, schedule, schedule.classTimes.first?.startTime))
            }
        }
        result.sort { ($0.2 ?? .distantPast) < ($1.2 ?? .distantPast) }
        return result.map { ($0.0, $0.1) }
    }
}

// MARK: - Day Header View (Redesigned)
struct DayHeaderView: View {
    let day: Day
    let classCount: Int
    let isExpanded: Bool
    let toggleExpansion: () -> Void

    var body: some View {
        Button(action: toggleExpansion) {
            HStack {
                Text(day.displayName)
                    .font(.title2).bold()
                    .foregroundColor(.white)
                
                Text("(\(classCount) \(classCount == 1 ? "class" : "classes"))")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Schedule Card (Redesigned)
struct ScheduleCard: View {
    // FIX 1: Using @Bindable ensures that when the subject's attendance
    // changes, this view will automatically update.
    @Bindable var subject: Subject
    let schedule: Schedule

    var body: some View {
        HStack(spacing: 15) {
            // Vertical accent color bar for better visual separation.
            Rectangle()
                .fill(subject.color)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(subject.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                if let classTime = schedule.classTimes.first,
                   let startTime = classTime.startTime,
                   let endTime = classTime.endTime {
                    HStack {
                        Image(systemName: "clock")
                        Text("\(formattedTime(startTime)) - \(formattedTime(endTime))")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // FIX 2: The frame is now larger to provide more padding.
            ZStack {
                Circle()
                    .stroke(subject.attendance.percentage >= 75 ? .green : .red, lineWidth: 2.5)
                
                VStack {
                    Text("\(Int(subject.attendance.percentage))%")
                        .font(.caption).bold()
                        .foregroundStyle(.white)
                    Text("ATT")
                        .font(.system(size: 8))
                        .foregroundStyle(.gray)
                }
            }
            .frame(width: 50, height: 50)
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(10)
        .padding(.leading, 10)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Helper for generating consistent colors
extension Subject {
    /// Generates a consistent, unique color based on the subject's name.
    var color: Color {
        let hash = name.hashValue
        let colorHash = abs(hash)
        let hue = Double(colorHash % 256) / 256.0
        return Color(hue: hue, saturation: 0.7, brightness: 0.8)
    }
}

// MARK: - Preview
#Preview {
    // Create a more robust preview with sample data.
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Subject.self, configurations: config)
        
        // Sample Data
        let mathSchedule = Schedule(day: "Monday", classTimes: [ClassTime(startTime: Date().addingTimeInterval(-3600*2), endTime: Date().addingTimeInterval(-3600*1))])
        let math = Subject(name: "Mathematics", schedules: [mathSchedule], attendance: Attendance(totalClasses: 10, attendedClasses: 8))
        
        let physicsSchedule = Schedule(day: "Monday", classTimes: [ClassTime(startTime: Date().addingTimeInterval(-3600*4), endTime: Date().addingTimeInterval(-3600*3))])
        let physics = Subject(name: "Physics", schedules: [physicsSchedule], attendance: Attendance(totalClasses: 12, attendedClasses: 7))
        
        let historySchedule = Schedule(day: "Wednesday", classTimes: [ClassTime(startTime: Date(), endTime: Date().addingTimeInterval(3600))])
        let history = Subject(name: "History", schedules: [historySchedule])
        
        container.mainContext.insert(math)
        container.mainContext.insert(physics)
        container.mainContext.insert(history)
        
        return TimeTableView()
            .modelContainer(container)
            .preferredColorScheme(.dark)
            
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
