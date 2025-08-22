import SwiftUI
import SwiftData

struct AttendanceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query var subjects: [Subject]
    
    // The View creates and owns the ViewModel.
    @StateObject private var viewModel = AttendanceViewModel()
    
    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                        Section {
                            DatePickerHeader(viewModel: viewModel)
                            HolidayButton(viewModel: viewModel)
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
                .background(LinearGradient(colors: [.gray.opacity(0.1), .black.opacity(0.1), .gray.opacity(0.07)], startPoint: .top, endPoint: .bottom))
                .blur(radius: viewModel.isShowingDatePicker ? 8 : 0)
                .disabled(viewModel.isShowingDatePicker)
                .fullScreenCover(isPresented: $viewModel.isShowingProfileView) {
                    ProfileView(isShowingProfileView: $viewModel.isShowingProfileView)
                }
            }
            
            if viewModel.isShowingDatePicker {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Use withAnimation here as well for a smooth dismissal
                        withAnimation(.snappy) {
                            viewModel.isShowingDatePicker = false
                        }
                    }
                    .transition(.opacity)
                
                DateFilterView(
                    start: viewModel.selectedDate,
                    onSubmit: { start in
                        withAnimation(.snappy) {
                            viewModel.selectedDate = start
                            viewModel.isShowingDatePicker = false
                        }
                    },
                    onClose: {
                        withAnimation(.snappy) {
                            viewModel.isShowingDatePicker = false
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // --- FIX IS HERE ---
        // The global .animation() modifier has been removed.
        // The withAnimation block in DatePickerHeader and the new ones
        // added above are now solely responsible for the transition,
        // which prevents the main view's frame from being animated.
        .onAppear {
            viewModel.setup(subjects: subjects, modelContext: modelContext)
        }
        .onChange(of: subjects) {
            viewModel.setup(subjects: subjects, modelContext: modelContext)
        }
    }
}

// MARK: - Subviews

struct DatePickerHeader: View {
    @ObservedObject var viewModel: AttendanceViewModel
    
    private var isNextDayDisabled: Bool { Calendar.current.isDateInToday(viewModel.selectedDate) }
    
    var body: some View {
        HStack {
            Button(action: viewModel.moveToPreviousDay) { Image(systemName: "chevron.left").font(.title2).padding() }
            Spacer()
            Text(viewModel.selectedDate, formatter: Self.dateFormatter).font(.headline)
                .onTapGesture {
                    // This withAnimation block is now the trigger for the transitions.
                    withAnimation(.snappy) {
                        viewModel.isShowingDatePicker.toggle()
                    }
                }
            Spacer()
            Button(action: viewModel.moveToNextDay) {
                Image(systemName: "chevron.right").font(.title2).padding()
                    .foregroundColor(isNextDayDisabled ? .gray : .accentColor)
            }.disabled(isNextDayDisabled)
        }.padding(.horizontal)
    }
    
    static var dateFormatter: DateFormatter {
        let formatter = DateFormatter(); formatter.dateStyle = .full; return formatter
    }
}

struct HolidayButton: View {
    @ObservedObject var viewModel: AttendanceViewModel
    
    var body: some View {
        Button(action: { viewModel.isHoliday.toggle() }) {
            Text(viewModel.isHoliday ? "Marked as Holiday" : "Mark today as Holiday")
                .frame(maxWidth: .infinity).padding().foregroundColor(.white)
                .background(viewModel.isHoliday ? Color.red : Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 10)).padding(.horizontal)
        }
    }
}

struct ClassesList: View {
    @ObservedObject var viewModel: AttendanceViewModel
    
    var body: some View {
        if viewModel.isHoliday {
            Text("No classes today. Enjoy your holiday!").font(.subheadline).foregroundColor(.gray).padding()
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
        case "Not Attended": return .blue
        case "Canceled": return .red
        default: return .gray
        }
    }
}

// MARK: - Preview
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
