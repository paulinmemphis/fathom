//
//  JournalEntry+CoreDataClass.swift
//  Fathom
//
//  Created by Paul Thomas on 6/29/25.
//
//

public import Foundation
public import CoreData

public typealias JournalEntryCoreDataClassSet = NSSet

@objc(JournalEntry)
public nonisolated class JournalEntry: NSManagedObject, Identifiable {
    // This class is intentionally left empty
    // Core Data properties are defined in the JournalEntry+CoreDataProperties.swift file
}
