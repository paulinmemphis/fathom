import Foundation
import CoreData
import SwiftUI
import Combine

// MARK: - Supporting Types First (to resolve scope issues)

enum PreferenceCategory: String, Codable, Sendable, CaseIterable {
    case financial = "financial"
    case reporting = "reporting"
    case compliance = "compliance"
    case strategic = "strategic"
    case operational = "operational"
}

enum WorkRole: String, Codable, Sendable, CaseIterable {
    case developer
    case designer
    case manager
    case executive
    case analyst
    case consultant
    case other

    var displayName: String { rawValue.capitalized }
}

enum InsightComplexity: String, CaseIterable, Sendable {
    case basic = "Basic"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    var intValue: Int {
        switch self {
        case .basic: return 1
        case .intermediate: return 2
        case .advanced: return 3
        }
    }

    var description: String {
        switch self {
        case .basic:
            return "Simple, actionable insights"
        case .intermediate:
            return "Moderate complexity with some analysis"
        case .advanced:
            return "Complex insights requiring deeper understanding"
        }
    }
}

enum WorkIndustry: String, CaseIterable, Sendable {
    case technology
    case healthcare
    case finance
    case education
    case retail
    case manufacturing
    case consulting
    case media
    case government
    case nonprofit
    case other

    var culturalNorms: CulturalNorms {
        switch self {
        case .technology:
            return CulturalNorms(pace: "Fast", hierarchy: "Flat", communication: "Direct", workLifeBalance: "Flexible")
        case .healthcare:
            return CulturalNorms(pace: "Urgent", hierarchy: "Structured", communication: "Precise", workLifeBalance: "Demanding")
        case .finance:
            return CulturalNorms(pace: "Fast", hierarchy: "Hierarchical", communication: "Formal", workLifeBalance: "Intense")
        case .education:
            return CulturalNorms(pace: "Steady", hierarchy: "Collaborative", communication: "Supportive", workLifeBalance: "Seasonal")
        case .retail:
            return CulturalNorms(pace: "Variable", hierarchy: "Clear", communication: "Customer-focused", workLifeBalance: "Shift-based")
        case .manufacturing:
            return CulturalNorms(pace: "Consistent", hierarchy: "Clear", communication: "Safety-focused", workLifeBalance: "Structured")
        case .consulting:
            return CulturalNorms(pace: "Project-driven", hierarchy: "Client-focused", communication: "Analytical", workLifeBalance: "Variable")
        case .media:
            return CulturalNorms(pace: "Deadline-driven", hierarchy: "Creative", communication: "Collaborative", workLifeBalance: "Irregular")
        case .government:
            return CulturalNorms(pace: "Methodical", hierarchy: "Formal", communication: "Procedural", workLifeBalance: "Stable")
        case .nonprofit:
            return CulturalNorms(pace: "Mission-driven", hierarchy: "Collaborative", communication: "Values-based", workLifeBalance: "Purpose-focused")
        case .other:
            return CulturalNorms(pace: "Variable", hierarchy: "Variable", communication: "Adaptive", workLifeBalance: "Variable")
        }
    }
}

struct CulturalNorms: Sendable, Equatable {
    let pace: String
    let hierarchy: String
    let communication: String
    let workLifeBalance: String
}

// MARK: - App Data Models

struct WorkplaceCheckInData: Sendable {
    let workplaceName: String?
    let sessionDuration: Int
    let stressLevel: Double?
    let focusLevel: Double?
    let timestamp: Date

    init(
        workplaceName: String? = nil,
        sessionDuration: Int = 0,
        stressLevel: Double? = nil,
        focusLevel: Double? = nil,
        timestamp: Date = Date()
    ) {
        self.workplaceName = workplaceName
        self.sessionDuration = max(0, sessionDuration)
        self.stressLevel = stressLevel.map { max(0.0, min(1.0, $0)) }
        self.focusLevel = focusLevel.map { max(0.0, min(1.0, $0)) }
        self.timestamp = timestamp
    }
}

// MARK: - Core Data Stack with iOS 26 Beta Fixes

final class FathomCoreDataStack: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    
    // Remove @MainActor to fix ObservableObject conformance
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "FathomDataModel")
        
        // iOS 26: Improved configuration for concurrent access
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber,
                                                              forKey: NSPersistentHistoryTrackingKey)
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber,
                                                              forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Core Data error: \(error), \(error.userInfo)")
            }
        }
        
        // iOS 26: Enhanced automatic merging - use safer merge policy
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    // Remove @concurrent - not needed for this method
    func performBackgroundTask<T: Sendable>(_ block: @Sendable @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                do {
                    let result = try block(context)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // iOS 26: Enhanced save with improved error handling
    @MainActor
    func save() async throws {
        guard viewContext.hasChanges else { return }
        
        try await withCheckedThrowingContinuation { continuation in
            viewContext.perform {
                do {
                    try self.viewContext.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - Core Data Models with iOS 26 Beta Fixes

extension ContextualTriggerEntity {
    // Fix: Use the correct Core Data API for thread-safe access
    var safeID: UUID {
        var result: UUID!
        managedObjectContext?.performAndWait {
            result = self.id ?? UUID()
        }
        return result
    }
    
    var safeName: String {
        var result: String!
        managedObjectContext?.performAndWait {
            result = self.name ?? "Unnamed Trigger"
        }
        return result
    }

    // Ensure defaults on insert to satisfy validation
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        let now = Date()
        if self.value(forKey: "id") == nil {
            self.id = UUID()
        }
        if (self.value(forKey: "name") as? String)?.isEmpty != false {
            self.name = "Unnamed Trigger"
        }
        if self.value(forKey: "isActive") == nil {
            self.isActive = true
        }
        if self.value(forKey: "createdAt") == nil {
            self.createdAt = now
        }
        if self.value(forKey: "updatedAt") == nil {
            self.updatedAt = now
        }
    }

    // Maintain updatedAt on change
    override public func willSave() {
        super.willSave()
        if self.hasChanges {
            self.updatedAt = Date()
        }
    }
}

extension UserPreferenceEntity {
    // Swift 6.2: Type-safe category handling
    var category: PreferenceCategory {
        get { PreferenceCategory(rawValue: categoryRawValue ?? "") ?? .operational }
        set { categoryRawValue = newValue.rawValue }
    }
    
    // Validation hooks
    override public func validateForInsert() throws {
        try super.validateForInsert()
        try validateCategory()
    }
    
    override public func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateCategory()
    }
    
    private func validateCategory() throws {
        guard let raw = categoryRawValue, PreferenceCategory(rawValue: raw) != nil else {
            throw CoreDataError.invalidCategory(categoryRawValue ?? "unknown")
        }
    }

    // Ensure defaults on insert to satisfy validation
    override public func awakeFromInsert() {
        super.awakeFromInsert()
        let now = Date()
        if self.value(forKey: "id") == nil {
            self.id = UUID()
        }
        if (self.value(forKey: "key") as? String)?.isEmpty != false {
            self.key = "unknown"
        }
        if (self.value(forKey: "value") as? String)?.isEmpty != false {
            self.value = ""
        }
        if (self.value(forKey: "categoryRawValue") as? String)?.isEmpty != false {
            self.categoryRawValue = PreferenceCategory.operational.rawValue
        }
        if self.value(forKey: "isActive") == nil {
            self.isActive = true
        }
        if self.value(forKey: "createdAt") == nil {
            self.createdAt = now
        }
        if self.value(forKey: "updatedAt") == nil {
            self.updatedAt = now
        }
    }

    // Maintain updatedAt on change
    override public func willSave() {
        super.willSave()
        if self.hasChanges {
            self.updatedAt = Date()
        }
    }
}

// MARK: - Core Data Manager with iOS 26 Beta Fixes

final class FathomCoreDataManager: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    
    private let coreDataStack: FathomCoreDataStack
    
    init(coreDataStack: FathomCoreDataStack = FathomCoreDataStack()) {
        self.coreDataStack = coreDataStack
    }
    
    var viewContext: NSManagedObjectContext {
        coreDataStack.viewContext
    }
    
    // MARK: - ContextualTrigger Operations
    
    func createContextualTrigger(
        name: String,
        description: String? = nil,
        isActive: Bool = true,
        userPreferenceId: UUID? = nil
    ) async throws -> StoredContextualTrigger {
        
        return try await coreDataStack.performBackgroundTask { context in
            let trigger = ContextualTriggerEntity(context: context)
            trigger.id = UUID()
            trigger.name = name
            trigger.triggerDescription = description
            trigger.isActive = isActive
            trigger.createdAt = Date()
            trigger.updatedAt = Date()
            
            // Handle relationship if provided
            if let preferenceId = userPreferenceId {
                let request: NSFetchRequest<UserPreferenceEntity> = UserPreferenceEntity.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", preferenceId as CVarArg)
                
                if let preference = try context.fetch(request).first {
                    trigger.userPreference = preference
                }
            }
            
            try context.save()
            // Build value struct to return across concurrency boundary
            return StoredContextualTrigger(
                id: trigger.id ?? UUID(),
                name: trigger.name ?? "Unknown",
                description: trigger.triggerDescription,
                isActive: trigger.isActive,
                userPreferenceId: trigger.userPreference?.id
            )
        }
    }
    
    @MainActor
    func fetchContextualTriggers() async throws -> [ContextualTriggerEntity] {
        let request: NSFetchRequest<ContextualTriggerEntity> = ContextualTriggerEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ContextualTriggerEntity.createdAt, ascending: false)]
        return try viewContext.fetch(request)
    }
    
    // MARK: - UserPreference Operations
    
    func createUserPreference(
        key: String,
        value: String,
        category: PreferenceCategory,
        isActive: Bool = true
    ) async throws -> UserPreference {
        
        return try await coreDataStack.performBackgroundTask { context in
            let preference = UserPreferenceEntity(context: context)
            preference.id = UUID()
            preference.key = key
            preference.value = value
            preference.category = category
            preference.isActive = isActive
            preference.createdAt = Date()
            preference.updatedAt = Date()
            
            try context.save()
            // Build value struct
            return UserPreference(
                id: preference.id ?? UUID(),
                key: preference.key ?? "unknown",
                value: preference.value ?? "",
                category: preference.category,
                isActive: preference.isActive,
                contextualTriggerIds: (preference.triggers as? Set<ContextualTriggerEntity> ?? []).compactMap { $0.id }
            )
        }
    }
    
    @MainActor
    func fetchUserPreferences() async throws -> [UserPreferenceEntity] {
        let request: NSFetchRequest<UserPreferenceEntity> = UserPreferenceEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \UserPreferenceEntity.createdAt, ascending: false)]
        return try viewContext.fetch(request)
    }
    
    // MARK: - Relationship Operations
    
    func linkTriggerToPreference(triggerId: UUID, preferenceId: UUID) async throws {
        try await coreDataStack.performBackgroundTask { context in
            // Fix: Create fetch requests in the background context
            let triggerRequest = NSFetchRequest<ContextualTriggerEntity>(entityName: "ContextualTriggerEntity")
            triggerRequest.predicate = NSPredicate(format: "id == %@", triggerId as CVarArg)
            
            let preferenceRequest = NSFetchRequest<UserPreferenceEntity>(entityName: "UserPreferenceEntity")
            preferenceRequest.predicate = NSPredicate(format: "id == %@", preferenceId as CVarArg)
            
            guard let trigger = try context.fetch(triggerRequest).first,
                  let preference = try context.fetch(preferenceRequest).first else {
                throw CoreDataError.entityNotFound
            }
            
            trigger.userPreference = preference
            // Use generated accessor to maintain inverse relationship
            preference.addToTriggers(trigger)
            
            try context.save()
        }
    }
    
    // MARK: - iOS 26 Enhanced Features
    
    @available(iOS 26.0, *)
    func performBulkUpdate() async throws {
        // iOS 26: Enhanced batch operations with improved performance
        try await coreDataStack.performBackgroundTask { context in
            let request = NSBatchUpdateRequest(entityName: "ContextualTriggerEntity")
            request.predicate = NSPredicate(format: "updatedAt < %@", Date().addingTimeInterval(-86400) as CVarArg)
            request.propertiesToUpdate = ["updatedAt": Date()]
            request.resultType = .updatedObjectsCountResultType
            
            let result = try context.execute(request) as? NSBatchUpdateResult
            print("Updated \(result?.result ?? 0) entities")
        }
    }
}

// MARK: - Error Handling (Fix Sendable conformance)

enum CoreDataError: Error, Sendable {
    case invalidCategory(String)
    case entityNotFound
    case saveFailed(Error)
    
    // Fix: Make error description nonisolated
    var errorDescription: String? {
        switch self {
        case .invalidCategory(let category):
            return "Invalid category: \(category)"
        case .entityNotFound:
            return "Entity not found"
        case .saveFailed(let error):
            return "Save failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - SwiftUI Integration (Fixed)

@MainActor
struct FathomContentView: View {
    @StateObject private var coreDataManager = FathomCoreDataManager()
    @State private var triggers: [ContextualTriggerEntity] = []
    @State private var preferences: [UserPreferenceEntity] = []
    
    var body: some View {
        NavigationView {
            List {
                Section("Triggers") {
                    ForEach(triggers, id: \.objectID) { trigger in
                        Text(trigger.safeName)
                    }
                }
                
                Section("Preferences") {
                    ForEach(preferences, id: \.objectID) { preference in
                        Text(preference.key ?? "unknown")
                    }
                }
            }
            .navigationTitle("Fathom")
            .task {
                await loadData()
            }
        }
        .environment(\.managedObjectContext, coreDataManager.viewContext)
    }
    
    private func loadData() async {
        do {
            let loadedTriggers = try await coreDataManager.fetchContextualTriggers()
            let loadedPreferences = try await coreDataManager.fetchUserPreferences()
            
            // Update on main actor
            await MainActor.run {
                self.triggers = loadedTriggers
                self.preferences = loadedPreferences
            }
        } catch {
            print("Failed to load data: \(error)")
        }
    }
}

// MARK: - Core Data Model Extensions (Generated in DerivedSources)

// MARK: - Pure Swift Models (storage-only, distinct from engine models)

struct StoredContextualTrigger: Sendable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    let userPreferenceId: UUID?
    
    nonisolated init(id: UUID = UUID(),
         name: String,
         description: String? = nil,
         isActive: Bool = true,
         userPreferenceId: UUID? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.isActive = isActive
        self.createdAt = Date()
        self.updatedAt = Date()
        self.userPreferenceId = userPreferenceId
    }
    
    // Convert from Core Data entity
    nonisolated init(from entity: ContextualTriggerEntity) {
        self.id = entity.id ?? UUID()
        self.name = entity.name ?? "Unknown"
        self.description = entity.triggerDescription
        self.isActive = entity.isActive
        self.createdAt = entity.createdAt ?? Date()
        self.updatedAt = entity.updatedAt ?? Date()
        self.userPreferenceId = entity.userPreference?.id
    }
}

struct UserPreference: Sendable, Identifiable {
    let id: UUID
    let key: String
    let value: String
    let category: PreferenceCategory
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    let contextualTriggerIds: [UUID]
    
    nonisolated init(id: UUID = UUID(),
         key: String,
         value: String,
         category: PreferenceCategory,
         isActive: Bool = true,
         contextualTriggerIds: [UUID] = []) {
        self.id = id
        self.key = key
        self.value = value
        self.category = category
        self.isActive = isActive
        self.createdAt = Date()
        self.updatedAt = Date()
        self.contextualTriggerIds = contextualTriggerIds
    }
    
    // Convert from Core Data entity
    nonisolated init(from entity: UserPreferenceEntity) {
        self.id = entity.id ?? UUID()
        self.key = entity.key ?? "unknown"
        self.value = entity.value ?? ""
        self.category = entity.category
        self.isActive = entity.isActive
        self.createdAt = entity.createdAt ?? Date()
        self.updatedAt = entity.updatedAt ?? Date()
        let triggerSet = (entity.triggers as? Set<ContextualTriggerEntity>) ?? []
        self.contextualTriggerIds = triggerSet.map { $0.id ?? UUID() }
    }
}
