//
//  BreathingExercise+CoreDataProperties.swift
//  Fathom
//
//  Created by Cascade on $(DATE).
//
//

import Foundation
import CoreData

extension BreathingExercise {

    @NSManaged public var completedAt: Date?
    @NSManaged public var duration: Double
    @NSManaged public var exerciseType: String?
    @NSManaged public var id: UUID?
    @NSManaged public var totalBreaths: Int16
    @NSManaged public var userRating: Int16

}
