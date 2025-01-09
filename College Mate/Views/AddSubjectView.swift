import SwiftUI
import SwiftData

// Define a custom struct for class times
struct ClassPeriodTime: Hashable {
    var startTime: Date?
    var endTime: Date?
}

struct AddSubjectView: View {
    
    @Environment(\.modelContext) var modelContext
    @Query var subjects: [Subject]
    @Binding var isShowingAddSubjectView: Bool
    
    @State private var subjectName = ""
    @State private var selectedDays: Set<String> = []
    @State private var classTimes: [String: [ClassPeriodTime]] = [:]
    @State private var classCount: [String: Int] = [:]
    
    let daysOfWeek = [
        "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                SubjectDetailsSection(subjectName: $subjectName)
                
                ClassScheduleSection(
                    daysOfWeek: daysOfWeek,
                    selectedDays: $selectedDays,
                    classTimes: $classTimes,
                    classCount: $classCount
                )
            }
            // added navigation title here to put this on outside view
        
        .navigationTitle("Add Subject")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveSubject()
                }
            }
            
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel", systemImage: "xmark") {
                    isShowingAddSubjectView = false
                }
            }
        }
    }
    }
    
    private func saveSubject() {
        guard !subjectName.isEmpty else {
            print("Subject name cannot be empty.")
            return
        }
        
        // Create a new Subject
        let newSubject = Subject(name: subjectName, numberOfNotes: 0)

        // Create schedules for the selected days
        for day in selectedDays {
            let newSchedule = Schedule(day: day)
            
            // Add class times to the schedule
            if let times = classTimes[day] {
                for time in times {
                    let newClassTime = ClassTime(startTime: time.startTime, endTime: time.endTime)
                    newSchedule.classTimes.append(newClassTime)
                }
            }
            
            // Add the schedule to the subject
            newSubject.schedules.append(newSchedule)
        }
        
        // Add the new Subject to the modelContext
        modelContext.insert(newSubject)
        
        // Reset form fields
        subjectName = ""
        selectedDays.removeAll()
        classTimes.removeAll()
        classCount.removeAll()
        
        print("Subject saved successfully.")
        isShowingAddSubjectView = false
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
                                classTimes[day] = [ClassPeriodTime(startTime: Date(), endTime: nil)]
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
                    Text("How many times you have this class in a day?")
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
    NavigationStack {
        AddSubjectView(isShowingAddSubjectView: .constant(true))
    }
}
