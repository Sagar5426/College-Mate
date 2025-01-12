import SwiftUI
import SwiftData

struct AttendanceView: View {
    @Environment(\.modelContext) var modelContext
    @Query var subjects: [Subject]
    @State private var selectedDate = Date()
    @State private var isHoliday = false
    @State private var isshowingDatePicker = false
    @State var isShowingProfileView: Bool = false
    
    var body: some View {
        GeometryReader {
            let size = $0.size
            
            NavigationStack {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                        
                        Section {
                            DatePickerHeader(
                                selectedDate: $selectedDate,
                                showDatePicker: $isshowingDatePicker,
                                moveToPreviousDay: moveToPreviousDay,
                                moveToNextDay: moveToNextDay
                            )
                            HolidayButton(isHoliday: $isHoliday)
                            Divider().padding(.vertical)
                            ClassesList(subjects: subjects, selectedDate: selectedDate, isHoliday: isHoliday)
                        } header: {
                            GeometryReader { proxy in
                                HeaderView(size: proxy.size, title: "Attendance 🙋", isShowingProfileView: $isShowingProfileView)
                                
                            }
                            .frame(height: 50)
                        }
                    }
                    .padding()
//                    .navigationTitle("Attendance 🙋")
//                    .navigationBarTitleDisplayMode(.inline)
//                    .toolbar {
//                        ToolbarItem(placement: .navigationBarTrailing) {
//                            NavigationLink(destination: ProfileView()) {
//                                Image(systemName: "person.circle.fill")
//                                    .resizable()
//                                    .scaledToFit()
//                                    .frame(height: 40)
//                                    .tint(.blue.opacity(0.8))
//                                    .padding(.vertical)
//                            }
//                        }
//                    }
                    
                }
                .background(.gray.opacity(0.15))
                .blur(radius: isshowingDatePicker ? 8 : 0)
                .disabled(isshowingDatePicker)
            }
            .fullScreenCover(isPresented: $isShowingProfileView) {
                ProfileView(isShowingProfileView: $isShowingProfileView)
            }
            .overlay {
                if isshowingDatePicker {
                    DateFilterView(
                        start: selectedDate,
                        onSubmit: { start in
                            selectedDate = start
                            isshowingDatePicker = false
                        },
                        onClose: { isshowingDatePicker = false }
                    )
                    .transition(.move(edge: .leading))
                }
            }
            .animation(.snappy, value: isshowingDatePicker)
        }
    }
}

// MARK: - Subviews
struct DatePickerHeader: View {
    @Binding var selectedDate: Date
    @Binding var showDatePicker: Bool
    let moveToPreviousDay: () -> Void
    let moveToNextDay: () -> Void
    
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
            }
        }
        .padding(.horizontal)
    }
}

struct HolidayButton: View {
    @Binding var isHoliday: Bool
    
    var body: some View {
        Button(action: { isHoliday.toggle() }) {
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

struct ClassesList: View {
    let subjects: [Subject]
    let selectedDate: Date
    let isHoliday: Bool
    
    var body: some View {
        ScrollView {
            if isHoliday {
                Text("No classes today. Enjoy your holiday!")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding()
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(subjects) { subject in
                        ForEach(subject.schedules) { schedule in
                            if schedule.day == formattedDay(from: selectedDate) {
                                ClassAttendanceRow(subject: subject)
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    private func formattedDay(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}

// MARK: - Extensions
extension AttendanceView {
    private func moveToPreviousDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        isHoliday = false
    }
    
    private func moveToNextDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        isHoliday = false
    }
    
    static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }
}

struct ClassAttendanceRow: View {
    let subject: Subject
    @State private var isAttended = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(subject.name)
                    .font(.headline)
                Text("Attendance: \(Int(subject.attendance.attendancePercentage))%")
                    .font(.subheadline)
                    .foregroundColor(subject.attendance.attendancePercentage >= 75 ? .green : .red)
            }
            
            Spacer()
            
            Button(action: toggleAttendance) {
                Text(isAttended ? "Attended" : "Mark as Attended")
                    .padding()
                    .foregroundColor(.white)
                    .background(isAttended ? Color.green : Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
    
    private func toggleAttendance() {
        isAttended.toggle()
    }
}

#Preview {
    AttendanceView()
        .modelContainer(for: Subject.self, inMemory: true)
}



