import Foundation
import CoreData

@objc(JournalEntry)
public class JournalEntry: NSManagedObject {
    // Add this initializer
    @nonobjc public nonisolated override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
}
