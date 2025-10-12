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
    case sunday = "Sunday"
    
    var displayName: String {
        return self.rawValue
    }
}

// MARK: - Identifiable Wrapper
/// A helper struct to ensure each class instance is uniquely identifiable for SwiftUI's ForEach.
/// This can resolve issues where views don't update correctly for items with the same subject.
struct ScheduledClass: Identifiable {
    let id: UUID // Use the ClassTime's UUID for a stable, unique ID
    let subject: Subject
    let classTime: ClassTime
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
                                // The function now returns a list of identifiable `ScheduledClass` objects.
                                let sortedItems = sortedClassTimes(for: day)
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
                                            // The loop now directly uses the identifiable `ScheduledClass` items.
                                            // This is a more robust and idiomatic way to handle dynamic lists in SwiftUI.
                                            ForEach(sortedItems) { item in
                                                ScheduleCard(subject: item.subject, classTime: item.classTime)
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
            .background(LinearGradient.appBackground.ignoresSafeArea())
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
    
    // This function now returns a list of our new `ScheduledClass` structs.
    private func sortedClassTimes(for day: Day) -> [ScheduledClass] {
        var result: [ScheduledClass] = []
        for subject in subjects {
            for schedule in subject.schedules where schedule.day == day.rawValue {
                for classTime in schedule.classTimes {
                    // Each class time becomes a unique, identifiable object.
                    result.append(ScheduledClass(id: classTime.id, subject: subject, classTime: classTime))
                }
            }
        }
        // Sort the final list by the start time of each class.
        result.sort { ($0.classTime.startTime ?? .distantPast) < ($1.classTime.startTime ?? .distantPast) }
        return result
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
    @Bindable var subject: Subject
    // The card still accepts a ClassTime object as before.
    let classTime: ClassTime

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
                
                // It now uses the specific start and end times from the ClassTime object.
                HStack {
                    Image(systemName: "clock")
                    // FIX: Use nil coalescing to provide a default value for startTime and endTime.
                    // This prevents the view from failing to render if a time is unexpectedly nil.
                    Text("\(formattedTime(classTime.startTime ?? Date())) - \(formattedTime(classTime.endTime ?? Date()))")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
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
        
        // Sample Data with two classes on the same day.
        let mathSchedule = Schedule(day: "Monday", classTimes: [
            ClassTime(startTime: Date().addingTimeInterval(-3600*4), endTime: Date().addingTimeInterval(-3600*3)),
            ClassTime(startTime: Date().addingTimeInterval(-3600*2), endTime: Date().addingTimeInterval(-3600*1))
        ])
        let math = Subject(name: "Mathematics", schedules: [mathSchedule], attendance: Attendance(totalClasses: 10, attendedClasses: 8))
        
        container.mainContext.insert(math)
        
        return TimeTableView()
            .modelContainer(container)
            .preferredColorScheme(.dark)
            
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}

