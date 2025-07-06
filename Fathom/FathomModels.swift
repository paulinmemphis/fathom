import Foundation

// MARK: - Type Aliases

typealias UserPreferencesDictionary = [InsightType: UserPreference]

// MARK: - Errors

enum PersonalizationError: Error, LocalizedError {
    case persistenceFailure(underlying: Error)
    case invalidData
    case initializationFailure
    case invalidUserInput
    
    var errorDescription: String? {
        switch self {
        case .persistenceFailure(let error):
            return "Failed to save user preferences: \(error.localizedDescription)"
        case .invalidData:
            return "Invalid preference data format"
        case .initializationFailure:
            return "Failed to initialize personalization engine"
        case .invalidUserInput:
            return "Invalid user input provided"
        }
    }
}

// MARK: - Enums

enum ContextualTriggerType: String, CaseIterable, Codable {
    case highStress = "high_stress"
    case lowFocus = "low_focus"
    case longSession = "long_session"
    case workplacePattern = "workplace_pattern"
    case reflectionPrompt = "reflection_prompt"
    
    var displayName: String {
        switch self {
        case .highStress: return "High Stress Detection"
        case .lowFocus: return "Low Focus Detection"
        case .longSession: return "Long Session Alert"
        case .workplacePattern: return "Workplace Pattern"
        case .reflectionPrompt: return "Reflection Prompt"
        }
    }
}

enum InsightComplexity: String, CaseIterable, Codable, Sendable {
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

enum WorkIndustry: String, CaseIterable, Codable {
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

enum WorkRole: String, CaseIterable, Codable {
    case developer
    case designer
    case manager
    case executive
    case analyst
    case consultant
    case other
    
    var displayName: String {
        return rawValue.capitalized
    }
}

enum InteractionAction {
    case viewed
    case dismissed
    case actionTaken
}

enum InsightType: String, CaseIterable, Codable {
    case observation = "Observation"
    case question = "Question"
    case suggestion = "Suggestion"
    case affirmation = "Affirmation"
    case alert = "Alert" // For more critical patterns
    case prediction = "Prediction" // For forecasting insights
    case anomaly = "Anomaly" // For unusual pattern detection
    case warning = "Warning"
    case celebration = "Celebration"
    case trend = "Trend"
    case correlation = "Correlation"
    case goalProgress = "Goal Progress"
    case workplaceSpecific = "Workplace Specific"
}

// MARK: - Data Structures

struct ContextualTrigger: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let type: ContextualTriggerType
    let message: String
    let priority: Int // 1-10, higher is more important
    let cooldownHours: Double
    var lastTriggered: Date?

    init(
        id: UUID = UUID(),
        name: String,
        type: ContextualTriggerType,
        message: String,
        priority: Int = 5,
        cooldownHours: Double = 2.0,
        lastTriggered: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.message = message
        self.priority = max(1, min(10, priority)) // Clamp to valid range
        self.cooldownHours = max(0.5, cooldownHours) // Minimum 30 minutes
        self.lastTriggered = lastTriggered
    }
    
    var canTrigger: Bool {
        guard let lastTriggered = lastTriggered else { return true }
        let cooldownInterval = cooldownHours * 3600 // Convert to seconds
        return Date().timeIntervalSince(lastTriggered) >= cooldownInterval
    }
}

struct WorkplaceCheckInData: Codable, Sendable {
    let workplaceName: String?
    let sessionDuration: Int // in minutes
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
    
    // Convenience init from Core Data object
    init(fromMO checkIn: WorkplaceCheckIn) {
        self.workplaceName = (checkIn.workplace as? Workplace)?.name
        self.sessionDuration = Int(checkIn.duration ?? 0)
        self.stressLevel = checkIn.stressLevel
        self.focusLevel = checkIn.focusLevel
        self.timestamp = checkIn.timestamp
    }
}

struct UserPreference: Codable, Sendable {
    let id: UUID
    var insightType: InsightType
    var engagementScore: Double // 0.0 to 1.0
    var dismissalRate: Double // 0.0 to 1.0
    var actionRate: Double // 0.0 to 1.0
    var lastUpdated: Date
    var viewCount: Int
    var dismissalCount: Int
    var actionCount: Int

    init(
        id: UUID = UUID(),
        insightType: InsightType,
        engagementScore: Double = 0.5,
        dismissalRate: Double = 0.1,
        actionRate: Double = 0.3,
        lastUpdated: Date = Date(),
        viewCount: Int = 0,
        dismissalCount: Int = 0,
        actionCount: Int = 0
    ) {
        self.id = id
        self.insightType = insightType
        self.engagementScore = max(0.0, min(1.0, engagementScore))
        self.dismissalRate = max(0.0, min(1.0, dismissalRate))
        self.actionRate = max(0.0, min(1.0, actionRate))
        self.lastUpdated = lastUpdated
        self.viewCount = max(0, viewCount)
        self.dismissalCount = max(0, dismissalCount)
        self.actionCount = max(0, actionCount)
    }
    
    mutating func updateEngagement(dismissed: Bool, actionTaken: Bool) {
        let weight = 0.1 // Learning rate
        
        if dismissed {
            dismissalCount += 1
            dismissalRate = dismissalRate * (1 - weight) + weight
            engagementScore = max(0.0, engagementScore - weight * 0.5)
        } else {
            if actionTaken {
                actionCount += 1
                actionRate = actionRate * (1 - weight) + weight
                engagementScore = min(1.0, engagementScore + weight)
            }
        }
        
        viewCount += 1
        lastUpdated = Date()
    }
}

struct CulturalNorms: Codable, Sendable {
    let pace: String
    let hierarchy: String
    let communication: String
    let workLifeBalance: String

    init(pace: String, hierarchy: String, communication: String, workLifeBalance: String) {
        self.pace = pace
        self.hierarchy = hierarchy
        self.communication = communication
        self.workLifeBalance = workLifeBalance
    }
}

struct InsightData: Identifiable, Sendable, Codable {
    let id: UUID
    let type: InsightType
    var message: String
    var priority: Int
    var confidence: Double
    let timestamp: Date
    
    init(id: UUID = UUID(), type: InsightType, message: String, priority: Int = 5, confidence: Double = 0.8, timestamp: Date = Date()) {
        self.id = id
        self.type = type
        self.message = message
        self.priority = max(1, min(10, priority))
        self.confidence = max(0.0, min(1.0, confidence))
        self.timestamp = timestamp
    }
}

struct BreathingSessionData: Codable, Sendable {
    let id: UUID
    let timestamp: Date
    let duration: Int
    
    // Convenience init from Core Data object
    init(fromMO exercise: BreathingExercise) {
        self.id = exercise.id ?? UUID()
        self.timestamp = exercise.completedAt ?? Date()
        self.duration = Int(exercise.duration)
    }
}

struct WorkplaceJournalEntryData: Codable, Sendable {
    let id: UUID
    let timestamp: Date
    let content: String
    
    // Convenience init from Core Data object
    init(from entry: WorkplaceJournalEntry) {
        self.id = entry.id
        self.timestamp = entry.date
        self.content = entry.text
    }
}

struct UserGoal: Codable {
    let id: UUID
    let title: String
    let progress: Double
}
