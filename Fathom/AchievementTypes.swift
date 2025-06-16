import Foundation

// MARK: - Achievement Definition and Criteria

/// Defines a single achievement in the app.
struct AchievementDefinition: Identifiable {
    let id: String // Unique identifier, e.g., "WORK_STREAK_7_DAY"
    let name: String // User-facing name, e.g., "Focused Apprentice"
    let description: String // User-facing description
    let iconName: String // SF Symbol name for the badge
    let category: AchievementCategory
    let criteria: AchievementCriteria
    let points: Int // Optional: Points awarded for gamification
}

/// Categories for grouping achievements in the UI.
enum AchievementCategory: String, CaseIterable, Identifiable {
    case workSessions = "Work Sessions"
    case breathing = "Breathing Exercises"
    case reflections = "Reflections"
    case streaks = "Streaks"
    // Add more categories as needed
    
    var id: String { self.rawValue }
}

/// Specifies the conditions required to unlock an achievement.
enum AchievementCriteria {
    case streak(type: StreakType, length: Int)
    case totalCount(type: StatType, count: Int)
    // case custom(evaluator: (UserStats) -> Bool) // For more complex, custom logic if needed in future
}

// MARK: - Supporting Enums

/// Types of streaks that can be tracked for achievements.
enum StreakType: String {
    case workSession = "Work Session Streak"
    case breathing = "Breathing Streak"
    case reflection = "Reflection Streak"
}

/// Types of total counts that can be tracked for achievements.
enum StatType: String {
    case totalWorkSessions = "Total Work Sessions"
    case totalBreathingExercises = "Total Breathing Exercises"
    case totalReflections = "Total Reflections Added"
}

// MARK: - Achievement Data Store (Example Definitions)
// This will likely live in AchievementManager or a dedicated data file.

class AchievementsList {
    static let all: [AchievementDefinition] = [
        // Work Session Streaks
        AchievementDefinition(id: "WORK_STREAK_3", name: "Focused Novice", description: "Achieve a 3-day work session streak.", iconName: "flame", category: .streaks, criteria: .streak(type: .workSession, length: 3), points: 10),
        AchievementDefinition(id: "WORK_STREAK_7", name: "Focused Apprentice", description: "Achieve a 7-day work session streak.", iconName: "flame.fill", category: .streaks, criteria: .streak(type: .workSession, length: 7), points: 20),
        
        // Breathing Streaks
        AchievementDefinition(id: "BREATH_STREAK_3", name: "Calm Beginner", description: "Achieve a 3-day breathing streak.", iconName: "wind.circle", category: .streaks, criteria: .streak(type: .breathing, length: 3), points: 10),
        
        // Reflection Streaks
        AchievementDefinition(id: "REFLECT_STREAK_3", name: "Mindful Starter", description: "Achieve a 3-day reflection streak.", iconName: "brain.head.profile.fill", category: .streaks, criteria: .streak(type: .reflection, length: 3), points: 10),
        
        // Total Work Sessions
        AchievementDefinition(id: "TOTAL_SESSIONS_1", name: "Session Starter", description: "Complete your 1st work session.", iconName: "figure.walk.circle", category: .workSessions, criteria: .totalCount(type: .totalWorkSessions, count: 1), points: 5),
        AchievementDefinition(id: "TOTAL_SESSIONS_10", name: "Session Regular", description: "Complete 10 work sessions.", iconName: "figure.walk.circle.fill", category: .workSessions, criteria: .totalCount(type: .totalWorkSessions, count: 10), points: 15),
        
        // Total Breathing Exercises
        AchievementDefinition(id: "TOTAL_BREATHING_1", name: "First Breath", description: "Log your 1st breathing exercise.", iconName: "lungs", category: .breathing, criteria: .totalCount(type: .totalBreathingExercises, count: 1), points: 5),
        
        // Total Reflections
        AchievementDefinition(id: "TOTAL_REFLECTIONS_1", name: "First Thought", description: "Add your 1st reflection.", iconName: "text.bubble", category: .reflections, criteria: .totalCount(type: .totalReflections, count: 1), points: 5),
    ]
}
