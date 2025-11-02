import SwiftUI
import SwiftData
import CoreData // Import CoreData for the notification name

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
            // --- THIS IS THE CORRECTED SYNC LISTENER ---
            .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange)
                .receive(on: DispatchQueue.main) // <-- Ensures the code runs on the main thread
            ) { _ in
                // We don't filter by 'object' so we get all context save notifications,
                // including the one from the background CloudKit sync.
                print("[AttendanceView] Received modelContext did change notification on main thread. Forcing refresh.")
                viewID = UUID() // This is now safe to do
            }
            // --- END CORRECTION ---
        }
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
            
            if !viewModel.scheduledSubjects.isEmpty {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    viewModel.toggleHoliday()
                }) {
                    Text(viewModel.isHoliday ? "Marked as Holiday" : "MarkToday as Holiday")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.isHoliday ? .orange.opacity(0.8) : .gray.opacity(0.2))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .animation(.easeOut(duration: 0.25), value: viewModel.scheduledSubjects.isEmpty)
    }
}


// MARK: - Other Subviews
struct ClassesList: View {
    @ObservedObject var viewModel: AttendanceViewModel
    
    /// This helper function breaks up the complex expression that was confusing the compiler.
    private func scheduledSchedules(for subject: Subject) -> [Schedule] {
        let dayOfWeek = viewModel.selectedDate.formatted(Date.FormatStyle().weekday(.wide))
        return (subject.schedules ?? []).filter { $0.day == dayOfWeek }
    }
    
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
                // Use the helper function here
                ForEach(viewModel.scheduledSubjects) { subject in
                    ForEach(scheduledSchedules(for: subject)) { schedule in
                        ForEach(schedule.classTimes ?? []) { classTime in
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
    
    private var percentage: Double {
        subject.attendance?.percentage ?? 0.0
    }
    
    private var isAboveThreshold: Bool {
        percentage >= (subject.attendance?.minimumPercentageRequirement ?? 75.0)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(subject.name).font(.title2).foregroundStyle(.primary)
                Text("Attendance: \(Int(percentage))%").font(.caption)
                    .foregroundColor(isAboveThreshold ? .green : .red)
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

//#Preview {
//    struct PreviewWrapper: View {
//        var body: some View {
//            do {

//                let config = ModelConfiguration(isStoredInMemoryOnly: true)
//


//                let container = try ModelContainer(for:
//                    Subject.self,
//                    Attendance.self,
//                    Schedule.self,
//                    ClassTime.self,
//                    Note.self,
//                    Folder.self,
//                    FileMetadata.self,
//                    AttendanceRecord.self
//                , configurations: config)

//
//                let todayString = Date().formatted(Date.FormatStyle().weekday(.wide))
//
//                let classTime = ClassTime()
//                let todaySchedule = Schedule(day: todayString)
//                todaySchedule.classTimes = [classTime]
//
//                let subject = Subject(name: "Computer Science")
//                subject.schedules = [todaySchedule]
//                subject.attendance = Attendance(totalClasses: 0, attendedClasses: 0)
//
//                container.mainContext.insert(subject)
//
//                return AttendanceView().modelContainer(container)
//
//            } catch {
//                return Text("Failed to create preview: \(error.localizedDescription)")
//            }
//        }
//    }
//
//    return PreviewWrapper()
//}

