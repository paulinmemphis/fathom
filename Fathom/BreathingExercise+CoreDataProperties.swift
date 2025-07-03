//
//  BreathingExercise+CoreDataProperties.swift
//  Fathom
//
//  Created by Paul Thomas on 6/28/25.
//
//

public import Foundation
public import CoreData


public typealias BreathingExerciseCoreDataPropertiesSet = NSSet

extension BreathingExercise {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<BreathingExercise> {
        return NSFetchRequest<BreathingExercise>(entityName: "BreathingExercise")
    }

    @NSManaged public var completedAt: Date?
    @NSManaged public var duration: Double
    @NSManaged public var exerciseTypes: String?
    @NSManaged public var id: UUID?
    @NSManaged public var totalBreaths: Int16
    @NSManaged public var userRating: Int16

}

extension BreathingExercise : Identifiable {

}
