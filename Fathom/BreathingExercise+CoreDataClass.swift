//
//  BreathingExercise+CoreDataClass.swift
//  Fathom
//
//  Created by Cascade on $(DATE).
//
//

import Foundation
import CoreData

@objc(BreathingExercise)
public class BreathingExercise: NSManagedObject {

    // Add custom methods here if needed
    
    @nonobjc nonisolated public class func fetchRequest() -> NSFetchRequest<BreathingExercise> {
        return NSFetchRequest<BreathingExercise>(entityName: "BreathingExercise")
    }
    
    @nonobjc nonisolated override public init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
}
