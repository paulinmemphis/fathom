//
//  UserStats+CoreDataProperties.swift
//  Fathom
//
//  Created by Paul Thomas on 6/13/25.
//
//

public import Foundation
public import CoreData


public typealias UserStatsCoreDataPropertiesSet = NSSet

extension UserStats {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserStats> {
        return NSFetchRequest<UserStats>(entityName: "UserStats")
    }

    @NSManaged public var currentBreathingStreak: Int16
    @NSManaged public var currentDailyReflectionStreak: Int16
    @NSManaged public var currentWorkSessionStreak: Int16
    @NSManaged public var lastBreathingDate: Date?
    @NSManaged public var lastDailyReflectionDate: Date?
    @NSManaged public var lastWorkSessionDate: Date?
    @NSManaged public var longestBreathingStreak: Int16
    @NSManaged public var longestDailyReflectionStreak: Int16
    @NSManaged public var longestWorkSessionStreak: Int16
    @NSManaged public var totalBreathingExercisesLogged: Int32
    @NSManaged public var totalReflectionsAdded: Int32
    @NSManaged public var totalWorkSessionsCompleted: Int32

}

extension UserStats : Identifiable {

}
