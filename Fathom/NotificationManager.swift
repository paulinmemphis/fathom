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
    private let focusReminderId = "daily.focus.reminder"
    private let streakSaverId = "streak.saver.today"
    
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

    /// Schedule a daily focus reminder at the provided hour and minute (24h).
    func scheduleDailyFocusReminder(hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Stay Focused"
        content.body = "Your daily focus session is ready to start."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: focusReminderId, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
        print("Scheduled daily focus reminder at \(hour):\(String(format: "%02d", minute))")
    }

    /// Cancel the daily focus reminder if scheduled.
    func cancelDailyFocusReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [focusReminderId])
        print("Canceled daily focus reminder")
    }

    /// Show an immediate local notification (used for achievements, nudges, etc.).
    func scheduleImmediateNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    /// Schedule a one-time "streak saver" nudge for today at the given hour:minute if the user hasn't completed a work session today.
    func scheduleStreakSaverIfNeeded(hour: Int = 19, minute: Int = 0) {
        // If completed today, cancel and return
        if let last = UserStatsManager.shared.userStats?.lastWorkSessionDate {
            let cal = Calendar.current
            if cal.isDateInToday(last) {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [streakSaverId])
                return
            }
        }
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        // Remove any existing pending for today and schedule new one
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [streakSaverId])
        let content = UNMutableNotificationContent()
        content.title = "Don’t break your streak"
        content.body = "Start a 25m focus session to keep your chain alive."
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: streakSaverId, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
        print("Scheduled streak saver at \(hour):\(String(format: "%02d", minute)) if needed")
    }

    /// Cancel today's streak saver notification if scheduled (e.g., after completing a session).
    func cancelStreakSaver() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [streakSaverId])
        print("Canceled streak saver for today")
    }
}
