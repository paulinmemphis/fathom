import Foundation
import CoreData

extension Fathom.WorkplaceCheckIn {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Fathom.WorkplaceCheckIn> {
        return NSFetchRequest<Fathom.WorkplaceCheckIn>(entityName: "WorkplaceCheckIn")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var checkInTime: Date?
    @NSManaged public var checkOutTime: Date?
    @NSManaged public var notes: String?
    @NSManaged public var isAutoCheckIn: Bool
    @NSManaged public var isAutoCheckOut: Bool
    @NSManaged public var focusRating: Int16
    @NSManaged public var stressRating: Int16
    @NSManaged public var sessionNote: String?
    @NSManaged public var workplace: Workplace?
}

// MARK: - Convenience Properties
extension Fathom.WorkplaceCheckIn {
    /// Normalized stress level (0.0 - 1.0)
    var stressLevel: Double {
        Double(stressRating) / 5.0
    }
    /// Normalized focus level (0.0 - 1.0)
    var focusLevel: Double {
        Double(focusRating) / 5.0
    }
    /// Session duration in minutes
    var sessionDuration: Int {
        guard let checkIn = checkInTime else { return 0 }
        let endTime = checkOutTime ?? Date()
        return Int(endTime.timeIntervalSince(checkIn) / 60)
    }
    /// Timestamp for check-in (or fallback)
    var timestamp: Date {
        checkInTime ?? Date()
    }

    var isActive: Bool {
        return checkInTime != nil && checkOutTime == nil
    }
    
    var duration: TimeInterval? {
        guard let checkIn = checkInTime else { return nil }
        let endTime = checkOutTime ?? Date()
        return endTime.timeIntervalSince(checkIn)
    }
    
    var formattedDuration: String {
        guard let duration = duration else { return "N/A" }
        
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var notesOrDefault: String {
        return notes ?? ""
    }
}
