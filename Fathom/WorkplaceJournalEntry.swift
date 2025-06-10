//
//  WorkplaceJournalEntry.swift
//  Fathom
//
//  Created by Paul Thomas on 6/10/25.
//


import Foundation

/// The data model for a single Fathom journal entry.
/// Placing this in its own file resolves the "ambiguous for type lookup" and "redeclaration" errors.
struct WorkplaceJournalEntry: Identifiable {
    var id = UUID()
    var title: String
    var text: String
    var date: Date
    var stressLevel: Double?
    var focusScore: Double?
    var workProjects: [String]? = nil
}