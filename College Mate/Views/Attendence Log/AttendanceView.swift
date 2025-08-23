import SwiftUI
import SwiftData

struct AttendanceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query var subjects: [Subject]
    
    @StateObject private var viewModel = AttendanceViewModel()
    // This state variable is the key to fixing the layout bug.
    @State private var viewID = UUID()
    
    var body: some View {
        // The NavigationStack is restored as the root view.
        NavigationStack {
            ScrollView(.vertical) {
                LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                    Section {
                        // The two separate views are now replaced by the single control panel.
                        ControlPanelView(viewModel: viewModel)
                        Divider().padding(.vertical)
                        ClassesList(viewModel: viewModel)
                    } header: {
                        GeometryReader { proxy in
                            HeaderView(size: proxy.size, title: "Attendance 🙋", isShowingProfileView: $viewModel.isShowingProfileView)
                        }
                        .frame(height: 50)
                    }
                }
                .padding()
            }
            // The .id() modifier is attached to the ScrollView.
            .id(viewID)
            .background(LinearGradient(colors: [.gray.opacity(0.1), .black.opacity(0.1), .gray.opacity(0.07)], startPoint: .top, endPoint: .bottom))
            .blur(radius: viewModel.isShowingDatePicker ? 8 : 0)
            .disabled(viewModel.isShowingDatePicker)
            .fullScreenCover(isPresented: $viewModel.isShowingProfileView) {
                ProfileView(isShowingProfileView: $viewModel.isShowingProfileView)
            }
            // The original .overlay modifier is restored.
            .overlay {
                if viewModel.isShowingDatePicker {
                    DateFilterView(
                        start: viewModel.selectedDate,
                        onSubmit: { start in
                            viewModel.selectedDate = start
                            viewModel.isShowingDatePicker = false
                            // When the picker closes, we change the ID to force a redraw.
                            viewID = UUID()
                        },
                        onClose: {
                            viewModel.isShowingDatePicker = false
                            // We do the same on close.
                            viewID = UUID()
                        }
                    )
                    .transition(.move(edge: .leading))
                }
            }
        }
        // The original global animation modifier is restored.
        .animation(.snappy, value: viewModel.isShowingDatePicker)
        .onAppear {
            viewModel.setup(subjects: subjects, modelContext: modelContext)
        }
        .onChange(of: subjects) {
            viewModel.setup(subjects: subjects, modelContext: modelContext)
        }
    }
}

// MARK: - Redesigned Control Panel View
struct ControlPanelView: View {
    @ObservedObject var viewModel: AttendanceViewModel
    
    private var isNextDayDisabled: Bool { Calendar.current.isDateInToday(viewModel.selectedDate) }
    
    var body: some View {
        VStack(spacing: 16) {
            // --- Date Controls ---
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
                    // New detailed date format
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
            
            // --- Holiday Button ---
            Button(action: { viewModel.isHoliday.toggle() }) {
                Text(viewModel.isHoliday ? "Marked as Holiday" : "Mark Today as Holiday")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.isHoliday ? .orange.opacity(0.8) : .gray.opacity(0.2))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 15))
    }
}


// MARK: - Other Subviews (ClassesList, ClassAttendanceRow)

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
