////
////  AttendanceViewModel.swift
////  College Mate
////
////  Created by Sagar Jangra on 22/08/2025.
////
//
//import SwiftUI
//import SwiftData
//
//@MainActor
//class AttendanceViewModel: ObservableObject {
//    
//    // MARK: - Properties
//    
//    // --- UI State ---
//    @Published var selectedDate = Date()
//    @Published var isHoliday = false
//    @Published var isShowingDatePicker = false
//    @Published var isShowingProfileView = false
//    
//    // This will hold the subjects that are scheduled for the selectedDate.
//    @Published var scheduledSubjects: [Subject] = []
//    
//    // The ViewModel holds the master list of all subjects.
//    private var allSubjects: [Subject] = []
//    
//    // MARK: - Initializer
//    init() {}
//    
//    // MARK: - Public Methods
//    
//    // The View will call this to provide the initial data and whenever it changes.
//    func updateSubjects(_ newSubjects: [Subject]) {
//        self.allSubjects = newSubjects
//        filterScheduledSubjects()
//    }
//
//    func moveToPreviousDay() {
//        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
//        isHoliday = false
//        filterScheduledSubjects()
//    }
//    
//    func moveToNextDay() {
//        let today = Calendar.current.startOfDay(for: Date())
//        let nextDay = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate)
//        
//        if nextDay <= today {
//            selectedDate = nextDay
//            isHoliday = false
//            filterScheduledSubjects()
//        }
//    }
//    
//    // --- Attendance Logic (Moved from the View) ---
//    // This is the core business logic, now cleanly separated.
//    func updateAttendance(for subject: Subject, classTime: ClassTime, to newStatus: String) {
//        let oldStatus = classTime.label
//        
//        // Prevent changes if the status is the same.
//        guard oldStatus != newStatus else { return }
//
//        // Logic for Attended
//        if newStatus == "Attended" {
//            if oldStatus == "Not Attended" {
//                subject.attendance.attendedClasses += 1
//            } else if oldStatus == "Canceled" {
//                subject.attendance.attendedClasses += 1
//                subject.attendance.totalClasses += 1
//            }
//        }
//        
//        // Logic for Not Attended
//        else if newStatus == "Not Attended" {
//            if oldStatus == "Attended" {
//                subject.attendance.attendedClasses -= 1
//            } else if oldStatus == "Canceled" {
//                subject.attendance.totalClasses += 1
//            }
//        }
//        
//        // Logic for Canceled
//        else if newStatus == "Canceled" {
//            if oldStatus == "Attended" {
//                subject.attendance.attendedClasses -= 1
//                subject.attendance.totalClasses -= 1
//            } else if oldStatus == "Not Attended" {
//                subject.attendance.totalClasses -= 1
//            }
//        }
//        
//        // Update the model and log the change.
//        // The line for 'isAttended' has been removed to match your new model.
//        classTime.label = newStatus
//        
//        let logAction = newStatus == "Attended" ? "+ Attended" : (newStatus == "Not Attended" ? "- Missed" : "ø Canceled")
//        let log = AttendanceLogEntry(timestamp: Date(), subjectName: subject.name, action: logAction)
//        subject.logs.append(log)
//    }
//    
//    // MARK: - Private Helper Methods
//    
//    private func filterScheduledSubjects() {
//        let dayOfWeek = selectedDate.formatted(Date.FormatStyle().weekday(.wide))
//        
//        scheduledSubjects = allSubjects.filter { subject in
//            // The subject must have started.
//            guard selectedDate >= subject.startDateOfSubject else { return false }
//            
//            // The subject must have a schedule for the selected day.
//            return subject.schedules.contains { $0.day == dayOfWeek }
//        }
//    }
//}
