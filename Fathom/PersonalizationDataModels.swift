import Foundation

// MARK: - Personalization Data Models

/// A Sendable struct representing a breathing exercise session for the PersonalizationEngine.
struct BreathingData: Sendable, Identifiable {
    let id: UUID
    let completedAt: Date
    let duration: Double
    let exerciseTypes: String
}

/// A Sendable struct representing a workplace check-in for the PersonalizationEngine.
struct WorkplaceCheckInData: Sendable, Identifiable {
    let id: UUID
    let timestamp: Date
    let stressLevel: Double
    let focusLevel: Double
    let sessionDuration: Int
}

/// A Sendable struct representing a journal entry for the PersonalizationEngine.
struct WorkplaceJournalEntryData: Sendable, Identifiable {
    let id: UUID
    let timestamp: Date
    let title: String
    let content: String
    let stressLevel: Double
    let focusScore: Double
}

/// A Sendable DTO representing a user's goal for the PersonalizationEngine.
struct PersonalizationGoalData: Sendable, Identifiable {
    let id: UUID
    let title: String
    let targetDate: Date
    var isCompleted: Bool
    let progress: Double
}

