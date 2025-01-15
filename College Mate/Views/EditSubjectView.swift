import SwiftUI
import SwiftData


struct EditSubjectView: View {
    @Bindable var subject: Subject
    @Binding var isShowingEditSubjectView: Bool

    let daysOfWeek = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    @State private var selectedDays: Set<String> = []
    @State private var classTimes: [String: [ClassPeriodTime]] = [:]
    @State private var classCount: [String: Int] = [:]

    var body: some View {
        NavigationStack {
            Form {
                SubjectDetailsSection(subjectName: $subject.name)
                FirstSubjectDatePicker(startDateOfSubject: $subject.startDateOfSubject)
                
                ClassScheduleSection(
                    daysOfWeek: daysOfWeek,
                    selectedDays: $selectedDays,
                    classTimes: $classTimes,
                    classCount: $classCount
                )
            }
            .onAppear {
                populateExistingData()
            }
            .onDisappear {
                saveUpdatedData()
            }
            .navigationTitle("Edit Subject")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isShowingEditSubjectView = false
                    }
                }
            }
        }
    }

    private func populateExistingData() {
        for schedule in subject.schedules {
            selectedDays.insert(schedule.day)
            // Convert ClassTime to ClassPeriodTime
            classTimes[schedule.day] = schedule.classTimes.map { classTime in
                ClassPeriodTime(startTime: classTime.startTime, endTime: classTime.endTime)
            }
            classCount[schedule.day] = schedule.classTimes.count
        }
    }

    private func saveUpdatedData() {
        subject.schedules = selectedDays.map { day in
            Schedule(
                day: day,
                classTimes: classTimes[day]?.map { classPeriodTime in
                    ClassTime(startTime: classPeriodTime.startTime, endTime: classPeriodTime.endTime)
                } ?? []
            )
        }
    }

}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Subject.self, configurations: config)
        let subject = Subject(name: "Math", startDateOfSubject: Date(), schedules: [])
        return EditSubjectView(subject: subject, isShowingEditSubjectView: .constant(true))
            .modelContainer(container)
    } catch {
        return Text("Failed to create container: \(error.localizedDescription)")
    }
}


extension EditSubjectView {
    // MARK: Helper Views
    struct SubjectDetailsSection: View {
        @Binding var subjectName: String
        
        var body: some View {
            Section(header: Text("Subject Details")) {
                TextField("Subject Name", text: $subjectName)
            }
        }
    }

    struct ClassScheduleSection: View {
        let daysOfWeek: [String]
        @Binding var selectedDays: Set<String>
        @Binding var classTimes: [String: [ClassPeriodTime]]
        @Binding var classCount: [String: Int]

        var body: some View {
            Section(header: Text("Select days on which you have classes")) {
                ForEach(daysOfWeek, id: \.self) { day in
                    DayRowView(
                        day: day,
                        isSelected: Binding(
                            get: { selectedDays.contains(day) },
                            set: { isSelected in
                                if isSelected {
                                    selectedDays.insert(day)
                                    let now = Date()
                                    let oneHourLater = Calendar.current.date(byAdding: .hour, value: 1, to: now)!
                                    classTimes[day] = [ClassPeriodTime(startTime: now, endTime: oneHourLater)]
                                    classCount[day] = 1
                                } else {
                                    selectedDays.remove(day)
                                    classTimes[day] = nil
                                    classCount[day] = nil
                                }
                            }
                        ),
                        times: Binding(
                            get: { classTimes[day] ?? [ClassPeriodTime(startTime: Date(), endTime: nil)] },
                            set: { classTimes[day] = $0 }
                        ),
                        count: Binding(
                            get: { classCount[day] ?? 1 },
                            set: { classCount[day] = $0 }
                        )
                    )
                }
            }
        }
    }


    struct DayRowView: View {
        let day: String
        @Binding var isSelected: Bool
        @Binding var times: [ClassPeriodTime]
        @Binding var count: Int

        var body: some View {
            VStack(alignment: .leading) {
                Toggle(day, isOn: $isSelected)
                
                if isSelected {
                    Divider()
                    VStack(alignment: .leading, spacing: 10) {
                        Text("How many times do you have this class in a day?")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .bold()

                        Picker("Number of Classes", selection: Binding(
                            get: { count },
                            set: { newValue in
                                // Resize `times` array safely when `count` changes
                                if newValue > times.count {
                                    times.append(contentsOf: Array(repeating: ClassPeriodTime(startTime: nil, endTime: nil), count: newValue - times.count))
                                } else {
                                    times.removeLast(times.count - newValue)
                                }
                                count = newValue
                            }
                        )) {
                            ForEach(1..<6) { num in
                                Text("\(num)").tag(num)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        ForEach(0..<count, id: \.self) { index in
                            Divider()
                            VStack(alignment: .leading) {
                                Text("\(ordinalNumber(for: index + 1)) Class Timing")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .bold()
                                HStack(alignment: .bottom) {
                                    VStack {
                                        Text("Start Time")
                                        DatePicker("", selection: Binding(
                                            get: { times[index].startTime ?? Date() },
                                            set: { times[index].startTime = $0 }
                                        ), displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                    }
                                    Spacer()
                                    VStack {
                                        Text("End Time")
                                        DatePicker("", selection: Binding(
                                            get: { times[index].endTime ?? Date() },
                                            set: { times[index].endTime = $0 }
                                        ), displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        // Optional Timing Comment
                        Text("Adding class timings is optional.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .italic()
                            .padding(.top, 5)
                    }
                }
            }
        }

        /// Converts a number to its ordinal representation (e.g., 1 -> "1st", 2 -> "2nd").
        private func ordinalNumber(for number: Int) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .ordinal
            return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
        }
    }
    struct FirstSubjectDatePicker: View {
        @Binding var startDateOfSubject: Date
        var body: some View {
            Section("Select the date of your first class") {
                DatePicker("First Class", selection: $startDateOfSubject, displayedComponents: [.date])
                    .datePickerStyle(.graphical)
            }
        }
    }

}
