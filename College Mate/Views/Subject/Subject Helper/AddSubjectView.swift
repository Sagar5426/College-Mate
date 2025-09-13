import SwiftUI
import SwiftData
import CoreHaptics


struct AddSubjectView: View {
    
    @Environment(\.modelContext) var modelContext
    @Query var subjects: [Subject]
    @Binding var isShowingAddSubjectView: Bool
    
    @State private var subjectName = ""
    @State private var startDateOfSubject: Date = .now
    @State private var MinimumAttendancePercentage: Int = 75
    @State private var selectedDays: Set<String> = []
    @State private var classTimes: [String: [ClassPeriodTime]] = [:]
    @State private var classCount: [String: Int] = [:]
    @State private var isShowingDuplicateAlert = false
    
    let daysOfWeek = [
        "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.gray.opacity(0.1), .black.opacity(0.1), .gray.opacity(0.07)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                Form {
                    SubjectDetailsSection(subjectName: $subjectName)
                    FirstSubjectDatePicker(startDateOfSubject: $startDateOfSubject)
                    MinimumAttendenceStepper(MinimumAttendancePercentage: $MinimumAttendancePercentage)
                    ClassScheduleSection(
                        daysOfWeek: daysOfWeek,
                        selectedDays: $selectedDays,
                        classTimes: $classTimes,
                        classCount: $classCount
                    )
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear) //
                .navigationTitle("Add Subject")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") {
                            saveSubject()
                        }
                        .disabled(!isAllInfoValid)
                        .tint(isAllInfoValid ? .blue : .gray)
                    }
                    
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel", systemImage: "xmark") {
                            isShowingAddSubjectView = false
                        }
                    }
                }
                .alert("Duplicate Subject", isPresented: $isShowingDuplicateAlert) {
                    Button("OK") { }
                } message: {
                    Text("A subject with this name already exists. Please choose a different name.")
                }
            }
        }
    }
    
    private func saveSubject() {
        guard !subjectName.isEmpty else {
            print("Subject name cannot be empty.")
            return
        }
        
        // Check for duplicates (case-insensitive)
        if subjects.contains(where: { $0.name.lowercased() == subjectName.lowercased() }) {
            isShowingDuplicateAlert = true
            return
        }
        
        // Create a new Subject
        let newSubject = Subject(name: subjectName)
        
        // Create schedules for the selected days
        for day in selectedDays {
            let newSchedule = Schedule(day: day)
            
            // Add class times to the schedule
            if let times = classTimes[day] {
                for time in times {
                    let newClassTime = ClassTime(startTime: time.startTime, endTime: time.endTime, date: Date())
                    newSchedule.classTimes.append(newClassTime)
                }
            }
            // Add first date of class
            newSubject.startDateOfSubject = startDateOfSubject
            
            // Add minimum attendence requirement
            newSubject.attendance.minimumPercentageRequirement = Double(MinimumAttendancePercentage)
            
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
        
        FileHelper.createSubjectFolder(for: newSubject)
        
        print("Subject saved successfully.")
        isShowingAddSubjectView = false
    }
    
}

// MARK: Helper Views
struct SubjectDetailsSection: View {
    @Binding var subjectName: String
    let characterLimit = 20 // Stricter character limit

    var body: some View {
        Section(header: Text("Subject Details")) {
            TextField("Subject Name (Max 20 Characters)", text: $subjectName)
                .onChange(of: subjectName) {
                    subjectName = String(subjectName.prefix(characterLimit))
                }
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



#Preview {
    NavigationStack {
        AddSubjectView(isShowingAddSubjectView: .constant(true))
    }
}


extension AddSubjectView {
    var isAllInfoValid: Bool {
        guard !subjectName.isEmpty else { return false }
        guard !selectedDays.isEmpty else { return false }
        
        
        
        return true
    }
}


struct FirstSubjectDatePicker: View {
    @Binding var startDateOfSubject: Date
    var body: some View {
        Section("Select the date of your first class") {
            DatePicker("First Class Date", selection: $startDateOfSubject, displayedComponents: [.date])
                .datePickerStyle(.compact)
        }
    }
}

struct MinimumAttendenceStepper: View {
    @Binding var MinimumAttendancePercentage: Int
    
    var body: some View {
        Section("Minimum Attendance Requirement") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Attendance Requirement")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Spacer()
                    Text("\(MinimumAttendancePercentage)%")
                        .font(.title3)
                        .bold()
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.1))
                        )
                        .frame(minWidth: 70)
                    
                    Spacer()
                    Spacer()
                    
                    Stepper("", value: $MinimumAttendancePercentage, in: 5...100, step: 5)
                        .labelsHidden()
                        .sensoryFeedback(.increase, trigger: MinimumAttendancePercentage)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

