//
//  CalendarManager.swift
//  Fathom
//
//  Created by Paul Thomas on 6/10/25.
//


import Foundation
import EventKit
import Combine

/// Manages fetching events from the user's calendar to provide contextual insights.
private final class SafeEventStore: @unchecked Sendable {
    let store = EKEventStore()
}

@MainActor
final class CalendarManager: ObservableObject {
    private let eventStore = SafeEventStore().store
    @Published var hasCalendarAccess = false

    func requestAccess(completion: @escaping (Bool) -> Void) {
        let eventStore = self.eventStore
        eventStore.requestAccess(to: .event) { granted, error in
            DispatchQueue.main.async {
                self.hasCalendarAccess = granted
                completion(granted)
            }
        }
    }
    
    /// Fetches today's events and schedules debrief notifications for completed meetings.
    func processTodaysEvents() {
        guard hasCalendarAccess else { return }
        let eventStore = self.eventStore // Capture locally on main actor
        
        let calendars = eventStore.calendars(for: .event)
        let today = Date()
        let startOfDay = Calendar.current.startOfDay(for: today)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: calendars)
        let events = eventStore.events(matching: predicate)
        
        for event in events {
            // If the event ended recently and was a meeting, schedule a prompt
            if let endDate = event.endDate, endDate < Date() && (Date().timeIntervalSince(endDate) < 60 * 15) {
                NotificationManager.shared.scheduleContextualDebrief(for: event.title, after: endDate)
            }
        }
    }
}
