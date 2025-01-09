import SwiftUI
import SwiftData

struct AttendanceView: View {
    @Environment(\.modelContext) var modelContext
    @Query var subjects: [Subject]
    @State private var selectedDate = Date() // Tracks the selected date
    @State private var isHoliday = false // Tracks holiday state
    @State private var showDatePicker = false // Controls the visibility of the date picker

    var body: some View {
        NavigationStack {
            VStack {
                // Date Picker and Navigation Arrows
                HStack {
                    Button(action: moveToPreviousDay) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .padding()
                    }

                    Spacer()

                    Text(selectedDate, formatter: dateFormatter)
                        .font(.headline)
                        .onTapGesture {
                            withAnimation {
                                showDatePicker.toggle() // Toggle date picker visibility
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

                // Inline Date Picker
                if showDatePicker {
                    DatePicker(
                        "Select Date",
                        selection: $selectedDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical) // Use a graphical style
                    .padding()
                }

                // Mark as Holiday Button
                Button(action: markAsHoliday) {
                    Text(isHoliday ? "Marked as Holiday" : "Mark Today as Holiday")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.white)
                        .background(isHoliday ? Color.red : Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal)
                }

                Divider().padding(.vertical)

                // Classes List
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
            .navigationTitle("Attendance")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ProfileView()) {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 40)
                            .tint(.blue.opacity(0.8))
                            .padding(.vertical)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func moveToPreviousDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        isHoliday = false // Reset holiday state for the new day
    }

    private func moveToNextDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        isHoliday = false // Reset holiday state for the new day
    }

    private func markAsHoliday() {
        isHoliday.toggle()
    }

    private func formattedDay(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }
}

struct ClassAttendanceRow: View {
    let subject: Subject
    @State private var isAttended = false // Track attendance for the class

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
        // Update attendance in the model context if needed
    }
}

#Preview {
    AttendanceView()
        .modelContainer(for: Subject.self, inMemory: true)
}
