import Foundation
import CoreData

// MARK: - Bridge Extensions
// These extensions convert between Core Data entities and PersonalizationEngine types

/*
 // Placeholder: Implement this when WorkplaceCheckIn Core Data entity is finalized
 extension WorkplaceCheckInData {
     init(from coreDataCheckIn: Fathom.WorkplaceCheckIn) {
         self.init(
             id: coreDataCheckIn.id ?? UUID(),
             timestamp: coreDataCheckIn.checkInTime ?? Date(),
             stressLevel: Double(coreDataCheckIn.stressRating) / 5.0, // Example conversion
             focusLevel: Double(coreDataCheckIn.focusRating) / 5.0, // Example conversion
             sessionDuration: Int(coreDataCheckIn.sessionDuration)
         )
     }
 }
 */



/*
 // Placeholder: Implement this when Insight Core Data entity is created
 extension InsightData {
     init(from coreDataInsight: Any) {
         self.init(
             type: .suggestion, // or get from Core Data
             message: "Default message", // or get from Core Data
             priority: 5, // or get from Core Data
             confidence: 0.8 // or get from Core Data
         )
     }
 }
 */

// MARK: - PersonalizationEngine Extension for Core Data Integration

@available(iOS 14.0, *)
extension PersonalizationEngine {
    
    /// Convert Core Data BreathingExercise array to BreathingSessionData array
    func convertBreathingExercises(_ coreDataExercises: [Fathom.BreathingExercise]) -> [BreathingSessionData] {
        return coreDataExercises.map(BreathingSessionData.init(fromMO:))
    }
    
    /// Generate insights using Core Data entities
    func generatePersonalizedInsights(
        from context: NSManagedObjectContext,
        forLastDays days: Int = 7,
        referenceDate: Date = Date()
    ) async -> [InsightData] {
        
        // Fetch Core Data entities
        let breathingRequest: NSFetchRequest<Fathom.BreathingExercise> = Fathom.BreathingExercise.fetchRequest()
        
        // Add date filtering
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: referenceDate) ?? referenceDate
        breathingRequest.predicate = NSPredicate(format: "completedAt >= %@", startDate as NSDate)
        
        do {
            let coreDataBreathingExercises = try context.fetch(breathingRequest)
            let personalizationBreathingExercises = convertBreathingExercises(coreDataBreathingExercises)
            
            // Create empty arrays for other data types - you'll need to implement these
            let checkIns: [WorkplaceCheckInData] = [] // Implement based on your Core Data model
            let journalEntries: [WorkplaceJournalEntryData] = [] // Implement based on your Core Data model
            let goals: [UserGoalData] = [] // Implement based on your Core Data model
            
            return await generatePersonalizedInsights(
                checkIns: checkIns,
                breathingLogs: personalizationBreathingExercises,
                journalEntries: journalEntries,
                goals: goals,
                forLastDays: days,
                referenceDate: referenceDate
            )
            
        } catch {
            // The logger is private, so we're using print for now.
            print("Failed to fetch Core Data entities: \(error)")
            return []
        }
    }
}