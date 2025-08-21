import Foundation

// Codable DTOs for persistence, intentionally separate from @MainActor code
// to avoid actor isolation crossing warnings.

struct InsightPreferenceDTO: Sendable {
    var viewCount: Int
    var actionCount: Int
    var dismissalCount: Int
    var engagementScore: Double
    var lastUpdated: Date
}

// Use raw String for insight type to avoid referencing actor-isolated enums here
struct UserPreferenceRecordDTO: Sendable {
    let insightType: String
    let preference: InsightPreferenceDTO
}

// Use raw String for trigger type for the same reason
struct ContextualTriggerDTO: Sendable {
    let id: UUID
    let name: String
    let type: String
    var message: String
    var priority: Int
    var cooldownHours: Double
    var lastTriggered: Date?
}

// Place Codable conformances in a nonisolated extension so synthesized
// encode/decode are not MainActor-isolated under the project's default isolation.
nonisolated extension InsightPreferenceDTO: Codable {}
nonisolated extension UserPreferenceRecordDTO: Codable {}
nonisolated extension ContextualTriggerDTO: Codable {}

