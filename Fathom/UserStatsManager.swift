import Foundation
import CoreData
import Combine

@MainActor
class UserStatsManager: ObservableObject {
    static let shared = UserStatsManager()
    private var managedObjectContext: NSManagedObjectContext?

    // Published properties for UI to observe streak values
    // These will be updated from the UserStats entity
    @Published var currentWorkSessionStreak: Int16 = 0
    @Published var longestWorkSessionStreak: Int16 = 0
    @Published var currentBreathingStreak: Int16 = 0
    @Published var longestBreathingStreak: Int16 = 0
    @Published var currentDailyReflectionStreak: Int16 = 0
    @Published var longestDailyReflectionStreak: Int16 = 0

    // Published properties for total counts
    @Published var totalWorkSessionsCompleted: Int32 = 0
    @Published var totalBreathingExercisesLogged: Int32 = 0
    @Published var totalReflectionsAdded: Int32 = 0

    private(set) var userStats: UserStats? {
        didSet {
            updatePublishedProperties()
        }
    }

    private init() { // Private initializer for singleton
        // Load stats when initialized, if context is available
        // However, context is typically injected after app launch
    }

    func configure(context: NSManagedObjectContext) {
        self.managedObjectContext = context
        self.userStats = fetchOrCreateUserStats()
        updatePublishedProperties() // Ensure published properties are up-to-date
    }

    private func updatePublishedProperties() {
        guard let stats = self.userStats else { return }
        // Update UI properties directly since we're already on main actor
        self.currentWorkSessionStreak = stats.currentWorkSessionStreak
        self.longestWorkSessionStreak = stats.longestWorkSessionStreak
        self.currentBreathingStreak = stats.currentBreathingStreak
        self.longestBreathingStreak = stats.longestBreathingStreak
        self.currentDailyReflectionStreak = stats.currentDailyReflectionStreak
        self.longestDailyReflectionStreak = stats.longestDailyReflectionStreak
        self.totalWorkSessionsCompleted = stats.totalWorkSessionsCompleted
        self.totalBreathingExercisesLogged = stats.totalBreathingExercisesLogged
        self.totalReflectionsAdded = stats.totalReflectionsAdded
    }

    private func fetchOrCreateUserStats() -> UserStats? {
        guard let context = managedObjectContext else {
            print("UserStatsManager: Managed object context not available.")
            return nil
        }

        let request: NSFetchRequest<UserStats> = UserStats.fetchRequest()
        do {
            let results = try context.fetch(request)
            if let existingStats = results.first {
                return existingStats
            } else {
                // No existing UserStats, create one
                let newStats = UserStats(context: context)
                // Set default values (though Core Data model might handle defaults)
                newStats.currentWorkSessionStreak = 0
                newStats.longestWorkSessionStreak = 0
                newStats.currentBreathingStreak = 0
                newStats.longestBreathingStreak = 0
                newStats.currentDailyReflectionStreak = 0
                newStats.longestDailyReflectionStreak = 0
                // last...Date attributes will be nil by default
                newStats.totalWorkSessionsCompleted = 0
                newStats.totalBreathingExercisesLogged = 0
                newStats.totalReflectionsAdded = 0
                try context.save()
                print("UserStatsManager: Created new UserStats entity.")
                return newStats
            }
        } catch {
            print("UserStatsManager: Error fetching or creating UserStats: \(error)")
            return nil
        }
    }

    // MARK: - Streak Update Logic

    private func updateStreak(
        eventDate: Date,
        currentStreakKeyPath: WritableKeyPath<UserStats, Int16>,
        longestStreakKeyPath: WritableKeyPath<UserStats, Int16>,
        lastDateKeyPath: WritableKeyPath<UserStats, Date?>
    ) {
        guard let context = managedObjectContext, var stats = self.userStats else { return }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: eventDate)
        
        if let lastEventDate = stats[keyPath: lastDateKeyPath] {
            let lastEventDay = calendar.startOfDay(for: lastEventDate)
            let components = calendar.dateComponents([.day], from: lastEventDay, to: today)
            let daysBetween = components.day ?? 0

            if daysBetween == 1 {
                // Streak continues
                stats[keyPath: currentStreakKeyPath] += 1
            } else if daysBetween > 1 {
                // Streak broken
                stats[keyPath: currentStreakKeyPath] = 1
            } else if daysBetween == 0 {
                // Same day, multiple events. Don't increment streak, just update date.
                // Streak already counted for today.
            } else {
                // Edge case or date in the past, reset streak
                 stats[keyPath: currentStreakKeyPath] = 1
            }
        } else {
            // No previous event, start streak at 1
            stats[keyPath: currentStreakKeyPath] = 1
        }

        // Update last date
        stats[keyPath: lastDateKeyPath] = today

        // Update longest streak
        if stats[keyPath: currentStreakKeyPath] > stats[keyPath: longestStreakKeyPath] {
            stats[keyPath: longestStreakKeyPath] = stats[keyPath: currentStreakKeyPath]
        }

        do {
            try context.save()
            updatePublishedProperties() // Refresh published values
            print("UserStatsManager: Streak updated successfully.")
        } catch {
            print("UserStatsManager: Error saving context after updating streak: \(error)")
        }
    }

    // MARK: - Public Methods to Log Events

    func logWorkSessionCompleted(on date: Date = Date()) {
        print("UserStatsManager: Logging work session completed on \(date)")
        updateStreak(
            eventDate: date,
            currentStreakKeyPath: \.currentWorkSessionStreak,
            longestStreakKeyPath: \.longestWorkSessionStreak,
            lastDateKeyPath: \.lastWorkSessionDate
        )
        // Increment total work sessions
        if let stats = self.userStats {
            stats.totalWorkSessionsCompleted += 1
            // Save context is handled by updateStreak, but if updateStreak fails or doesn't save, ensure save here or make updateStreak more robust.
            // For now, assuming updateStreak saves successfully.
        }
    }

    func logBreathingExercise(on date: Date = Date()) {
        print("UserStatsManager: Logging breathing exercise on \(date)")
        updateStreak(
            eventDate: date,
            currentStreakKeyPath: \.currentBreathingStreak,
            longestStreakKeyPath: \.longestBreathingStreak,
            lastDateKeyPath: \.lastBreathingDate
        )
        // Increment total breathing exercises
        if let stats = self.userStats {
            stats.totalBreathingExercisesLogged += 1
            // Assuming updateStreak saves successfully.
        }
    }

    func logReflectionAdded(on date: Date = Date()) {
        print("UserStatsManager: Logging reflection added on \(date)")
        updateStreak(
            eventDate: date,
            currentStreakKeyPath: \.currentDailyReflectionStreak,
            longestStreakKeyPath: \.longestDailyReflectionStreak,
            lastDateKeyPath: \.lastDailyReflectionDate
        )
        // Increment total reflections added
        if let stats = self.userStats {
            stats.totalReflectionsAdded += 1
            // Assuming updateStreak saves successfully.
        }
    }
    
    // Call this method if you need to reset streaks (e.g., for testing or a user request)
    func resetAllStreaks() {
        guard let context = managedObjectContext, let stats = self.userStats else { return }
        stats.currentWorkSessionStreak = 0
        stats.lastWorkSessionDate = nil
        stats.currentBreathingStreak = 0
        stats.lastBreathingDate = nil
        stats.currentDailyReflectionStreak = 0
        stats.lastDailyReflectionDate = nil
        // Optionally reset longest streaks too, or keep them as historical bests
        // stats.longestWorkSessionStreak = 0 
        // stats.longestBreathingStreak = 0
        // stats.longestDailyReflectionStreak = 0
        do {
            try context.save()
            updatePublishedProperties()
            print("UserStatsManager: All current streaks reset.")
        } catch {
            print("UserStatsManager: Error resetting streaks: \(error)")
        }
    }
}
