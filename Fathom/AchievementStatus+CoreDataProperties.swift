//
//  AchievementStatus+CoreDataProperties.swift
//  Fathom
//
//  Created on 12/15/24.
//
//

import Foundation
import CoreData


extension AchievementStatus {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AchievementStatus> {
        return NSFetchRequest<AchievementStatus>(entityName: "AchievementStatus")
    }

    @NSManaged public var achievementID: String
    @NSManaged public var dateUnlocked: Date?
    @NSManaged public var isUnlocked: Bool
    @NSManaged public var progress: Int32

}

extension AchievementStatus : Identifiable {

}
