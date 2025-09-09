import Foundation
import CoreData
import Combine

@MainActor
class AchievementManager: ObservableObject {
    static let shared = AchievementManager()
    private var managedObjectContext: NSManagedObjectContext?
    private lazy var userStatsManager = UserStatsManager.shared // To access streak and total counts
    private var cancellables = Set<AnyCancellable>()

    // Published properties for UI to observe achievements
    @Published var achievementStatuses: [AchievementDisplayData] = []

    private init() {
        // Private initializer for singleton
    }

    func configure(context: NSManagedObjectContext) {
        self.managedObjectContext = context
        print("AchievementManager configured with context.")
        loadAndProcessAchievements()
        setupUserStatsSubscription()
    }

    // Placeholder for combined data for UI
    struct AchievementDisplayData: Identifiable {
        let definition: AchievementDefinition
        var isUnlocked: Bool
        var unlockedDate: Date?
        var currentProgress: Int32?
        var targetProgress: Int32?
        
        var id: String { definition.id }
    }

    private func loadAndProcessAchievements() {
        guard let context = managedObjectContext else { return }
        let definitions = AchievementsList.all

        // Fetch existing statuses
        let fetchRequest: NSFetchRequest<AchievementStatus> = AchievementStatus.fetchRequest()
        guard let existingStatusesCoreData = try? context.fetch(fetchRequest) else {
            print("Error fetching AchievementStatus")
            return
        }
        let existingStatusesDict = Dictionary(uniqueKeysWithValues: existingStatusesCoreData.map { ($0.achievementID, $0) })

        var displayData: [AchievementDisplayData] = []

        for def in definitions {
            if let statusEntity = existingStatusesDict[def.id] {
                displayData.append(AchievementDisplayData(
                    definition: def,
                    isUnlocked: statusEntity.isUnlocked,
                    unlockedDate: statusEntity.dateUnlocked,
                    currentProgress: statusEntity.progress,
                    targetProgress: Int32(getTargetFromCriteria(def.criteria))
                ))
            } else {
                // Create new AchievementStatus in Core Data
                let newStatus = AchievementStatus(context: context)
                newStatus.achievementID = def.id
                newStatus.isUnlocked = false
                newStatus.progress = 0
                // ... set other defaults ...
                // try? context.save() // Consider batch saving
                
                displayData.append(AchievementDisplayData(
                    definition: def,
                    isUnlocked: false
                    // ... other fields nil or default ...
                ))
            }
        }
        // TODO: Save context if new entities were created
        self.achievementStatuses = displayData.sorted { $0.definition.category.rawValue < $1.definition.category.rawValue || ($0.definition.category == $1.definition.category && $0.definition.name < $1.definition.name) }
        
        // Save context if any new entities were created
        if context.hasChanges {
            do {
                try context.save()
                print("AchievementManager: Saved new AchievementStatus entities.")
            } catch {
                print("AchievementManager: Error saving context after creating new AchievementStatus entities: \(error)")
            }
        }
    }

    private func setupUserStatsSubscription() {
        let publishers = [
            userStatsManager.$currentWorkSessionStreak.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            userStatsManager.$currentBreathingStreak.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            userStatsManager.$currentDailyReflectionStreak.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            userStatsManager.$totalWorkSessionsCompleted.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            userStatsManager.$totalBreathingExercisesLogged.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            userStatsManager.$totalReflectionsAdded.dropFirst().map { _ in () }.eraseToAnyPublisher()
        ]

        Publishers.MergeMany(publishers)
            .debounce(for: .seconds(1.0), scheduler: RunLoop.main)
            .sink { [weak self] in
                print("AchievementManager: Detected change in UserStatsManager, checking achievements.")
                self?.checkAchievementsForUnlocks()
            }
            .store(in: &cancellables)
    }

    func checkAchievementsForUnlocks() {
        guard let context = managedObjectContext, let userStatsEntity = userStatsManager.userStats else { 
            print("AchievementManager: Context or UserStats entity not available for checking unlocks.")
            return 
        }
        
        var hasChanges = false
        for index in achievementStatuses.indices {
            var mutableAchievement = achievementStatuses[index] // This is a value copy

            if !mutableAchievement.isUnlocked {
                var shouldUnlock = false
                let definition = mutableAchievement.definition

                switch definition.criteria {
                case .streak(let type, let length):
                    switch type {
                    case .workSession:
                        if userStatsEntity.currentWorkSessionStreak >= Int16(length) { shouldUnlock = true }
                    case .breathing:
                        if userStatsEntity.currentBreathingStreak >= Int16(length) { shouldUnlock = true }
                    case .reflection:
                        if userStatsEntity.currentDailyReflectionStreak >= Int16(length) { shouldUnlock = true }
                    }
                case .totalCount(let type, let count):
                    switch type {
                    case .totalWorkSessions:
                        if userStatsEntity.totalWorkSessionsCompleted >= Int32(count) { shouldUnlock = true }
                    case .totalBreathingExercises:
                        if userStatsEntity.totalBreathingExercisesLogged >= Int32(count) { shouldUnlock = true }
                    case .totalReflections:
                        if userStatsEntity.totalReflectionsAdded >= Int32(count) { shouldUnlock = true }
                    }
                }

                if shouldUnlock {
                    mutableAchievement.isUnlocked = true
                    mutableAchievement.unlockedDate = Date()
                    
                    // Update the published array by replacing the element at the specific index
                    self.achievementStatuses[index] = mutableAchievement

                    // Update Core Data entity
                    let fetchRequest: NSFetchRequest<AchievementStatus> = AchievementStatus.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "achievementID == %@", definition.id)
                    do {
                        let results = try context.fetch(fetchRequest)
                        if let statusEntityToUpdate = results.first {
                            statusEntityToUpdate.isUnlocked = true
                            statusEntityToUpdate.dateUnlocked = Date()
                            hasChanges = true
                            print("Achievement Unlocked: \(definition.name)")
                            // Habit-forming: notify and track
                            NotificationManager.shared.scheduleImmediateNotification(
                                title: "Achievement Unlocked",
                                body: "\(definition.name): \(definition.description)"
                            )
                            AnalyticsService.shared.logEvent("achievement_unlocked", parameters: [
                                "id": definition.id,
                                "name": definition.name,
                                "category": definition.category.rawValue,
                                "points": definition.points
                            ])
                            // TODO: Post notification or alert for the user
                        } else {
                            print("Error: Could not find AchievementStatus entity for ID \(definition.id) to update.")
                        }
                    } catch {
                        print("Error fetching AchievementStatus for update: \(error)")
                    }
                }
            }
        }

        // After iterating through all, if any changes were made to achievementStatuses, re-assign to trigger UI update if necessary.
                    // This is more robust for structs if direct modification of array elements doesn't always propagate.
                    if hasChanges {
                        self.achievementStatuses = self.achievementStatuses.map { $0 } // Re-assign to ensure UI updates
                    }

        if hasChanges {
            do {
                try context.save()
                print("AchievementManager: Saved context after unlocking achievements.")
            } catch {
                print("AchievementManager: Error saving context after unlocking achievements: \(error)")
            }
        }
    } // Closes checkAchievementsForUnlocks()
    
    // TODO: Add methods to get specific achievement status, etc.
} // Closes class AchievementManager

func getTargetFromCriteria(_ criteria: AchievementCriteria) -> Int {
    switch criteria {
    case .streak(_, let length):
        return length
    case .totalCount(_, let count):
        return count
    }
}
