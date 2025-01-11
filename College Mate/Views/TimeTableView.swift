import SwiftUI
import SwiftData

struct TimeTableView: View {
    @Environment(\.modelContext) var modelContext
    @Query var subjects: [Subject]
    @State private var expandedDays: Set<String> = Set(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]) // All days expanded by default
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"], id: \.self) { day in
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
                                            if schedule.day == day {
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
                }
                .padding()
            }
            .navigationBarTitle("Time Table 🗓️")
        }
    }
    
    // MARK: - Toggle Day Expansion
    private func toggleDayExpansion(_ day: String) {
        if expandedDays.contains(day) {
            expandedDays.remove(day)
        } else {
            expandedDays.insert(day)
        }
    }
}

extension TimeTableView {
    
    // Updated Profile Icon in Header View
    @ViewBuilder
    func HeaderView(_ size: CGSize, title: String) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.title.bold())
            
            Spacer(minLength: 0)
            
            NavigationLink(destination: ProfileView()) {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 45, height: 45)
                    .foregroundStyle(.white)
                    .background(
                        Circle()
                            .fill(Color.blue.gradient)
                            .frame(width: 55, height: 55) // Larger circle for profile
                    )
                    .shadow(radius: 5)
            }
        }
        .padding(.bottom, 10)
        .background {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                
                Divider()
            }
            .visualEffect { content, geometryProxy in
                content
                    .opacity(headerBGOpacity(geometryProxy))
            }
            .padding(.horizontal, -15)
            .padding(.top, -(safeArea.top + 15))
        }
    }
    
    func headerBGOpacity(_ proxy: GeometryProxy) -> CGFloat {
        // Since we ignored the safe area by applying the negative padding, the minY starts with the safe area top value instead of zero.
        
        let minY = proxy.frame(in: .scrollView).minY + safeArea.top
        return minY > 0 ? 0 : (-minY/15)
        //Instead of applying opacity instantly, l converted the minY into a series of progress ranging from 0 to 1, so the opacity effect will be more subtle.
    }
    
    func headerScale(_ size: CGSize, proxy: GeometryProxy) -> CGFloat {
        let minY = proxy.frame(in: .scrollView).minY
        let screenHeight = size.height
        
        let progress = minY / screenHeight
        let scale = (min(max(progress,0),1)) * 0.4
        
        return 1 + scale
    }
}


// MARK: Helper Views
struct DayHeaderView: View {
    let day: String
    let isExpanded: Bool
    let toggleExpansion: () -> Void
    
    var body: some View {
        Button(action: toggleExpansion) {
            HStack {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.headline)
                    .foregroundColor(.white)
                Text(day)
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

// MARK: Preview
#Preview {
    TimeTableView()
        .modelContainer(for: Subject.self, inMemory: true)
}
