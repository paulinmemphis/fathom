import Foundation
import CoreData
import UserNotifications
import Combine

// MARK: - Personalization Data Structures

enum ContextualTriggerType: String, CaseIterable, Codable {
    case highStress = "high_stress"
    case lowFocus = "low_focus"
    case longSession = "long_session"
    case workplacePattern = "workplace_pattern"
    case reflectionPrompt = "reflection_prompt"
}

struct ContextualTrigger: Codable, Identifiable {
    let id = UUID()
    let name: String
    let type: ContextualTriggerType
    let message: String
    let priority: Int // 1-10, higher is more important
    let cooldownHours: Double // How long to wait before triggering again
    var lastTriggered: Date?
    
    init(name: String, type: ContextualTriggerType, message: String, priority: Int = 5, cooldownHours: Double = 2.0) {
        self.name = name
        self.type = type
        self.message = message
        self.priority = priority
        self.cooldownHours = cooldownHours
        self.lastTriggered = nil
    }
    
    var canTrigger: Bool {
        guard let lastTriggered = lastTriggered else { return true }
        let cooldownInterval = cooldownHours * 3600 // Convert to seconds
        return Date().timeIntervalSince(lastTriggered) >= cooldownInterval
    }
}

struct NotificationContext: Codable {
    let workplaceName: String?
    let sessionDuration: Int // in minutes
    let stressLevel: Double?
    let focusLevel: Double?
    let timestamp: Date
    
    init(workplaceName: String? = nil, sessionDuration: Int = 0, stressLevel: Double? = nil, focusLevel: Double? = nil) {
        self.workplaceName = workplaceName
        self.sessionDuration = sessionDuration
        self.stressLevel = stressLevel
        self.focusLevel = focusLevel
        self.timestamp = Date()
    }
}

struct UserPreference: Codable {
    let id = UUID()
    var insightType: InsightType
    var engagementScore: Double // 0.0 to 1.0, based on user interactions
    var dismissalRate: Double // 0.0 to 1.0, how often user dismisses this type
    var actionTakenRate: Double // 0.0 to 1.0, how often user acts on insights
    var lastUpdated: Date
    
    init(insightType: InsightType) {
        self.insightType = insightType
        self.engagementScore = 0.5 // neutral starting point
        self.dismissalRate = 0.0
        self.actionTakenRate = 0.0
        self.lastUpdated = Date()
    }
    
    mutating func updateEngagement(dismissed: Bool, actionTaken: Bool) {
        let weight = 0.1 // Learning rate
        
        if dismissed {
            dismissalRate = dismissalRate * (1 - weight) + weight
            engagementScore = max(0.0, engagementScore - weight * 0.5)
        } else {
            dismissalRate = dismissalRate * (1 - weight)
            if actionTaken {
                actionTakenRate = actionTakenRate * (1 - weight) + weight
                engagementScore = min(1.0, engagementScore + weight)
            }
        }
        
        lastUpdated = Date()
    }
}

enum WorkRole: String, CaseIterable, Codable {
    case developer = "Developer"
    case designer = "Designer"
    case manager = "Manager"
    case analyst = "Analyst"
    case consultant = "Consultant"
    case researcher = "Researcher"
    case executive = "Executive"
    case support = "Support"
    case sales = "Sales"
    case marketing = "Marketing"
    case other = "Other"
    
    var typicalStressors: [String] {
        switch self {
        case .developer:
            return ["debugging", "deadlines", "code complexity", "technical debt"]
        case .designer:
            return ["creative blocks", "feedback loops", "visual perfectionism", "client revisions"]
        case .manager:
            return ["team conflicts", "resource allocation", "meeting overload", "decision fatigue"]
        case .analyst:
            return ["data accuracy", "complex analysis", "reporting deadlines", "stakeholder expectations"]
        case .consultant:
            return ["client management", "travel fatigue", "knowledge gaps", "project scope creep"]
        case .researcher:
            return ["literature reviews", "experiment failures", "publication pressure", "funding concerns"]
        case .executive:
            return ["strategic decisions", "board meetings", "market pressure", "leadership burden"]
        case .support:
            return ["customer frustration", "issue resolution", "knowledge gaps", "escalation pressure"]
        case .sales:
            return ["quota pressure", "client rejection", "pipeline management", "competition"]
        case .marketing:
            return ["campaign performance", "brand consistency", "creative approval", "ROI pressure"]
        case .other:
            return ["workload", "deadlines", "communication", "priorities"]
        }
    }
    
    var focusPatterns: [String] {
        switch self {
        case .developer:
            return ["deep work blocks", "minimal interruptions", "morning focus", "flow state"]
        case .designer:
            return ["creative sprints", "inspiration breaks", "visual exploration", "iterative refinement"]
        case .manager:
            return ["time blocking", "communication windows", "strategic thinking", "team alignment"]
        case .analyst:
            return ["data deep dives", "analytical blocks", "visualization time", "validation periods"]
        case .consultant:
            return ["client prep", "knowledge synthesis", "presentation building", "solution crafting"]
        case .researcher:
            return ["literature blocks", "experiment design", "data analysis", "writing sessions"]
        case .executive:
            return ["strategic blocks", "decision windows", "stakeholder alignment", "vision crafting"]
        case .support:
            return ["ticket batching", "knowledge updates", "escalation handling", "process improvement"]
        case .sales:
            return ["prospect research", "call preparation", "relationship building", "deal progression"]
        case .marketing:
            return ["campaign planning", "content creation", "performance analysis", "creative development"]
        case .other:
            return ["task batching", "priority setting", "communication blocks", "skill development"]
        }
    }
}

enum WorkIndustry: String, CaseIterable, Codable {
    case technology = "Technology"
    case healthcare = "Healthcare"
    case finance = "Finance"
    case education = "Education"
    case consulting = "Consulting"
    case retail = "Retail"
    case manufacturing = "Manufacturing"
    case media = "Media"
    case government = "Government"
    case nonprofit = "Nonprofit"
    case other = "Other"
    
    var culturalNorms: [String: Any] {
        switch self {
        case .technology:
            return ["pace": "fast", "hierarchy": "flat", "communication": "informal", "innovation": "high"]
        case .healthcare:
            return ["pace": "urgent", "hierarchy": "structured", "communication": "precise", "compliance": "strict"]
        case .finance:
            return ["pace": "intense", "hierarchy": "formal", "communication": "formal", "risk": "managed"]
        case .education:
            return ["pace": "cyclical", "hierarchy": "traditional", "communication": "collaborative", "purpose": "mission-driven"]
        case .consulting:
            return ["pace": "variable", "hierarchy": "project-based", "communication": "client-focused", "expertise": "specialized"]
        case .retail:
            return ["pace": "seasonal", "hierarchy": "operational", "communication": "customer-centric", "metrics": "performance-driven"]
        case .manufacturing:
            return ["pace": "steady", "hierarchy": "structured", "communication": "process-focused", "efficiency": "optimized"]
        case .media:
            return ["pace": "deadline-driven", "hierarchy": "creative", "communication": "storytelling", "trends": "trend-aware"]
        case .government:
            return ["pace": "methodical", "hierarchy": "formal", "communication": "regulatory", "transparency": "required"]
        case .nonprofit:
            return ["pace": "mission-driven", "hierarchy": "collaborative", "communication": "impact-focused", "resources": "constrained"]
        case .other:
            return ["pace": "variable", "hierarchy": "mixed", "communication": "adaptive", "culture": "diverse"]
        }
    }
}

enum InsightComplexity: Int, CaseIterable {
    case basic = 1      // Simple observations
    case intermediate = 2   // Pattern recognition
    case advanced = 3       // Predictive insights
    case expert = 4         // Complex correlations and recommendations
    
    var description: String {
        switch self {
        case .basic: return "Basic observations about your work patterns"
        case .intermediate: return "Pattern recognition and trend analysis"
        case .advanced: return "Predictive insights and forecasting"
        case .expert: return "Advanced correlations and strategic recommendations"
        }
    }
}

// MARK: - Personalization Engine

@MainActor
class PersonalizationEngine: ObservableObject {
    static let shared = PersonalizationEngine()
    
    @Published var userPreferences: [InsightType: UserPreference] = [:]
    @Published var userRole: WorkRole = .other
    @Published var userIndustry: WorkIndustry = .other
    @Published var insightComplexity: InsightComplexity = .basic
    @Published var contextualTriggers: [ContextualTrigger] = []
    
    private let userDefaults = UserDefaults.standard
    private let preferencesKey = "PersonalizationPreferences"
    private let roleKey = "UserWorkRole"
    private let industryKey = "UserIndustry"
    private let complexityKey = "InsightComplexity"
    
    private init() {
        loadUserPreferences()
        setupDefaultTriggers()
        updateComplexityBasedOnUsage()
    }
    
    // MARK: - Preference Learning
    
    func recordInteraction(insightType: InsightType, dismissed: Bool, actionTaken: Bool) {
        if userPreferences[insightType] == nil {
            userPreferences[insightType] = UserPreference(insightType: insightType)
        }
        
        userPreferences[insightType]?.updateEngagement(dismissed: dismissed, actionTaken: actionTaken)
        saveUserPreferences()
        
        // Adapt complexity based on engagement
        updateComplexityBasedOnUsage()
    }
    
    func getPreferenceScore(for insightType: InsightType) -> Double {
        return userPreferences[insightType]?.engagementScore ?? 0.5
    }
    
    // MARK: - Industry/Role Adaptation
    
    func setUserProfile(role: WorkRole, industry: WorkIndustry) {
        userRole = role
        userIndustry = industry
        
        userDefaults.set(role.rawValue, forKey: roleKey)
        userDefaults.set(industry.rawValue, forKey: industryKey)
        
        updateContextualTriggersForProfile()
    }
    
    func adaptInsightForProfile(_ insight: Insight) -> Insight {
        var adaptedInsight = insight
        
        // Customize message based on role-specific language and concerns
        if insight.message.contains("stress") {
            let roleStressors = userRole.typicalStressors
            if !roleStressors.isEmpty {
                let relevantStressor = roleStressors.randomElement() ?? "work pressure"
                adaptedInsight.message = adaptedInsight.message.replacingOccurrences(
                    of: "stress",
                    with: "\(relevantStressor) stress"
                )
            }
        }
        
        // Adjust priority based on industry culture
        let culturalNorms = userIndustry.culturalNorms
        if let pace = culturalNorms["pace"] as? String {
            switch pace {
            case "fast", "intense", "urgent":
                adaptedInsight.priority = min(10, adaptedInsight.priority + 1)
            case "methodical", "steady":
                adaptedInsight.priority = max(1, adaptedInsight.priority - 1)
            default:
                break
            }
        }
        
        return adaptedInsight
    }
    
    // MARK: - Progressive Insights
    
    private func updateComplexityBasedOnUsage() {
        let totalEngagement = userPreferences.values.map { $0.engagementScore }.reduce(0, +)
        let averageEngagement = totalEngagement / Double(max(1, userPreferences.count))
        let totalInteractions = userPreferences.count
        
        let newComplexity: InsightComplexity
        
        if totalInteractions < 10 || averageEngagement < 0.3 {
            newComplexity = .basic
        } else if totalInteractions < 25 || averageEngagement < 0.6 {
            newComplexity = .intermediate
        } else if totalInteractions < 50 || averageEngagement < 0.8 {
            newComplexity = .advanced
        } else {
            newComplexity = .expert
        }
        
        if newComplexity != insightComplexity {
            insightComplexity = newComplexity
            userDefaults.set(newComplexity.rawValue, forKey: complexityKey)
        }
    }
    
    func filterInsightsByComplexity(_ insights: [Insight]) -> [Insight] {
        return insights.filter { insight in
            switch insightComplexity {
            case .basic:
                return insight.type == .observation || insight.type == .affirmation
            case .intermediate:
                return insight.type != .prediction && insight.confidence >= 0.6
            case .advanced:
                return insight.confidence >= 0.4
            case .expert:
                return true // Show all insights at expert level
            }
        }
    }
    
    // MARK: - Contextual Triggers
    
    private func setupDefaultTriggers() {
        contextualTriggers = [
            ContextualTrigger(
                name: "High Stress Detection",
                type: .highStress,
                message: "You've been experiencing high stress. Consider taking a breathing break.",
                priority: 8,
                cooldownHours: 2.0
            ),
            ContextualTrigger(
                name: "Low Focus Pattern",
                type: .lowFocus,
                message: "Your focus seems low today. Try a 5-minute mindfulness exercise.",
                priority: 6,
                cooldownHours: 4.0
            ),
            ContextualTrigger(
                name: "Long Work Session",
                type: .longSession,
                message: "You've been working for over 4 hours. Time for a meaningful break!",
                priority: 7,
                cooldownHours: 6.0
            )
        ]
    }
    
    private func updateContextualTriggersForProfile() {
        // Add role-specific triggers
        switch userRole {
        case .developer:
            addTriggerIfNeeded(ContextualTrigger(
                name: "Code Review Break",
                type: .workplacePattern,
                message: "Debugging can be mentally taxing. Take a step back to gain fresh perspective.",
                priority: 6,
                cooldownHours: 3.0
            ))
        case .manager:
            addTriggerIfNeeded(ContextualTrigger(
                name: "Meeting Overload",
                type: .workplacePattern,
                message: "Multiple meetings can be draining. Schedule some focus time for yourself.",
                priority: 7,
                cooldownHours: 4.0
            ))
        case .designer:
            addTriggerIfNeeded(ContextualTrigger(
                name: "Creative Block",
                type: .workplacePattern,
                message: "Creative blocks are normal. Try changing your environment or taking a walk.",
                priority: 5,
                cooldownHours: 2.0
            ))
        default:
            break
        }
    }
    
    private func addTriggerIfNeeded(_ trigger: ContextualTrigger) {
        if !contextualTriggers.contains(where: { $0.name == trigger.name }) {
            contextualTriggers.append(trigger)
        }
    }
    
    func evaluateContextualTriggers(for checkIn: WorkplaceCheckIn) -> [ContextualTrigger] {
        return contextualTriggers.filter { trigger in
            trigger.canTrigger && trigger.type == .highStress ? Double(checkIn.stressRating) >= 4.0 : trigger.type == .lowFocus ? Double(checkIn.focusRating) <= 2.0 : trigger.type == .longSession ? (checkIn.checkOutTime?.timeIntervalSince(checkIn.checkInTime ?? Date()) ?? 0) > 4 * 3600 : false
        }
    }
    
    func markTriggerUsed(_ trigger: ContextualTrigger) {
        if let index = contextualTriggers.firstIndex(where: { $0.id == trigger.id }) {
            contextualTriggers[index].lastTriggered = Date()
        }
    }
    
    // MARK: - Persistence
    
    private func saveUserPreferences() {
        do {
            let data = try JSONEncoder().encode(userPreferences)
            userDefaults.set(data, forKey: preferencesKey)
        } catch {
            print("Failed to save user preferences: \(error)")
        }
    }
    
    private func loadUserPreferences() {
        // Load preferences
        if let data = userDefaults.data(forKey: preferencesKey),
           let preferences = try? JSONDecoder().decode([InsightType: UserPreference].self, from: data) {
            userPreferences = preferences
        }
        
        // Load role and industry
        if let roleString = userDefaults.string(forKey: roleKey),
           let role = WorkRole(rawValue: roleString) {
            userRole = role
        }
        
        if let industryString = userDefaults.string(forKey: industryKey),
           let industry = WorkIndustry(rawValue: industryString) {
            userIndustry = industry
        }
        
        // Load complexity
        let complexityValue = userDefaults.integer(forKey: complexityKey)
        if let complexity = InsightComplexity(rawValue: complexityValue) {
            insightComplexity = complexity
        }
    }
}

// MARK: - Personalization Extensions for InsightEngine

extension InsightEngine {
    
    func generatePersonalizedInsights(
        checkIns: [WorkplaceCheckIn],
        breathingLogs: [BreathingExercise] = [],
        journalEntries: [WorkplaceJournalEntry] = [],
        goals: [UserGoal] = [],
        forLastDays days: Int = 7,
        referenceDate: Date = Date()
    ) -> [Insight] {
        
        let personalization = PersonalizationEngine.shared
        
        // Generate base insights
        var insights = generateInsights(
            checkIns: checkIns,
            breathingLogs: breathingLogs,
            journalEntries: journalEntries,
            goals: goals,
            forLastDays: days,
            referenceDate: referenceDate
        )
        
        // Apply personalization filters and adaptations
        insights = insights.map { personalization.adaptInsightForProfile($0) }
        insights = personalization.filterInsightsByComplexity(insights)
        
        // Rank insights by user preferences
        insights = insights.sorted { insight1, insight2 in
            let score1 = personalization.getPreferenceScore(for: insight1.type)
            let score2 = personalization.getPreferenceScore(for: insight2.type)
            
            if score1 != score2 {
                return score1 > score2
            }
            return insight1.priority > insight2.priority
        }
        
        // Evaluate contextual triggers
        if let latestCheckIn = checkIns.last {
            let triggers = personalization.evaluateContextualTriggers(for: latestCheckIn)
            
            // Convert triggers to insights
            let triggerInsights = triggers.map { trigger in
                Insight(
                    message: trigger.message,
                    type: .alert,
                    priority: trigger.priority,
                    confidence: 1.0
                )
            }
            
            // Mark triggers as used
            triggers.forEach { personalization.markTriggerUsed($0) }
            
            // Add trigger insights to the beginning
            insights = triggerInsights + insights
        }
        
        return insights
    }
}
