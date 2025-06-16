//
//  WorkPlaceJournalStore.swift
//  Fathom
//
//  Created by Paul Thomas on 6/10/25.
//

import Foundation
import Combine

/// Manages the collection of journal entries for the Fathom app.
/// This class acts as the single source of truth for all journal data.
@MainActor
class WorkplaceJournalStore: ObservableObject {
    
    /// Shared singleton instance
    static let shared = WorkplaceJournalStore()
    
    /// The array of journal entries displayed in the UI.
    /// The @Published property wrapper automatically announces changes to any SwiftUI views observing this object.
    @Published var entries: [WorkplaceJournalEntry] = []

    init() {
        // For demonstration, we load sample data when the app starts.
        // In a production app, this would fetch data from a database or CloudKit.
        loadSampleData()
    }

    /// Populates the store with sample entries for UI development and previewing.
    private func loadSampleData() {
        self.entries = [
            WorkplaceJournalEntry(
                title: "Q3 Planning Session",
                text: "The planning session for the new 'Phoenix' project was intense. Feeling overwhelmed by the timeline.",
                date: Date().addingTimeInterval(-86400 * 2),
                stressLevel: 0.7,
                focusScore: 0.4
            ),
            WorkplaceJournalEntry(
                title: "Deep Work Day",
                text: "Finally had a chance to focus on the refactoring task. Made significant progress.",
                date: Date().addingTimeInterval(-86400),
                stressLevel: 0.2,
                focusScore: 0.9
            )
        ]
    }
    
    /// Adds a new journal entry to the store
    func addEntry(_ entry: WorkplaceJournalEntry) {
        entries.insert(entry, at: 0) // Insert at the beginning for newest first
    }
}
