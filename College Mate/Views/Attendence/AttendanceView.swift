import SwiftUI
import SwiftData

struct AttendanceView: View {
    @Environment(\.modelContext) var modelContext
    @Query var subjects: [Subject]
    @State private var selectedDate = Date()
    @State private var isHoliday = false
    @State private var isShowingDatePicker = false
    @State private var isShowingProfileView = false
    let viewModel: AttendanceViewModel
    
    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                    Section {
                        DatePickerHeader(
                            selectedDate: $selectedDate,
                            showDatePicker: $isShowingDatePicker,
                            moveToPreviousDay: moveToPreviousDay,
                            moveToNextDay: moveToNextDay
                        )
                        HolidayButton(isHoliday: $isHoliday)
                        Divider().padding(.vertical)
                        ClassesList(subjects: subjects, selectedDate: selectedDate, isHoliday: isHoliday, viewModel: viewModel)
                    } header: {
                        GeometryReader { proxy in
                            HeaderView(size: proxy.size, title: "Attendance 🙋", isShowingProfileView: $isShowingProfileView)
                        }
                        .frame(height: 50)
                    }
                }
                .padding()
            }
            .background(.black.opacity(0.2))
            .blur(radius: isShowingDatePicker ? 8 : 0)
            .disabled(isShowingDatePicker)
        }
        .fullScreenCover(isPresented: $isShowingProfileView) {
            ProfileView(isShowingProfileView: $isShowingProfileView)
        }
        .overlay {
            if isShowingDatePicker {
                DateFilterView(
                    start: selectedDate,
                    onSubmit: { start in
                        selectedDate = start
                        isShowingDatePicker = false
                    },
                    onClose: { isShowingDatePicker = false }
                )
                .transition(.move(edge: .leading))
            }
        }
        .animation(.snappy, value: isShowingDatePicker)
    }
    
    private func moveToPreviousDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        isHoliday = false
    }
    
    private func moveToNextDay() {
        let today = Calendar.current.startOfDay(for: Date())
        let nextDay = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate)
        
        if nextDay <= today {
            selectedDate = nextDay
            isHoliday = false
        }
    }
}

// MARK: - Subviews

struct DatePickerHeader: View {
    @Binding var selectedDate: Date
    @Binding var showDatePicker: Bool
    let moveToPreviousDay: () -> Void
    let moveToNextDay: () -> Void
    
    var isNextDayDisabled: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }
    
    var body: some View {
        HStack {
            Button(action: moveToPreviousDay) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .padding()
            }
            
            Spacer()
            
            Text(selectedDate, formatter: AttendanceView.dateFormatter)
                .font(.headline)
                .onTapGesture {
                    withAnimation {
                        showDatePicker.toggle()
                    }
                }
            
            Spacer()
            
            Button(action: moveToNextDay) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .padding()
                    .foregroundColor(isNextDayDisabled ? .gray : .blue) // Gray color if disabled
            }
            .disabled(isNextDayDisabled) // Disable the button when it's the current day
        }
        .padding(.horizontal)
    }
}


struct HolidayButton: View {
    @Binding var isHoliday: Bool
    
    var body: some View {
        Button(action: {
            isHoliday.toggle()
            
        }) {
            Text(isHoliday ? "Marked as Holiday" : "Mark Today as Holiday")
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundColor(.white)
                .background(isHoliday ? Color.red : Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
        }
    }
}

// MARK: - Extensions
extension AttendanceView {
    struct ClassesList: View {
        
        let subjects: [Subject]
        let selectedDate: Date
        let isHoliday: Bool
        let viewModel: AttendanceViewModel
        
        var body: some View {
            if isHoliday {
                Text("No classes today. Enjoy your holiday!")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding()
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(subjects) { subject in
                        ForEach(subject.schedules) { schedule in
                            ForEach(schedule.classTimes) { classTime in
                                if schedule.day == formattedDay(from: selectedDate) {
                                    ClassAttendanceRow(
                                        subject: subject,
                                        viewModel: viewModel,
                                        classTime: Binding (
                                            get: { classTime },
                                            set: { updatedClassTime in
                                                if let index = schedule.classTimes.firstIndex(where: { $0.id == classTime.id }) {
                                                    schedule.classTimes[index] = updatedClassTime
                                                }
                                            }
                                        )
                                    )
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        
        private func formattedDay(from date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        }
    }
    
    struct ClassAttendanceRow: View {
        let subject: Subject
        let viewModel: AttendanceViewModel
        @Binding var classTime: ClassTime
        
        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(subject.name)
                        .font(.title2)
                        .foregroundStyle(.white)
                    
                    Text("Attendance: \(Int(subject.attendance.percentage))%")
                        .font(.caption)
                        .foregroundColor(subject.attendance.percentage >= 75 ? .green : .red)
                }
                
                Spacer()
                
                Menu {
                    Button("Attended") {
                        updateAttendance(to: "Attended")
                    }
                    Button("Not Attended") {
                        updateAttendance(to: "Not Attended")
                    }
                    Button("Canceled") {
                        updateAttendance(to: "Canceled")
                    }
                } label: {
                    Text(classTime.label) // Use classTime.label directly
                        .padding()
                        .foregroundColor(.white)
                        .background(
                            classTime.label == "Attended" ? Color.green :
                            classTime.label == "Not Attended" ? Color.blue : Color.red
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
        }
        
        private func updateAttendance(to newLabel: String) {
            switch newLabel {
            case "Attended":
                if classTime.label == "Canceled" {
                    // Move from "Canceled" to "Attended"
                    subject.attendance.attendedClasses += 1
                    subject.attendance.totalClasses += 1
                } else if classTime.label == "Not Attended" {
                    // Move from "Not Attended" to "Attended"
                    subject.attendance.attendedClasses += 1
                }
            case "Not Attended":
                if classTime.label == "Canceled" {
                    // Move from "Canceled" to "Not Attended"
                    subject.attendance.totalClasses += 1
                } else if classTime.label == "Attended" {
                    // Move from "Attended" to "Not Attended"
                    subject.attendance.attendedClasses -= 1
                }
            case "Canceled":
                if classTime.label == "Attended" {
                    // Move from "Attended" to "Canceled"
                    subject.attendance.attendedClasses -= 1
                    subject.attendance.totalClasses -= 1
                } else if classTime.label == "Not Attended" {
                    // Move from "Not Attended" to "Canceled"
                    subject.attendance.totalClasses -= 1
                }
            default:
                break
            }
            
            // Update the ClassTime model
            classTime.label = newLabel
            classTime.isAttended = (newLabel == "Attended")
        }
    }

    static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }
}





// MARK: - Preview

#Preview {
    AttendanceView(viewModel: AttendanceViewModel(subjects: [
        Subject(name: "DSA",
                startDateOfSubject: Date.now,
                schedules: [Schedule(day: "Monday", classTimes: [ClassTime(startTime: Date.now, endTime: Date.now, isAttended: false, date: Date())])],
                attendance: Attendance(totalClasses: 8, attendedClasses: 5, minimumPercentageRequirement: 75.0), notes: [Note(title: "asas", type: .image, content: Data(),  createdDate: Date())])
    ]))
    .modelContainer(for: Subject.self, inMemory: true)
}
