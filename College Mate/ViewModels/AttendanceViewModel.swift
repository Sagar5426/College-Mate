import SwiftUI
import SwiftData

@Observable
class AttendanceViewModel {
   var subjects: [Subject]
    
    init(subjects: [Subject]) {
        self.subjects = subjects
    }
    
    // Function to add or update attendance for a specific subject
    func updateAttendance(for subjectName: String, totalClasses: Int, attendedClasses: Int) {
        guard let subjectIndex = subjects.firstIndex(where: { $0.name == subjectName }) else {
            print("Subject not found")
            return
        }
        
        let subject = subjects[subjectIndex]
        subject.attendance.totalClasses = totalClasses
        subject.attendance.attendedClasses = attendedClasses
    }
    
    // Function to declare a day as a holiday for a subject
    func declareHoliday(for subjectName: String, day: String) {
        guard let subjectIndex = subjects.firstIndex(where: { $0.name == subjectName }) else {
            print("Subject not found")
            return
        }
        
        let subject = subjects[subjectIndex]
        guard let scheduleIndex = subject.schedules.firstIndex(where: { $0.day == day }) else {
            print("Schedule for this day not found")
            return
        }
        
        // Empty the classTimes for the holiday
        subject.schedules[scheduleIndex].classTimes = []
    }
    
    // Function to add a new day with class times to a subject's schedule
    func addDay(for subjectName: String, day: String, classTimes: [ClassTime]) {
        guard let subjectIndex = subjects.firstIndex(where: { $0.name == subjectName }) else {
            print("Subject not found")
            return
        }
        
        let subject = subjects[subjectIndex]
        let newSchedule = Schedule(day: day, classTimes: classTimes)
        subject.schedules.append(newSchedule)
    }
    
    // Function to toggle the attendance status
    func toggleAttendance(for subjectName: String, day: String) {
        guard let subjectIndex = subjects.firstIndex(where: { $0.name == subjectName }) else {
            print("Subject not found")
            return
        }
        
        let subject = subjects[subjectIndex]
        if let schedule = subject.schedules.first(where: { $0.day == day }) {
            // Toggle the attendance for the specific day
            if schedule.classTimes.isEmpty {
                // If no class times exist for that day, consider the class as attended
                schedule.classTimes.append(ClassTime(startTime: Date(), endTime: Date()))
            } else {
                // If class times exist, mark as not attended
                schedule.classTimes.removeAll()
            }
        }
    }
}
