//
//  JournalEntry+CoreDataProperties.swift
//  Fathom
//
//  Created by Paul Thomas on 6/29/25.
//
//

public import Foundation
public import CoreData


public typealias JournalEntryCoreDataPropertiesSet = NSSet

extension JournalEntry {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<JournalEntry> {
        return NSFetchRequest<JournalEntry>(entityName: "JournalEntry")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var timestamp: Date?
    @NSManaged public var text: String?
    @NSManaged public var moodRating: Int16
    @NSManaged public var isDraft: Bool

}

// Identifiable conformance is now declared in JournalEntry+CoreDataClass.swift
extension JournalEntry {

}
