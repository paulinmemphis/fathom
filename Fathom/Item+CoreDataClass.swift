import Foundation
import CoreData

@objc(Item)
nonisolated public class Item: NSManagedObject {}

// Note: This class is explicitly marked as nonisolated to match NSManagedObject's
// actor isolation and prevent warnings about main actor isolation mismatches.

extension Item {
    @NSManaged public var timestamp: Date?
}

extension Item: Identifiable {}

