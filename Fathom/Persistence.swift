@preconcurrency import CoreData
import SwiftUI
import Combine

@MainActor
final class PersistenceController: ObservableObject {
    // MARK: - 1. Shared Singleton for the App
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Fathom")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
    }

    func loadStore(completion: @escaping (Error?) -> Void) {
        container.loadPersistentStores { storeDescription, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(error)
                    return
                }
                self.container.viewContext.automaticallyMergesChangesFromParent = true
                self.container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
                completion(nil)
            }
        }
    }

    // MARK: - 4. View Context
    var viewContext: NSManagedObjectContext {
        return container.viewContext
    }

    // MARK: - 5. Preview Controller (for SwiftUI Previews with Sample Data)
    @MainActor
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        // Synchronously load the store for previewing.
        let group = DispatchGroup()
        group.enter()
        controller.loadStore { error in
            if let error = error {
                fatalError("Failed to load store for preview: \(error)")
            }
            group.leave()
        }
        group.wait()

        let context = controller.viewContext

        // Create sample JournalEntry data
        for i in 0..<5 {
            let newEntry = JournalEntry(context: context)
            newEntry.id = UUID()
            newEntry.timestamp = Date().addingTimeInterval(-Double(i * 3600 * 24)) // Entries from past days
            newEntry.text = "This is sample journal entry #\(i + 1). It contains some insightful thoughts and reflections from the day."
            newEntry.moodRating = Int16.random(in: 1...5)
            newEntry.isDraft = (i % 2 == 0) // Alternate draft status
        }

        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo) when creating preview data")
        }
        return controller
    }()

    // MARK: - 6. Save Context Helper
    func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                NSLog("Unresolved error saving context: \(nsError), \(nsError.userInfo)")
                // In a real app, you might want to handle this error more gracefully
            }
        }
    }
    
    // MARK: - CRUD Operations (Example for JournalEntry)
    
    func createJournalEntry(text: String, moodRating: Int16?, isDraft: Bool = false) -> JournalEntry {
        let newEntry = JournalEntry(context: viewContext)
        newEntry.id = UUID()
        newEntry.timestamp = Date()
        newEntry.text = text
        if let mood = moodRating {
            newEntry.moodRating = mood
        }
        newEntry.isDraft = isDraft
        
        saveContext()
        return newEntry
    }
    
    func fetchJournalEntries(predicate: NSPredicate? = nil, sortDescriptors: [NSSortDescriptor]? = nil) -> [JournalEntry] {
        let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = sortDescriptors ?? [NSSortDescriptor(keyPath: \JournalEntry.timestamp, ascending: false)]
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            NSLog("Error fetching journal entries: \(error)")
            return []
        }
    }
    
    func deleteJournalEntry(_ entry: JournalEntry) {
        viewContext.delete(entry)
        saveContext()
    }
}
