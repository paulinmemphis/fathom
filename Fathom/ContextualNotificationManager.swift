import Foundation
@preconcurrency import UserNotifications
import CoreData
import Combine

@MainActor
class ContextualNotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = ContextualNotificationManager()
    
    @Published var notificationPermissionGranted = false
    @Published var activeNotifications: [UNNotificationRequest] = []
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    private override init() {
        super.init()
        notificationCenter.delegate = self
        Task { await self.checkNotificationPermission() }
    }
    
    // MARK: - Permission Management
    
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .badge, .sound, .provisional]
            )
            self.notificationPermissionGranted = granted
            return granted
        } catch {
            print("Error requesting notification permission: \(error)")
            return false
        }
    }
    
    private func checkNotificationPermission() async {
        let settings = await notificationCenter.notificationSettings()
        self.notificationPermissionGranted = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }
    
    // MARK: - Contextual Notifications
    
    func scheduleContextualNotification(for trigger: ContextualTrigger, context: WorkplaceCheckInData) {
        guard notificationPermissionGranted else { return }
        
        let content = UNMutableNotificationContent()
        content.title = getContextualTitle(for: trigger, context: context)
        content.body = getContextualBody(for: trigger, context: context)
        content.sound = .default
        content.categoryIdentifier = "CONTEXTUAL_NOTIFICATION"
        
        // Set badge based on priority
        content.badge = NSNumber(value: max(1, Int(trigger.priority)))
        
        // Add custom data
        content.userInfo = [
            "triggerType": trigger.type.rawValue,
            "triggerName": trigger.name,
            "context": try? JSONEncoder().encode(context) ?? Data(),
            "scheduledAt": Date().timeIntervalSince1970
        ]
        
        // Schedule immediately for contextual triggers
        let request = UNNotificationRequest(
            identifier: "contextual_\(trigger.id.uuidString)",
            content: content,
            trigger: nil // nil means immediate delivery
        )
        
        Task {
            do {
                try await notificationCenter.add(request)
                print("Scheduled contextual notification: \(trigger.name)")
                await self.updateActiveNotifications()
            } catch {
                print("Error scheduling contextual notification: \(error)")
            }
        }
    }
    
    func scheduleSmartNotifications() {
        guard notificationPermissionGranted else { return }
        
        // Cancel existing smart notifications
        cancelNotifications(withPrefix: "smart_")
        
        // Schedule daily reflection reminder
        scheduleReflectionReminder()
        
        // Schedule breathing break reminders
        scheduleBreathingReminders()
        
        // Schedule daily insights
        scheduleDailyInsights()
    }
    
    private func scheduleReflectionReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Daily Reflection"
        content.body = "Take a moment to reflect on your workday and capture your thoughts"
        content.sound = .default
        content.categoryIdentifier = "REFLECTION_REMINDER"
        
        // Schedule for 6 PM daily
        var dateComponents = DateComponents()
        dateComponents.hour = 18
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "smart_reflection_daily",
            content: content,
            trigger: trigger
        )
        
        Task {
            do {
                try await notificationCenter.add(request)
            } catch {
                print("Error scheduling reflection reminder: \(error)")
            }
        }
    }
    
    private func scheduleBreathingReminders() {
        let breathingTimes = [
            (hour: 10, minute: 30, title: "Morning Breathing Break", body: "Take a few minutes for mindful breathing to start your day focused"),
            (hour: 14, minute: 0, title: "Afternoon Reset", body: "Time for a breathing break to recharge for the rest of your day"),
            (hour: 16, minute: 30, title: "Pre-Evening Calm", body: "Wind down with some breathing exercises before wrapping up")
        ]
        
        for (index, time) in breathingTimes.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = time.title
            content.body = time.body
            content.sound = .default
            content.categoryIdentifier = "BREATHING_REMINDER"
            
            var dateComponents = DateComponents()
            dateComponents.hour = time.hour
            dateComponents.minute = time.minute
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: "smart_breathing_\(index)",
                content: content,
                trigger: trigger
            )
            
            Task {
                do {
                    try await notificationCenter.add(request)
                } catch {
                    print("Error scheduling breathing reminder: \(error)")
                }
            }
        }
    }
    
    private func scheduleDailyInsights() {
        let content = UNMutableNotificationContent()
        content.title = "Your Daily Insights"
        content.body = "Check out your personalized workplace wellness insights"
        content.sound = .default
        content.categoryIdentifier = "DAILY_INSIGHTS"
        
        // Schedule for 9 AM daily
        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "smart_insights_daily",
            content: content,
            trigger: trigger
        )
        
        Task {
            do {
                try await notificationCenter.add(request)
            } catch {
                print("Error scheduling daily insights: \(error)")
            }
        }
    }
    
    // MARK: - Notification Content Generation
    
    private func getContextualTitle(for trigger: ContextualTrigger, context: WorkplaceCheckInData) -> String {
        switch trigger.type {
        case .highStress:
            return "High Stress Detected"
        case .lowFocus:
            return "Focus Break Needed"
        case .longSession:
            return "Long Work Session"
        case .workplacePattern:
            return "Workplace Pattern Alert"
        case .reflectionPrompt:
            return "Reflection Time"
        }
    }
    
    private func getContextualBody(for trigger: ContextualTrigger, context: WorkplaceCheckInData) -> String {
        switch trigger.type {
        case .highStress:
            return "Consider taking a breathing break or short walk. Your stress levels have been elevated."
        case .lowFocus:
            return "Your focus seems to be declining. Try a 5-minute mindfulness exercise."
        case .longSession:
            return "You've been working for \(context.sessionDuration) minutes. Time for a break!"
        case .workplacePattern:
            return "Based on your patterns at \(context.workplaceName ?? "this location"), consider adjusting your approach."
        case .reflectionPrompt:
            return "How are you feeling about your work today? Take a moment to reflect."
        }
    }
    
    // MARK: - Notification Management
    
    func cancelNotifications(withPrefix prefix: String) {
        Task {
            let pending = await self.notificationCenter.pendingNotificationRequests()
            let identifiersToCancel = pending.compactMap { request in
                request.identifier.hasPrefix(prefix) ? request.identifier : nil
            }
            
            if !identifiersToCancel.isEmpty {
                await self.notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToCancel)
                await self.updateActiveNotifications()
            }
        }
    }
    
    func cancelAllPersonalizedNotifications() {
        Task {
            await self.notificationCenter.removeAllPendingNotificationRequests()
            await self.updateActiveNotifications()
        }
    }
    
    private func updateActiveNotifications() async {
        let pending = await self.notificationCenter.pendingNotificationRequests()
        self.activeNotifications = pending
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        let userInfo = response.notification.request.content.userInfo
        
        // Handle different notification types
        if identifier.hasPrefix("contextual_") {
            // Handle contextual notification response
            if let triggerType = userInfo["triggerType"] as? String {
                print("User responded to contextual notification: \(triggerType)")
                // Could trigger specific actions based on trigger type
            }
        } else if identifier.hasPrefix("smart_") {
            // Handle smart notification response
            print("User responded to smart notification: \(identifier)")
        }
        
        Task {
            await self.updateActiveNotifications()
        }
        
        completionHandler()
    }
}
