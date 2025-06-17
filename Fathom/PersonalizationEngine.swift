import Foundation
import UserNotifications
import Combine

// MARK: - Type Aliases

typealias UserPreferencesDictionary = [InsightType: UserPreference]

// MARK: - Personalization Data Structures

enum ContextualTriggerType: String, CaseIterable, Codable {
    case highStress = "high_stress"
    case lowFocus = "low_focus"
    case longSession = "long_session"
    case workplacePattern = "workplace_pattern"
    case reflectionPrompt = "reflection_prompt"
}

struct ContextualTrigger: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let type: ContextualTriggerType
    let message: String
    let priority: Int // 1-10, higher is more important
    let cooldownHours: Double // How long to wait before triggering again
    var lastTriggered: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, name, type, message, priority, cooldownHours, lastTriggered
    }
    
    init(id: UUID = UUID(), name: String, type: ContextualTriggerType, message: String, 
         priority: Int = 5, cooldownHours: Double = 2.0, lastTriggered: Date? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.message = message
        self.priority = priority
        self.cooldownHours = cooldownHours
        self.lastTriggered = lastTriggered
    }
    
    var canTrigger: Bool {
        guard let lastTriggered = lastTriggered else { return true }
        let cooldownInterval = cooldownHours * 3600 // Convert to seconds
        return Date().timeIntervalSince(lastTriggered) >= cooldownInterval
    }
}

struct NotificationContext: Codable, Sendable {
    let workplaceName: String?
    let sessionDuration: Int // in minutes
    let stressLevel: Double?
    let focusLevel: Double?
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case workplaceName, sessionDuration, stressLevel, focusLevel, timestamp
    }
    
    init(workplaceName: String? = nil, sessionDuration: Int = 0, 
         stressLevel: Double? = nil, focusLevel: Double? = nil, timestamp: Date = Date()) {
        self.workplaceName = workplaceName
        self.sessionDuration = sessionDuration
        self.stressLevel = stressLevel
        self.focusLevel = focusLevel
        self.timestamp = timestamp
    }
}

struct UserPreference: Codable, Sendable {
    let id: UUID
    var insightType: InsightType
    var engagementScore: Double // 0.0 to 1.0, based on user interactions
    var dismissalRate: Double // 0.0 to 1.0, how often user dismisses this type
    var actionRate: Double // 0.0 to 1.0, how often user takes action
    var lastUpdated: Date
    var viewCount: Int
    var dismissalCount: Int
    var actionCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id, insightType, engagementScore, dismissalRate, actionRate, lastUpdated, viewCount, dismissalCount, actionCount
    }
    
    init(id: UUID = UUID(), insightType: InsightType, engagementScore: Double = 0.5, 
         dismissalRate: Double = 0.1, actionRate: Double = 0.3, lastUpdated: Date = Date(), viewCount: Int = 0, dismissalCount: Int = 0, actionCount: Int = 0) {
        self.id = id
        self.insightType = insightType
        self.engagementScore = engagementScore
        self.dismissalRate = dismissalRate
        self.actionRate = actionRate
        self.lastUpdated = lastUpdated
        self.viewCount = viewCount
        self.dismissalCount = dismissalCount
        self.actionCount = actionCount
    }
    
    mutating func updateEngagement(dismissed: Bool, actionTaken: Bool) {
        let weight = 0.1 // Learning rate
        
        if dismissed {
            dismissalRate = dismissalRate * (1 - weight) + weight
            engagementScore = max(0.0, engagementScore - weight * 0.5)
        } else {
            dismissalRate = dismissalRate * (1 - weight)
            if actionTaken {
                actionRate = actionRate * (1 - weight) + weight
                engagementScore = min(1.0, engagementScore + weight)
            }
        }
        
        lastUpdated = Date()
    }
}

enum WorkRole: String, CaseIterable, Codable, Sendable {
    case developer = "Developer"
    case designer = "Designer"
    case manager = "Manager"
    case analyst = "Analyst"
    case consultant = "Consultant"
    case educator = "Educator"
    case healthcare = "Healthcare Professional"
    case executive = "Executive"
    case other = "Other"
    
    var description: String {
        return rawValue
    }
    
    var suggestedInsightTypes: [InsightType] {
        switch self {
        case .developer:
            return [.trend, .correlation, .prediction]
        case .designer:
            return [.trend, .workplaceSpecific, .goalProgress]
        case .manager:
            return [.workplaceSpecific, .goalProgress, .prediction]
        case .analyst:
            return [.correlation, .anomaly, .prediction]
        case .consultant:
            return [.workplaceSpecific, .trend, .goalProgress]
        case .educator:
            return [.goalProgress, .affirmation, .suggestion]
        case .healthcare:
            return [.affirmation, .suggestion, .alert]
        case .executive:
            return [.prediction, .workplaceSpecific, .trend]
        case .other:
            return [.suggestion, .affirmation, .goalProgress]
        }
    }
}

enum WorkIndustry: String, CaseIterable, Codable, Sendable {
    case technology = "Technology"
    case healthcare = "Healthcare"
    case finance = "Finance"
    case education = "Education"
    case retail = "Retail"
    case manufacturing = "Manufacturing"
    case consulting = "Consulting"
    case media = "Media"
    case government = "Government"
    case nonprofit = "Nonprofit"
    case other = "Other"
    
    struct CulturalNorms: Codable {
        let pace: String
        let hierarchy: String
        let communication: String
        let workLifeBalance: String
    }
    
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

enum InsightComplexity: String, CaseIterable, Codable, Sendable {
    case basic = "Basic"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    
    var intValue: Int {
        switch self {
        case .basic:
            return 1
        case .intermediate:
            return 2
        case .advanced:
            return 3
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

// MARK: - Personalization Engine

actor PersonalizationEngine: ObservableObject, Sendable {
    static let shared = PersonalizationEngine()
    
    @Published private(set) var userRole: WorkRole = .other
    @Published private(set) var userIndustry: WorkIndustry = .other
    @Published private(set) var insightComplexity: InsightComplexity = .basic
    
    private var userPreferences: UserPreferencesDictionary = [:]
    private var contextualTriggers: [ContextualTrigger] = []
    
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    
    private let notificationCenter: UNUserNotificationCenter
    
    private init() {
        notificationCenter = UNUserNotificationCenter.current()
        // NOTE: You must call await PersonalizationEngine.shared.initialize() after creation to complete setup.
        // Do NOT call actor-isolated methods here.
    }

    /// Call this after creation to complete async setup
    func initialize() async {
        await loadUserPreferences()
        await setupDefaultTriggers()
        await updateComplexityBasedOnUsage()
        
        // Set up the NotificationCenter publisher here where we can safely access actor properties
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [actor = self] _ in
                Task {
                    await actor.loadUserPreferences()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Interface
    
    func updateUserRole(_ role: WorkRole) {
        userRole = role
        userDefaults.set(role.rawValue, forKey: "userRole")
        updateContextualTriggersForProfile()
    }
    
    func updateUserIndustry(_ industry: WorkIndustry) {
        userIndustry = industry
        userDefaults.set(industry.rawValue, forKey: "userIndustry")
        updateContextualTriggersForProfile()
    }
    
    func updateInsightComplexity(_ complexity: InsightComplexity) {
        insightComplexity = complexity
        userDefaults.set(complexity.rawValue, forKey: "insightComplexity")
    }
    
    // MARK: - Preference Learning
    
    func recordInsightEngagement(_ type: InsightType, wasDismissed: Bool, actionTaken: Bool) {
        var preference = userPreferences[type] ?? UserPreference(insightType: type)
        preference.updateEngagement(dismissed: wasDismissed, actionTaken: actionTaken)
        userPreferences[type] = preference
        saveUserPreferences()
    }
    
    func getEngagementScore(for type: InsightType) -> Double {
        return userPreferences[type]?.engagementScore ?? 0.5
    }
    
    func getInsightPriority(_ type: InsightType) -> Double {
        // Base priority on engagement score and complexity level
        let baseScore = getEngagementScore(for: type)
        let complexityMultiplier: Double
        
        switch insightComplexity {
        case .basic:
            complexityMultiplier = 1.0
        case .intermediate:
            complexityMultiplier = 1.2
        case .advanced:
            complexityMultiplier = 1.5
        }
        
        return baseScore * complexityMultiplier
    }
    
    func recordInteraction(for insightType: InsightType, action: InteractionAction) async {
        var preference = userPreferences[insightType] ?? UserPreference(insightType: insightType)
        
        switch action {
        case .viewed:
            preference.viewCount += 1
        case .dismissed:
            preference.dismissalCount += 1
        case .actionTaken:
            preference.actionCount += 1
            preference.engagementScore = min(1.0, preference.engagementScore + 0.1)
        }
        
        // Update engagement score based on interaction patterns
        let totalInteractions = preference.viewCount + preference.dismissalCount + preference.actionCount
        if totalInteractions > 0 {
            let positiveRatio = Double(preference.actionCount) / Double(totalInteractions)
            let dismissalPenalty = Double(preference.dismissalCount) / Double(totalInteractions) * 0.3
            preference.engagementScore = max(0.0, min(1.0, positiveRatio - dismissalPenalty))
        }
        
        userPreferences[insightType] = preference
        saveUserPreferences()
    }
    
    func getContextualTriggers() -> [ContextualTrigger] {
        return contextualTriggers
    }
    
    enum InteractionAction {
        case viewed
        case dismissed
        case actionTaken
    }
    
    // MARK: - Insight Adaptation and Filtering
    
    func filterInsightsByComplexity(_ insights: [Insight]) -> [Insight] {
        let userMaxComplexity = insightComplexity
        return insights.filter { insight in
            let insightComplexity = complexityForInsightType(insight.type)
            switch userMaxComplexity {
            case .basic:
                return insightComplexity == .basic
            case .intermediate:
                return insightComplexity == .basic || insightComplexity == .intermediate
            case .advanced:
                return true
            }
        }
    }
    
    private func complexityForInsightType(_ type: InsightType) -> InsightComplexity {
        // Map insight types to complexity levels
        switch type {
        case .trend:
            return .basic
        case .workplaceSpecific, .goalProgress, .correlation:
            return .intermediate
        case .anomaly, .prediction:
            return .advanced
        case .alert, .suggestion, .affirmation:
            return .basic
        case .observation, .question:
            return .basic
        case .warning, .celebration:
            return .basic
        }
    }
    
    // MARK: - Insight Adaptation
    
    private func adaptInsightForProfile(_ insight: Insight) -> Insight {
        var adaptedInsight = insight
        
        // Adjust message based on user's role and industry
        adaptedInsight.message = insight.message
        
        // Adjust priority based on user preferences
        if let preference = userPreferences[insight.type] {
            // Increase priority for insights the user engages with
            if preference.engagementScore > 0.7 {
                adaptedInsight.priority += 1
            }
            // Decrease priority for insights the user often dismisses
            else if preference.dismissalRate > 0.5 {
                adaptedInsight.priority = max(1, adaptedInsight.priority - 1)
            }
            
            // Adjust confidence based on action rate
            adaptedInsight.confidence = min(1.0, adaptedInsight.confidence * (0.8 + (preference.actionRate * 0.2)))
        }
        
        // Apply role-specific adaptations
        switch userRole {
        case .manager:
            adaptedInsight.message = adaptedInsight.message.replacingOccurrences(of: "you", with: "your team")
        case .executive:
            // Add more strategic language for executives
            if !adaptedInsight.message.contains("strategic") {
                adaptedInsight.message = "From a strategic perspective: " + adaptedInsight.message
            }
        default:
            break
        }
        
        return adaptedInsight
    }
    
    // MARK: - Industry/Role Adaptation
    
    func setUserProfile(role: WorkRole, industry: WorkIndustry) {
        userRole = role
        userIndustry = industry
        
        userDefaults.set(role.rawValue, forKey: "userRole")
        userDefaults.set(industry.rawValue, forKey: "userIndustry")
        
        updateContextualTriggersForProfile()
    }
    
    func setInsightComplexity(_ complexity: InsightComplexity) {
        insightComplexity = complexity
        userDefaults.set(complexity.rawValue, forKey: "insightComplexity")
    }
    
    func savePreferences() {
        saveUserPreferences()
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
    
    // MARK: - Progressive Insights
    
    private func updateComplexityBasedOnUsage() {
        let totalInteractions = userPreferences.values.reduce(0) { $0 + Int($1.engagementScore * 100) }
        
        if totalInteractions > 500 {
            insightComplexity = .advanced
        } else if totalInteractions > 200 {
            insightComplexity = .intermediate
        } else {
            insightComplexity = .basic
        }
        
        userDefaults.set(insightComplexity.rawValue, forKey: "insightComplexity")
    }
    
    // MARK: - Persistence
    
    private func saveUserPreferences() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(userPreferences)
            userDefaults.set(data, forKey: "userPreferences")
            userDefaults.set(userRole.rawValue, forKey: "userRole")
            userDefaults.set(userIndustry.rawValue, forKey: "userIndustry")
            userDefaults.set(insightComplexity.rawValue, forKey: "insightComplexity")
        } catch {
            print("Failed to save user preferences: \(error)")
        }
    }
    
    private func loadUserPreferences() async {
        // Load preferences
        if let data = userDefaults.data(forKey: "userPreferences") {
            do {
                userPreferences = try JSONDecoder().decode(UserPreferencesDictionary.self, from: data)
            } catch {
                print("Failed to load user preferences: \(error)")
                userPreferences = [:]
            }
        }
        
        // Load complexity setting
        if let complexityRaw = userDefaults.object(forKey: "insightComplexity") as? String {
            insightComplexity = InsightComplexity(rawValue: complexityRaw) ?? .basic
        }
        
        // Load other settings
        userRole = WorkRole(rawValue: userDefaults.string(forKey: "userRole") ?? "") ?? .other
        userIndustry = WorkIndustry(rawValue: userDefaults.string(forKey: "userIndustry") ?? "") ?? .other
    }
    
    // MARK: - Contextual Triggers
    
    func evaluateContextualTriggers(for checkIn: WorkplaceCheckIn) -> [ContextualTrigger] {
        var activeTriggers: [ContextualTrigger] = []
        
        // Check each trigger to see if it should be activated
        for trigger in contextualTriggers {
            if shouldTrigger(trigger, for: checkIn) {
                activeTriggers.append(trigger)
            }
        }
        
        // Sort by priority (highest first)
        return activeTriggers.sorted { $0.priority > $1.priority }
    }
    
    private func shouldTrigger(_ trigger: ContextualTrigger, for checkIn: WorkplaceCheckIn) -> Bool {
        // Check cooldown
        guard trigger.canTrigger else { return false }
        
        switch trigger.type {
        case .highStress:
            // Trigger if stress level is above threshold
            return checkIn.stressLevel > 0.7
            
        case .lowFocus:
            // Trigger if focus level is below threshold
            return checkIn.focusLevel < 0.4
            
        case .longSession:
            // Trigger if session duration is long
            return checkIn.sessionDuration > 120 // 2 hours
            
        case .workplacePattern:
            // Check for specific workplace patterns
            return checkWorkplacePatterns(for: checkIn)
            
        case .reflectionPrompt:
            // Random chance for reflection prompt, but not too often
            return Int.random(in: 1...100) <= 10 // 10% chance
        }
    }
    
    private func checkWorkplacePatterns(for checkIn: WorkplaceCheckIn) -> Bool {
        // Implement specific workplace pattern checks
        // This is a simplified example - you'd want to make this more sophisticated
        
        // Example: Check if this is a common time for high stress
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: checkIn.timestamp)
        
        // If it's late afternoon (3-5pm) and stress is increasing
        if (15...17).contains(hour) {
            return checkIn.stressLevel > 0.6
        }
        
        return false
    }
    
    func markTriggerUsed(_ trigger: ContextualTrigger) {
        if let index = contextualTriggers.firstIndex(where: { $0.id == trigger.id }) {
            var updatedTrigger = contextualTriggers[index]
            updatedTrigger.lastTriggered = Date()
            contextualTriggers[index] = updatedTrigger
        }
    }
    
    // MARK: - Insight Generation
    
    /// Generates personalized insights based on user data and preferences
    /// - Parameters:
    ///   - checkIns: Array of workplace check-ins
    ///   - breathingLogs: Array of breathing exercise logs (optional)
    ///   - journalEntries: Array of journal entries (optional)
    ///   - goals: Array of user goals (optional)
    ///   - days: Number of days to look back for insights (default: 7)
    ///   - referenceDate: Reference date for time-based calculations (default: current date)
    /// - Returns: Array of personalized insights
    func generatePersonalizedInsights(
        checkIns: [WorkplaceCheckIn],
        breathingLogs: [BreathingExercise] = [],
        journalEntries: [WorkplaceJournalEntry] = [],
        goals: [UserGoal] = [],
        forLastDays days: Int = 7,
        referenceDate: Date = Date()
    ) async -> [Insight] {
        // Map Core Data objects to Sendable structs to safely pass across actor boundaries
        let checkInData = checkIns.map { CheckInData(from: $0) } // This now includes sessionNote
        let breathingData = breathingLogs.map { BreathingData(from: $0) }

        // Generate base insights from InsightEngine
        var insights = await InsightEngine.shared.generateInsights(
            checkIns: checkInData,
            breathingLogs: breathingData,
            journalEntries: journalEntries,
            goals: goals,
            forLastDays: days,
            referenceDate: referenceDate
        )
        // Apply personalization
        insights = filterInsightsByComplexity(insights)
        insights = insights.map { adaptInsightForProfile($0) }
        
        // Sort by priority and engagement
        insights.sort { lhs, rhs in
            let lhsEngagement = userPreferences[lhs.type]?.engagementScore ?? 0.5
            let rhsEngagement = userPreferences[rhs.type]?.engagementScore ?? 0.5
            
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            return lhsEngagement > rhsEngagement
        }
        
        return insights
    }
    
    // MARK: - Main Actor Access Properties
    
    func getCurrentInsightComplexity() async -> InsightComplexity {
        return insightComplexity
    }
    
    func getCurrentUserRole() async -> WorkRole {
        return userRole
    }
    
    func getCurrentUserIndustry() async -> WorkIndustry {
        return userIndustry
    }
}
