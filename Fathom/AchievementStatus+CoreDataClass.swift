//
//  AchievementStatus+CoreDataClass.swift
//  Fathom
//
//  Created on 12/15/24.
//
//

import Foundation
import CoreData

@objc(AchievementStatus)
public class AchievementStatus: NSManagedObject {
    
    @nonobjc nonisolated public override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }

}
