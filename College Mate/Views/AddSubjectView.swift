import SwiftUI

// Define a custom struct for class times
struct ClassTime: Hashable {
    var startTime: Date?
    var endTime: Date?
}

struct AddSubjectView: View {
    
    @State private var subjectName = ""
    @State private var selectedDays: Set<String> = []
    @State private var classTimes: [String: [ClassTime]] = [:]
    @State private var classCount: [String: Int] = [:]
    
    let daysOfWeek = [
        "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                SubjectDetailsSection(subjectName: $subjectName)
                
                ClassScheduleSection(
                    daysOfWeek: daysOfWeek,
                    selectedDays: $selectedDays,
                    classTimes: $classTimes,
                    classCount: $classCount
                )
            }
            .navigationTitle("Add Subject")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSubject()
                    }
                }
            }
        }
    }
    
    private func saveSubject() {
        print("Subject Name: \(subjectName)")
        print("Days: \(selectedDays)")
        print("Times: \(classTimes)")
        print("Class Count: \(classCount)")
    }
}

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
    @Binding var classTimes: [String: [ClassTime]]
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
                                classTimes[day] = [ClassTime(startTime: Date(), endTime: nil)]
                                classCount[day] = 1
                            } else {
                                selectedDays.remove(day)
                                classTimes[day] = nil
                                classCount[day] = nil
                            }
                        }
                    ),
                    times: Binding(
                        get: { classTimes[day] ?? [ClassTime(startTime: Date(), endTime: nil)] },
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
    @Binding var times: [ClassTime]
    @Binding var count: Int

    var body: some View {
        VStack(alignment: .leading) {
            Toggle(day, isOn: $isSelected)
            
            if isSelected {
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    Text("How many times you have this class in a day?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .bold()

                    Picker("Number of Classes", selection: Binding(
                        get: { count },
                        set: { newValue in
                            // Resize `times` array safely when `count` changes
                            if newValue > times.count {
                                times.append(contentsOf: Array(repeating: ClassTime(startTime: nil, endTime: nil), count: newValue - times.count))
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
                            Text("\(index + 1) class Timing (OPTIONAL)")
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
                }
            }
        }
    }
}

#Preview {
    AddSubjectView()
}
