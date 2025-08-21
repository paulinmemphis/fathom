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
    func convertBreathingExercises(_ coreDataExercises: [Fathom.BreathingExercise]) -> [BreathingData] {
        return coreDataExercises.map { BreathingData(from: $0) }
    }
    
    /// Convert Core Data WorkplaceCheckIn array to WorkplaceCheckInData array
    func convertWorkplaceCheckIns(_ coreDataCheckIns: [Fathom.WorkplaceCheckIn]) -> [WorkplaceCheckInData] {
        return coreDataCheckIns.map { checkIn in
            // Attempt to read a workplace name if present
            let workplaceName = checkIn.workplace?.value(forKey: "name") as? String
            return WorkplaceCheckInData(
                workplaceName: workplaceName,
                sessionDuration: checkIn.sessionDuration,
                stressLevel: checkIn.stressLevel,
                focusLevel: checkIn.focusLevel,
                timestamp: checkIn.timestamp
            )
        }
    }
    
    /// Convert Core Data WorkplaceJournalEntry array to WorkplaceJournalEntryData array
    func convertJournalEntries(_ coreDataEntries: [NSManagedObject]) -> [WorkplaceJournalEntry] {
        return coreDataEntries.compactMap { entry in
    // Map NSManagedObject to WorkplaceJournalEntry
    // This assumes properties: title, text, date, stressLevel, focusScore, workProjects
    guard let title = entry.value(forKey: "title") as? String,
          let text = entry.value(forKey: "text") as? String,
          let date = entry.value(forKey: "date") as? Date else { return nil }
    let stressLevel = entry.value(forKey: "stressLevel") as? Double
    let focusScore = entry.value(forKey: "focusScore") as? Double
    let workProjects = entry.value(forKey: "workProjects") as? [String]
    return WorkplaceJournalEntry(
        title: title,
        text: text,
        date: date,
        stressLevel: stressLevel,
        focusScore: focusScore,
        workProjects: workProjects
    )
}
    }
    
    /// Generate insights using Core Data entities
    func generatePersonalizedInsights(
        from context: NSManagedObjectContext,
        forLastDays days: Int = 7,
        referenceDate: Date = Date()
    ) async -> [InsightData] {
        
        // Calculate date range
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: referenceDate) ?? referenceDate
        let datePredicate = NSPredicate(format: "completedAt >= %@", startDate as NSDate)
        
        do {
            // Fetch breathing exercises
            let breathingRequest: NSFetchRequest<Fathom.BreathingExercise> = Fathom.BreathingExercise.fetchRequest()
            breathingRequest.predicate = datePredicate
            let coreDataBreathingExercises = try context.fetch(breathingRequest)
            let breathingData = convertBreathingExercises(coreDataBreathingExercises)
            
            // Fetch workplace check-ins (if the entity exists)
            var checkInData: [WorkplaceCheckInData] = []
            if let _ = NSEntityDescription.entity(forEntityName: "WorkplaceCheckIn", in: context) {
                let checkInRequest = NSFetchRequest<Fathom.WorkplaceCheckIn>(entityName: "WorkplaceCheckIn")
                checkInRequest.predicate = NSPredicate(format: "timestamp >= %@", startDate as NSDate)
                let coreDataCheckIns = try context.fetch(checkInRequest)
                checkInData = convertWorkplaceCheckIns(coreDataCheckIns)
            }
            
            // Fetch journal entries (if the entity exists)
            var journalData: [WorkplaceJournalEntry] = []
            if let _ = NSEntityDescription.entity(forEntityName: "WorkplaceJournalEntry", in: context) {
                let journalRequest = NSFetchRequest<NSManagedObject>(entityName: "WorkplaceJournalEntry")
                journalRequest.predicate = NSPredicate(format: "date >= %@", startDate as NSDate)
                let coreDataJournalEntries = try context.fetch(journalRequest)
                journalData = convertJournalEntries(coreDataJournalEntries)
            }
            
            // Create empty goals array for now - implement when UserGoal Core Data entity is available
            let goals: [UserGoalData] = []
            
            return await generatePersonalizedInsights(
                checkIns: checkInData,
                breathingLogs: breathingData,
                journalEntries: journalData,
                goals: goals,
                forLastDays: days,
                referenceDate: referenceDate
            )
            
        } catch {
            // Handle fetch errors
            print("Failed to fetch Core Data entities: \(error)")
            return []
        }
    }
    
    /// Convenience method to generate insights for a specific workplace
    func generateWorkplaceSpecificInsights(
        from context: NSManagedObjectContext,
        workplaceName: String,
        forLastDays days: Int = 7,
        referenceDate: Date = Date()
    ) async -> [InsightData] {
        
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: referenceDate) ?? referenceDate
        
        do {
            // Fetch workplace-specific check-ins
            var workplaceCheckIns: [WorkplaceCheckInData] = []
            if let _ = NSEntityDescription.entity(forEntityName: "WorkplaceCheckIn", in: context) {
                let checkInRequest = NSFetchRequest<Fathom.WorkplaceCheckIn>(entityName: "WorkplaceCheckIn")
                checkInRequest.predicate = NSPredicate(
                    format: "timestamp >= %@ AND workplace.name == %@",
                    startDate as NSDate,
                    workplaceName
                )
                let coreDataCheckIns = try context.fetch(checkInRequest)
                workplaceCheckIns = convertWorkplaceCheckIns(coreDataCheckIns)
            }
            
            // Fetch all breathing exercises for the time period
            let breathingRequest: NSFetchRequest<Fathom.BreathingExercise> = Fathom.BreathingExercise.fetchRequest()
            breathingRequest.predicate = NSPredicate(format: "completedAt >= %@", startDate as NSDate)
            let coreDataBreathingExercises = try context.fetch(breathingRequest)
            let breathingData = convertBreathingExercises(coreDataBreathingExercises)
            
            // Fetch workplace-specific journal entries if available
            var journalData: [WorkplaceJournalEntry] = []
            if let _ = NSEntityDescription.entity(forEntityName: "WorkplaceJournalEntry", in: context) {
                let journalRequest = NSFetchRequest<NSManagedObject>(entityName: "WorkplaceJournalEntry")
                journalRequest.predicate = NSPredicate(format: "date >= %@", startDate as NSDate)
                let coreDataJournalEntries = try context.fetch(journalRequest)
                journalData = convertJournalEntries(coreDataJournalEntries)
            }
            
            let goals: [UserGoalData] = []
            
            let allInsights = await generatePersonalizedInsights(
                checkIns: workplaceCheckIns,
                breathingLogs: breathingData,
                journalEntries: journalData,
                goals: goals,
                forLastDays: days,
                referenceDate: referenceDate
            )
            
            // Filter for workplace-specific insights
            return allInsights.filter { insight in
                insight.type == InsightType.workplaceSpecific || 
                insight.message.localizedCaseInsensitiveContains(workplaceName)
            }
            
        } catch {
            print("Failed to fetch workplace-specific data: \(error)")
            return []
        }
    }
}
