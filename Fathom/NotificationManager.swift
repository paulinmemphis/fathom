//
//  NotificationManager.swift
//  Fathom
//
//  Created by Paul Thomas on 6/10/25.
//


import Foundation
import UserNotifications

/// Manages all notification-related functionality, including requesting permissions and scheduling.
@MainActor
class NotificationManager {
    static let shared = NotificationManager()
    
    /// Requests user permission to send notifications.
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print(error.localizedDescription)
            }
        }
    }
    
    /// Schedules a proactive insight notification to be delivered to the user.
    func scheduleProactiveInsight(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        
        // Schedule for the next day at 9 AM
        var dateComponents = DateComponents()
        dateComponents.hour = 9
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    /// Schedules a contextual notification based on a calendar event.
    func scheduleContextualDebrief(for eventTitle: String, after eventEndDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Reflect on Your Meeting"
        content.body = "How did the '\(eventTitle)' meeting go? Take a moment to debrief in Fathom."
        content.sound = UNNotificationSound.default
        
        // Schedule for 5 minutes after the event ends
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 300, repeats: false)
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
