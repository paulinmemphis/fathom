import Foundation

// Codable DTOs for persistence, intentionally separate from @MainActor code
// to avoid actor isolation crossing warnings.

nonisolated struct InsightPreferenceDTO: Sendable {
    var viewCount: Int
    var actionCount: Int
    var dismissalCount: Int
    var engagementScore: Double
    var lastUpdated: Date
}

// Use raw String for insight type to avoid referencing actor-isolated enums here
nonisolated struct UserPreferenceRecordDTO: Sendable {
    let insightType: String
    let preference: InsightPreferenceDTO
}

// Use raw String for trigger type for the same reason
nonisolated struct ContextualTriggerDTO: Sendable {
    let id: UUID
    let name: String
    let type: String
    var message: String
    var priority: Int
    var cooldownHours: Double
    var lastTriggered: Date?
}

// Codable conformance is now handled by the nonisolated struct declarations.
extension InsightPreferenceDTO: Codable {}
extension UserPreferenceRecordDTO: Codable {}
extension ContextualTriggerDTO: Codable {}

