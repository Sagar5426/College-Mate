import SwiftUI
import SwiftData

struct AttendanceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query var subjects: [Subject]
    
    @StateObject private var viewModel = AttendanceViewModel()
    @State private var viewID = UUID()
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ControlPanelView(viewModel: viewModel)
                        Divider().padding(.vertical)
                        ClassesList(viewModel: viewModel)
                    } header: {
                        // A GeometryReader is used here to get the size of the parent view.
                        // This can be useful for creating responsive layouts.
                        GeometryReader { proxy in
                            HeaderView(size: proxy.size, title: "Attendance 🙋", isShowingProfileView: $viewModel.isShowingProfileView)
                        }
                        .frame(height: 50)
                    }
                }
                .padding()
            }
            .id(viewID)
            .background(LinearGradient.appBackground.ignoresSafeArea())
            .blur(radius: viewModel.isShowingDatePicker ? 8 : 0)
            .disabled(viewModel.isShowingDatePicker)
            .fullScreenCover(isPresented: $viewModel.isShowingProfileView) {
                ProfileView(isShowingProfileView: $viewModel.isShowingProfileView)
            }
            .overlay {
                if viewModel.isShowingDatePicker {
                    DateFilterView(
                        start: viewModel.selectedDate,
                        onSubmit: { start in
                            viewModel.selectedDate = start
                            viewModel.isShowingDatePicker = false
                            viewID = UUID()
                        },
                        onClose: {
                            viewModel.isShowingDatePicker = false
                            viewID = UUID()
                        }
                    )
                    .transition(.move(edge: .leading))
                }
            }
        }
        // MODIFICATION: Replaced .snappy with a smoother .spring animation
        .animation(.spring(duration: 0.4), value: viewModel.isShowingDatePicker)
        .onAppear {
            viewModel.setup(subjects: subjects, modelContext: modelContext)
        }
        .onChange(of: subjects) {
            viewModel.setup(subjects: subjects, modelContext: modelContext)
        }
    }
}

// MARK: - Control Panel View
struct ControlPanelView: View {
    @ObservedObject var viewModel: AttendanceViewModel
    
    private var isNextDayDisabled: Bool { Calendar.current.isDateInToday(viewModel.selectedDate) }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: viewModel.moveToPreviousDay) {
                    Image(systemName: "chevron.left.circle.fill")
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.snappy) {
                        viewModel.isShowingDatePicker.toggle()
                    }
                }) {
                    Text(viewModel.selectedDate.formatted(.dateTime.day().month(.wide).year().weekday(.wide)))
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: viewModel.moveToNextDay) {
                    Image(systemName: "chevron.right.circle.fill")
                }
                .disabled(isNextDayDisabled)
                .opacity(isNextDayDisabled ? 0.5 : 1.0)
            }
            .font(.title)
            .foregroundStyle(.blue)
            
            // The button is now only visible if there are scheduled subjects for the selected day.
            if !viewModel.scheduledSubjects.isEmpty {
                Button(action: {
                    // This line triggers a light vibration.
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    viewModel.toggleHoliday()
                }) {
                    Text(viewModel.isHoliday ? "Marked as Holiday" : "Mark Today as Holiday")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isHoliday ? .orange.opacity(0.8) : .gray.opacity(0.2))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                // The transition is changed to move from the top edge.
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        // The animation is now faster with a specific duration.
        .animation(.easeOut(duration: 0.25), value: viewModel.scheduledSubjects.isEmpty)
    }
}


// MARK: - Other Subviews
struct ClassesList: View {
    @ObservedObject var viewModel: AttendanceViewModel
    
    var body: some View {
        if viewModel.isHoliday {
            VStack(spacing: 10) {
                Image(systemName: "sun.max.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text("Enjoy your holiday!")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 50)
            
        } else if viewModel.scheduledSubjects.isEmpty {
            Text("No classes scheduled for this day.").font(.subheadline).foregroundColor(.gray).padding()
        } else {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(viewModel.scheduledSubjects) { subject in
                    ForEach(subject.schedules.filter { $0.day == viewModel.selectedDate.formatted(Date.FormatStyle().weekday(.wide)) }) { schedule in
                        ForEach(schedule.classTimes) { classTime in
                            ClassAttendanceRow(
                                subject: subject,
                                record: viewModel.record(for: classTime, in: subject),
                                viewModel: viewModel
                            )
                        }
                    }
                }
            }.padding()
        }
    }
}

struct ClassAttendanceRow: View {
    let subject: Subject
    let record: AttendanceRecord
    @ObservedObject var viewModel: AttendanceViewModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(subject.name).font(.title2).foregroundStyle(.primary)
                Text("Attendance: \(Int(subject.attendance.percentage))%").font(.caption)
                    .foregroundColor(subject.attendance.percentage >= 75 ? .green : .red)
            }
            Spacer()
            Menu {
                Button("Attended") { viewModel.updateAttendance(for: record, in: subject, to: "Attended") }
                Button("Not Attended") { viewModel.updateAttendance(for: record, in: subject, to: "Not Attended") }
                Button("Canceled") { viewModel.updateAttendance(for: record, in: subject, to: "Canceled") }
            } label: {
                Text(record.status)
                    .padding().foregroundColor(.white).background(labelColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding().background(Color.secondary.opacity(0.2)).cornerRadius(10)
    }
    
    private var labelColor: Color {
        switch record.status {
        case "Attended": return .green
        case "Not Attended": return .red
        case "Canceled": return .blue
        default: return .gray
        }
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Subject.self, configurations: config)
        let todayString = Date().formatted(Date.FormatStyle().weekday(.wide))
        let todaySchedule = Schedule(day: todayString, classTimes: [ClassTime()])
        let subject = Subject(name: "Computer Science", schedules: [todaySchedule])
        container.mainContext.insert(subject)
        return AttendanceView().modelContainer(container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}

