import Foundation
import CoreData
import CoreLocation

extension Workplace {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Workplace> {
        return NSFetchRequest<Workplace>(entityName: "Workplace")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var address: String?
    @NSManaged public var notes: String?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var workingHoursPerDay: Double
    @NSManaged public var workingDays: Data? // Stored as serialized Set<Int>
    @NSManaged public var notificationsEnabled: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var checkIns: NSSet?
}

// MARK: - Convenience Properties
extension Workplace {
    var workingDaysArray: [Int] {
        get {
            if let data = workingDays, let decoded = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [Int] {
                return decoded
            }
            return [2, 3, 4, 5, 6] // Default: Monday-Friday
        }
        set {
            if let encoded = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: false) {
                workingDays = encoded
            }
        }
    }
    
    var coordinate: CLLocationCoordinate2D {
        get {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }
    
    var formattedWorkingHours: String {
        return String(format: "%.1f hours", workingHoursPerDay)
    }
    
    var nameOrDefault: String {
        return name ?? "Unnamed Workplace"
    }
    
    var addressOrDefault: String {
        return address ?? "No address"
    }
    
    var notesOrDefault: String {
        return notes ?? ""
    }
}

// MARK: Generated accessors for checkIns
extension Workplace {
    @objc(addCheckInsObject:)
    @NSManaged public func addToCheckIns(_ value: WorkplaceCheckIn)

    @objc(removeCheckInsObject:)
    @NSManaged public func removeFromCheckIns(_ value: WorkplaceCheckIn)

    @objc(addCheckIns:)
    @NSManaged public func addToCheckIns(_ values: NSSet)

    @objc(removeCheckIns:)
    @NSManaged public func removeFromCheckIns(_ values: NSSet)
}
