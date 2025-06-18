import Foundation
import CoreData

extension JournalEntry {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<JournalEntry> {
        return NSFetchRequest<JournalEntry>(entityName: "JournalEntry")
    }

    // == IMPORTANT ==
    // Verify these @NSManaged properties match your Fathom.xcdatamodeld attributes EXACTLY
    // If 'id' is optional in your model, use 'UUID?'. If non-optional, use 'UUID'.
    // Adjust types for other properties as needed (e.g., String?, Date?, etc.)
    @NSManaged public var id: UUID?
    @NSManaged public var timestamp: Date?
    @NSManaged public var text: String?
    @NSManaged public var moodRating: Int16
    @NSManaged public var isDraft: Bool
    // Add any other attributes from your JournalEntry entity here

}

extension JournalEntry : Identifiable {
    // This extension makes JournalEntry conform to Identifiable.
    // If your 'id' attribute is non-optional (e.g., @NSManaged public var id: UUID),
    // this extension can be empty: extension JournalEntry : Identifiable {}
    // If 'id' is optional (e.g., @NSManaged public var id: UUID?),
    // you might need to provide a computed property for Identifiable's 'id',
    // or ensure your usage handles the optionality, e.g. ForEach(entries, id: \.self) or similar.
    // For simplicity with CoreData and Identifiable, often a non-optional UUID attribute is preferred.
}
