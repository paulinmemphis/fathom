//
//  AchievementStatus+CoreDataProperties.swift
//  Fathom
//
//  Created by Paul Thomas on 6/13/25.
//
//

public import Foundation
public import CoreData


public typealias AchievementStatusCoreDataPropertiesSet = NSSet

extension AchievementStatus {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AchievementStatus> {
        return NSFetchRequest<AchievementStatus>(entityName: "AchievementStatus")
    }

    @NSManaged public var achievementID: String?
    @NSManaged public var currentProgress: Int32
    @NSManaged public var isUnlocked: Bool
    @NSManaged public var targetProgress: Int32
    @NSManaged public var unlockedDate: Date?

}

extension AchievementStatus : Identifiable {

}
