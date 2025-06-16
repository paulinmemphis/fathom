import Foundation
import CoreData

extension WorkplaceCheckIn {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<WorkplaceCheckIn> {
        return NSFetchRequest<WorkplaceCheckIn>(entityName: "WorkplaceCheckIn")
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
extension WorkplaceCheckIn {
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
