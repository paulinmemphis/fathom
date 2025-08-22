import Foundation
import CoreData

// MARK: - Bridge DTO Initializers
// These extensions convert between Core Data entities and PersonalizationEngine DTOs

extension BreathingData {
    init(from coreDataExercise: Fathom.BreathingExercise) {
        self.init(
            id: coreDataExercise.id ?? UUID(),
            completedAt: coreDataExercise.completedAt ?? Date(),
            duration: coreDataExercise.duration,
            exerciseTypes: coreDataExercise.exerciseTypes ?? "unknown"
        )
    }
}

extension WorkplaceJournalEntryData {
    init(from coreDataEntry: Fathom.JournalEntry) {
        let components = coreDataEntry.text?.split(separator: "\n", maxSplits: 1).map(String.init) ?? []
        let title = components.first ?? ""
        let content = components.count > 1 ? components[1] : ""
        let stress = (5.0 - Double(coreDataEntry.moodRating)) / 4.0

        self.init(
            id: coreDataEntry.id ?? UUID(),
            timestamp: coreDataEntry.timestamp ?? Date(),
            title: title,
            content: content,
            stressLevel: stress,
            focusScore: 0.0 // JournalEntry does not have a focus score
        )
    }
}

extension WorkplaceCheckInData {
    init(from coreDataCheckIn: Fathom.WorkplaceCheckIn) {
        self.init(
            id: coreDataCheckIn.id ?? UUID(),
            timestamp: coreDataCheckIn.checkInTime ?? Date(),
            stressLevel: coreDataCheckIn.stressLevel,
            focusLevel: coreDataCheckIn.focusLevel,
            sessionDuration: Int(coreDataCheckIn.sessionDuration)
        )
    }
}

// MARK: - PersonalizationBridge Class

@available(iOS 14.0, *)
@MainActor
final class PersonalizationBridge {
    private let context: NSManagedObjectContext
    private let engine: PersonalizationEngine

    init(context: NSManagedObjectContext, engine: PersonalizationEngine) {
        self.context = context
        self.engine = engine
    }

    /// Generate insights using Core Data entities
    func generateInsightsFromCoreData(
        forLastDays days: Int = 7,
        referenceDate: Date = Date()
    ) async -> [AppInsight] {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: referenceDate) ?? referenceDate

        let fetchedDataResult: Result<(breathing: [BreathingData], checkIns: [WorkplaceCheckInData], journal: [WorkplaceJournalEntryData]), Error>
        do {
            let breathingData = try self.fetchBreathingExercises(since: startDate)
            let checkInData = try self.fetchWorkplaceCheckIns(since: startDate)
            let journalData = try self.fetchJournalEntries(since: startDate)
            fetchedDataResult = .success((breathingData, checkInData, journalData))
        } catch {
            fetchedDataResult = .failure(error)
        }

        switch fetchedDataResult {
        case .failure(let error):
            print("Failed to fetch Core Data entities: \(error.localizedDescription)")
            return []
        case .success(let data):
            let goals: [PersonalizationGoalData] = [] // Goals are not in Core Data yet

            let insights = await self.engine.generatePersonalizedInsights(
                checkIns: data.checkIns,
                breathingLogs: data.breathing,
                journalEntries: data.journal,
                goals: goals,
                forLastDays: days,
                referenceDate: referenceDate
            )
            return insights.map { AppInsight(from: $0) }
        }
    }

    // MARK: - Private Fetch Helpers

    private func fetchBreathingExercises(since date: Date) throws -> [BreathingData] {
        let request: NSFetchRequest<Fathom.BreathingExercise> = Fathom.BreathingExercise.fetchRequest()
        request.predicate = NSPredicate(format: "completedAt >= %@", date as NSDate)
        let results = try context.fetch(request)
        return results.map(BreathingData.init)
    }

    private func fetchWorkplaceCheckIns(since date: Date) throws -> [WorkplaceCheckInData] {
        let request: NSFetchRequest<Fathom.WorkplaceCheckIn> = Fathom.WorkplaceCheckIn.fetchRequest()
        request.predicate = NSPredicate(format: "checkInTime >= %@", date as NSDate)
        let results = try context.fetch(request)
        return results.map(WorkplaceCheckInData.init)
    }

    private func fetchJournalEntries(since date: Date) throws -> [WorkplaceJournalEntryData] {
        let request: NSFetchRequest<Fathom.JournalEntry> = Fathom.JournalEntry.fetchRequest()
        request.predicate = NSPredicate(format: "timestamp >= %@", date as NSDate)
        let results = try context.fetch(request)
        return results.map(WorkplaceJournalEntryData.init)
    }
}
