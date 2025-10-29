//
//  NotificationManager.swift
//  College Mate
//
//  Created by Sagar Jangra on 29/10/2025.
//

import Foundation
import UserNotifications
import SwiftData

@MainActor
class NotificationManager {
    
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()

    private init() {}

    /// Call this when your app first launches (e.g., in your App's init() or onAppear()).
    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notification authorization: \(error.localizedDescription)")
            }
            if granted {
                print("Notification permission granted.")
            } else {
                print("Notification permission denied.")
            }
        }
    }

    /// Schedules repeating weekly notifications for all classes in a given subject.
    /// This method first cancels all existing notifications for the subject to prevent duplicates.
    func scheduleNotifications(for subject: Subject) async {
        // First, cancel any old notifications for this subject
        await cancelNotifications(for: subject)
        
        let subjectName = subject.name
        
        for schedule in subject.schedules {
            guard let weekday = dayToWeekday(schedule.day) else { continue }
            
            for classTime in schedule.classTimes {
                guard let startTime = classTime.startTime else { continue }
                
                let components = Calendar.current.dateComponents([.hour, .minute], from: startTime)
                guard let hour = components.hour, let minute = components.minute else { continue }
                
                // 1. Create Content
                let content = UNMutableNotificationContent()
                content.title = "\(subjectName) class is starting now"
                content.body = "Time to head to class!"
                content.sound = .default
                
                // 2. Create Trigger
                var dateComponents = DateComponents()
                dateComponents.weekday = weekday // 1=Sun, 2=Mon, etc.
                dateComponents.hour = hour
                dateComponents.minute = minute
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                
                // 3. Create Request
                let identifier = "\(subject.id.uuidString)_\(schedule.day)_\(classTime.id.uuidString)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                
                // 4. Add Request
                do {
                    try await center.add(request)
                    print("Scheduled notification: \(identifier)")
                } catch {
                    print("Failed to schedule notification \(identifier): \(error.localizedDescription)")
                }
            }
        }
    }

    /// Cancels all pending notifications for a specific subject.
    func cancelNotifications(for subject: Subject) async {
        let subjectPrefix = subject.id.uuidString
        
        let pendingRequests = await center.pendingNotificationRequests()
        
        let identifiersToCancel = pendingRequests
            .map { $0.identifier }
            .filter { $0.hasPrefix(subjectPrefix) }
        
        if !identifiersToCancel.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: identifiersToCancel)
            print("Cancelled notifications for subject: \(subject.name)")
        }
    }
    
    /// Helper to convert day string to weekday integer (1=Sunday, 2=Monday, etc.)
    private func dayToWeekday(_ day: String) -> Int? {
        switch day.lowercased() {
        case "sunday": return 1
        case "monday": return 2
        case "tuesday": return 3
        case "wednesday": return 4
        case "thursday": return 5
        case "friday": return 6
        case "saturday": return 7
        default: return nil
        }
    }
}

