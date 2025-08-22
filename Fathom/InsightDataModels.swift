import Foundation

// MARK: - Insights Core Models

enum InsightType: String, Codable, Sendable, CaseIterable, Hashable {
    case observation
    case question
    case suggestion
    case affirmation
    case alert
    case prediction
    case anomaly
    case warning
    case celebration
    case trend
    case correlation
    case goalProgress
    case workplaceSpecific
}

struct InsightData: Sendable, Identifiable, Hashable {
    let id: UUID
    var type: InsightType
    var message: String
    var priority: Int
    var confidence: Double
    
    init(id: UUID = UUID(), type: InsightType, message: String, priority: Int = 0, confidence: Double = 1.0) {
        self.id = id
        self.type = type
        self.message = message
        self.priority = priority
        self.confidence = confidence
    }
}

// MARK: - Contextual Triggers

enum TriggerType: String, Codable, Sendable, CaseIterable {
    case highStress
    case lowFocus
    case longSession
    case workplacePattern
    case reflectionPrompt
}

struct ContextualTrigger: Sendable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let type: TriggerType
    var message: String
    var priority: Int
    var cooldownHours: Double
    var lastTriggered: Date?
    
    init(id: UUID = UUID(), name: String, type: TriggerType, message: String, priority: Int, cooldownHours: Double, lastTriggered: Date? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.message = message
        self.priority = priority
        self.cooldownHours = cooldownHours
        self.lastTriggered = lastTriggered
    }
    
    var canTrigger: Bool {
        guard let last = lastTriggered else { return true }
        let cooldown = last.addingTimeInterval(cooldownHours * 3600)
        return Date() >= cooldown
    }
}

// MARK: - Engagement Tracking

enum InteractionAction: String, Codable, Sendable {
    case viewed
    case dismissed
    case actionTaken
}

struct InsightPreference: Sendable, Equatable {
    let insightType: InsightType
    var viewCount: Int
    var actionCount: Int
    var dismissalCount: Int
    var engagementScore: Double
    var lastUpdated: Date
    
    init(insightType: InsightType,
         viewCount: Int = 0,
         actionCount: Int = 0,
         dismissalCount: Int = 0,
         engagementScore: Double = 0.5,
         lastUpdated: Date = Date()) {
        self.insightType = insightType
        self.viewCount = viewCount
        self.actionCount = actionCount
        self.dismissalCount = dismissalCount
        self.engagementScore = engagementScore
        self.lastUpdated = lastUpdated
    }
    
    mutating func updateEngagement(dismissed: Bool, actionTaken: Bool) {
        viewCount += 1
        if dismissed { dismissalCount += 1 }
        if actionTaken { actionCount += 1 }
        let total = max(1, viewCount + dismissalCount + actionCount)
        let positiveRatio = Double(actionCount) / Double(total)
        let dismissalPenalty = Double(dismissalCount) / Double(total) * 0.3
        engagementScore = max(0.0, min(1.0, positiveRatio - dismissalPenalty))
        lastUpdated = Date()
    }
    
    var actionRate: Double { guard viewCount > 0 else { return 0.0 }; return Double(actionCount) / Double(viewCount) }
    var dismissalRate: Double { guard viewCount > 0 else { return 0.0 }; return Double(dismissalCount) / Double(viewCount) }
}

typealias UserPreferencesDictionary = [InsightType: InsightPreference]
