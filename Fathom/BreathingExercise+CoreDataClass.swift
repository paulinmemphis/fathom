//
//  BreathingExercise+CoreDataClass.swift
//  Fathom
//
//  Created by Paul Thomas on 6/28/25.
//
//

import Foundation
import CoreData

public typealias BreathingExerciseCoreDataClassSet = NSSet


public class BreathingExercise: NSManagedObject {

    nonisolated override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }

}
