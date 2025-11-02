//
//  will.swift
//  College Mate
//
//  Created by Sagar Jangra on 01/11/2025.
//


import UIKit
import SwiftData

// This class will handle receiving the silent CloudKit notifications.
// SwiftData will automatically process them.
class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Register for all remote notifications (including silent ones)
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        // This notification is a signal from CloudKit that data has changed.
        // We don't need to do anything with it.
        // SwiftData's ModelContainer will see it and update itself automatically.
        // The ModelContainer will then post a .NSManagedObjectContextObjectsDidChange
        // notification, which our views are listening for.
        
        completionHandler(.newData)
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Optional: Log errors if registration fails
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
}

