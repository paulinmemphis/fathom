import Foundation
import SwiftUI
import UserNotifications
@preconcurrency import Combine
import CoreData
import os



@available(iOS 14.0, *)
@MainActor
final class PersonalizationEngine: ObservableObject {
    static let shared = PersonalizationEngine()
    
    // MARK: - Published Properties
    @Published private(set) var userRole: WorkRole = .other
    @Published private(set) var userIndustry: WorkIndustry = .other
    @Published private(set) var insightComplexity: InsightComplexity = .basic
    @Published private(set) var isInitialized = false
    
    // MARK: - Private Properties
    private var userPreferences: UserPreferencesDictionary = [:]
    private var contextualTriggers: [ContextualTrigger] = []
    private var pendingPreferenceUpdates: [InsightType: UserPreference] = [:]
    
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    private let notificationCenter: UNUserNotificationCenter
    private let logger = Logger(subsystem: "PersonalizationEngine", category: "main")
    
    // MARK: - Constants
    private enum Keys {
        static let userPreferences = "PersonalizationEngine.userPreferences"
        static let userRole = "PersonalizationEngine.userRole"
        static let userIndustry = "PersonalizationEngine.userIndustry"
        static let insightComplexity = "PersonalizationEngine.insightComplexity"
        static let contextualTriggers = "PersonalizationEngine.contextualTriggers"
    }
    
    private init() {
        notificationCenter = UNUserNotificationCenter.current()
    }

    // MARK: - Initialization
    
    @MainActor func initialize() async throws {
        guard !isInitialized else { return }
        
        await loadUserPreferences()
        await setupDefaultTriggersIfNeeded()
        await updateComplexityBasedOnUsage()
        setupNotificationObserver()
        setupPersistenceTimer()
        isInitialized = true
        logger.info("PersonalizationEngine initialized successfully")
    }
    
    @MainActor private func setupNotificationObserver() {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor [weak self] in
                    guard let self = self, self.isInitialized else { return }
                    await self.loadUserPreferences()
                }
            }
            .store(in: &cancellables)
    }
    
    @MainActor private func setupPersistenceTimer() {
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor [weak self] in
                    await self?.flushPendingUpdates()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Interface
    
    func getUserRole() -> WorkRole {
        return userRole
    }
    
    func getUserIndustry() -> WorkIndustry {
        return userIndustry
    }
    
    func getInsightComplexity() -> InsightComplexity {
        return insightComplexity
    }
    
    @MainActor func setUserProfile(role: WorkRole, industry: WorkIndustry) throws {
        guard isInitialized else {
            throw PersonalizationError.initializationFailure
        }
        
        userRole = role
        userIndustry = industry
        userDefaults.set(role.rawValue, forKey: Keys.userRole)
        userDefaults.set(industry.rawValue, forKey: Keys.userIndustry)
        
        Task {
            await updateContextualTriggersForProfile()
        }
        
        logger.info("User profile updated: role=\(role.rawValue), industry=\(industry.rawValue)")
    }
    
    @MainActor func setInsightComplexity(_ complexity: InsightComplexity) throws {
        guard isInitialized else {
            throw PersonalizationError.initializationFailure
        }
        
        guard complexity != insightComplexity else { return }
        
        insightComplexity = complexity
        userDefaults.set(complexity.rawValue, forKey: Keys.insightComplexity)
        
        logger.info("Insight complexity updated to: \(complexity.rawValue)")
    }
    
    // MARK: - Preference Learning
    
    @MainActor func recordInsightEngagement(_ type: InsightType, wasDismissed: Bool, actionTaken: Bool) throws {
        guard isInitialized else {
            throw PersonalizationError.initializationFailure
        }
        
        var preference = userPreferences[type] ?? UserPreference(insightType: type)
        preference.updateEngagement(dismissed: wasDismissed, actionTaken: actionTaken)
        
        // Store in pending updates for batched persistence
        pendingPreferenceUpdates[type] = preference
        userPreferences[type] = preference
        
        logger.debug("Recorded engagement for \(type.rawValue): dismissed=\(wasDismissed), action=\(actionTaken)")
    }
    
    @MainActor func recordInteraction(for insightType: InsightType, action: InteractionAction) throws {
        guard isInitialized else {
            throw PersonalizationError.initializationFailure
        }
        
        var preference = userPreferences[insightType] ?? UserPreference(insightType: insightType)
        
        switch action {
        case .viewed:
            preference.viewCount += 1
        case .dismissed:
            preference.dismissalCount += 1
            preference.engagementScore = max(0.0, preference.engagementScore - 0.05)
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
        
        preference.lastUpdated = Date()
        pendingPreferenceUpdates[insightType] = preference
        userPreferences[insightType] = preference
    }
    
    func getEngagementScore(for type: InsightType) -> Double {
        return userPreferences[type]?.engagementScore ?? 0.5
    }
    
    func getInsightPriority(_ type: InsightType) -> Double {
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
    
    // MARK: - Insight Adaptation and Filtering

    func filterInsightsByComplexity(_ insights: [InsightData]) -> [InsightData] {
        let userMaxComplexity = insightComplexity
        return insights.filter { insight in
            let complexity = complexityForInsightType(insight.type)
            switch userMaxComplexity {
            case .basic:
                return complexity == .basic
            case .intermediate:
                return complexity == .basic || complexity == .intermediate
            case .advanced:
                return true
            }
        }
    }

    private func complexityForInsightType(_ type: InsightType) -> InsightComplexity {
        switch type {
        case .trend, .alert, .suggestion, .affirmation, .observation, .question:
            return .basic
        case .workplaceSpecific, .goalProgress, .correlation, .warning, .celebration:
            return .intermediate
        case .anomaly, .prediction:
            return .advanced
        }
    }

    @MainActor func adaptInsightForProfile(_ insight: InsightData) -> InsightData {
        var adaptedInsight = insight
        
        // Adjust priority based on user preferences
        if let preference = userPreferences[insight.type] {
            if preference.engagementScore > 0.7 {
                adaptedInsight.priority += 1
            } else if preference.dismissalRate > 0.5 {
                adaptedInsight.priority = max(1, adaptedInsight.priority - 1)
            }
            adaptedInsight.confidence = min(1.0, adaptedInsight.confidence * (0.8 + (preference.actionRate * 0.2)))
        }
        
        // Apply role-specific adaptations
        switch userRole {
        case .manager:
            adaptedInsight.message = adaptedInsight.message.replacingOccurrences(of: "you", with: "your team")
        case .executive:
            if !adaptedInsight.message.contains("strategic") {
                adaptedInsight.message = "From a strategic perspective: " + adaptedInsight.message
            }
        default:
            break
        }
        
        return adaptedInsight
    }

    // MARK: - Contextual Triggers

    func getContextualTriggers() -> [ContextualTrigger] {
        return contextualTriggers
    }
    
    @MainActor private func setupDefaultTriggersIfNeeded() async {
        // Only setup if no triggers exist
        guard contextualTriggers.isEmpty else { return }
        
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
        
        await saveContextualTriggers()
    }

    @MainActor private func updateContextualTriggersForProfile() async {
        switch userRole {
        case .developer:
            await addTriggerIfNeeded(ContextualTrigger(
                name: "Code Review Break",
                type: .workplacePattern,
                message: "Debugging can be mentally taxing. Take a step back to gain fresh perspective.",
                priority: 6,
                cooldownHours: 3.0
            ))
        case .manager:
            await addTriggerIfNeeded(ContextualTrigger(
                name: "Meeting Overload",
                type: .workplacePattern,
                message: "Multiple meetings can be draining. Schedule some focus time for yourself.",
                priority: 7,
                cooldownHours: 4.0
            ))
        case .designer:
            await addTriggerIfNeeded(ContextualTrigger(
                name: "Creative Block",
                type: .workplacePattern,
                message: "Creative blocks are normal. Try changing your environment or taking a walk.",
                priority: 5,
                cooldownHours: 2.0
            ))
        default:
            break
        }
        
        await saveContextualTriggers()
    }

    @MainActor private func addTriggerIfNeeded(_ trigger: ContextualTrigger) async {
        if !contextualTriggers.contains(where: { $0.name == trigger.name }) {
            contextualTriggers.append(trigger)
        }
    }

    @MainActor func evaluateContextualTriggers(for checkIn: WorkplaceCheckInData) -> [ContextualTrigger] {
        var activeTriggers: [ContextualTrigger] = []
        
        for trigger in contextualTriggers {
            if shouldTrigger(trigger, for: checkIn) {
                activeTriggers.append(trigger)
            }
        }
        
        return activeTriggers.sorted { $0.priority > $1.priority }
    }

    private func shouldTrigger(_ trigger: ContextualTrigger, for checkIn: WorkplaceCheckInData) -> Bool {
        guard trigger.canTrigger else { return false }
        
        switch trigger.type {
        case .highStress:
            return (checkIn.stressLevel ?? 0.0) > 0.7
        case .lowFocus:
            return (checkIn.focusLevel ?? 0.0) < 0.4
        case .longSession:
            return checkIn.sessionDuration > 240 // 4 hours in minutes
        case .workplacePattern:
            return checkWorkplacePatterns(for: checkIn)
        case .reflectionPrompt:
            return Int.random(in: 1...100) <= 10 // 10% chance
        }
    }

    private func checkWorkplacePatterns(for checkIn: WorkplaceCheckInData) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: checkIn.timestamp)
        
        // Afternoon stress check
        if (15...17).contains(hour) {
            return (checkIn.stressLevel ?? 0.0) > 0.6
        }
        
        return false
    }

    @MainActor func markTriggerUsed(_ trigger: ContextualTrigger) {
        guard let index = contextualTriggers.firstIndex(where: { $0.id == trigger.id }),
              index < contextualTriggers.count else {
            logger.warning("Attempted to mark non-existent trigger as used: \(trigger.id)")
            return
        }
        
        var updatedTrigger = contextualTriggers[index]
        updatedTrigger.lastTriggered = Date()
        contextualTriggers[index] = updatedTrigger
        
        Task {
            await saveContextualTriggers()
        }
    }

    // MARK: - Progressive Insights

    @MainActor private func updateComplexityBasedOnUsage() async {
        let totalEngagement = userPreferences.values.reduce(0) { $0 + $1.engagementScore }
        let averageEngagement = userPreferences.isEmpty ? 0 : totalEngagement / Double(userPreferences.count)
        let totalInteractions = userPreferences.values.reduce(0) { $0 + $1.viewCount + $1.actionCount }
        
        let newComplexity: InsightComplexity
        if totalInteractions > 500 && averageEngagement > 0.7 {
            newComplexity = .advanced
        } else if totalInteractions > 200 && averageEngagement > 0.5 {
            newComplexity = .intermediate
        } else {
            newComplexity = .basic
        }
        
        if newComplexity != insightComplexity {
            insightComplexity = newComplexity
            userDefaults.set(insightComplexity.rawValue, forKey: Keys.insightComplexity)
            logger.info("Complexity auto-updated to: \(newComplexity.rawValue)")
        }
    }

    // MARK: - Persistence

    @MainActor private func flushPendingUpdates() async {
        guard !pendingPreferenceUpdates.isEmpty else { return }
        
        let updateCount = pendingPreferenceUpdates.count
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(userPreferences)
            userDefaults.set(data, forKey: Keys.userPreferences)
            pendingPreferenceUpdates.removeAll()
            logger.debug("Flushed \(updateCount) preference updates")
        } catch {
            logger.error("Failed to flush preference updates: \(error)")
        }
    }

    @MainActor func persistUserPreferences() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(userPreferences)
            userDefaults.set(data, forKey: Keys.userPreferences)
        } catch {
            logger.error("Failed to persist user preferences: \(error)")
        }
    }
    
    @MainActor private func saveContextualTriggers() async {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(contextualTriggers)
            userDefaults.set(data, forKey: Keys.contextualTriggers)
        } catch {
            logger.error("Failed to save contextual triggers: \(error)")
        }
    }

    @MainActor private func loadUserPreferences() async {
        // Load user preferences
        if let data = userDefaults.data(forKey: Keys.userPreferences) {
            do {
                userPreferences = try JSONDecoder().decode(UserPreferencesDictionary.self, from: data)
            } catch {
                logger.error("Failed to load user preferences: \(error)")
                userPreferences = [:]
            }
        }
        
        // Load contextual triggers - preserve defaults if loading fails
        if let data = userDefaults.data(forKey: Keys.contextualTriggers) {
            do {
                let loadedTriggers = try JSONDecoder().decode([ContextualTrigger].self, from: data)
                if !loadedTriggers.isEmpty {
                    contextualTriggers = loadedTriggers
                }
            } catch {
                logger.error("Failed to load contextual triggers: \(error)")
                // Keep existing triggers or let setupDefaultTriggersIfNeeded handle it
            }
        }
        
        // Load other settings
        if let complexityRaw = userDefaults.string(forKey: Keys.insightComplexity) {
            insightComplexity = InsightComplexity(rawValue: complexityRaw) ?? .basic
        }
        
        if let roleRaw = userDefaults.string(forKey: Keys.userRole) {
            userRole = WorkRole(rawValue: roleRaw) ?? .other
        }
        
        if let industryRaw = userDefaults.string(forKey: Keys.userIndustry) {
            userIndustry = WorkIndustry(rawValue: industryRaw) ?? .other
        }
    }

    // MARK: - Insight Generation

    func generatePersonalizedInsights(
        checkIns: [WorkplaceCheckInData],
        breathingLogs: [BreathingSessionData] = [],
        journalEntries: [WorkplaceJournalEntryData] = [],
        goals: [UserGoalData] = [],
        forLastDays days: Int = 7,
        referenceDate: Date = Date()
    ) async -> [InsightData] {
        guard isInitialized else { return [] }
        
        // Basic insight generation (you'll need to implement your specific logic)
        var insights: [InsightData] = []
        
        // Example insights based on check-ins
        if !checkIns.isEmpty {
            let stressLevels = checkIns.compactMap(\.stressLevel)
            let avgStress = stressLevels.isEmpty ? 0.0 : stressLevels.reduce(0, +) / Double(stressLevels.count)
            
            let focusLevels = checkIns.compactMap(\.focusLevel)
            let avgFocus = focusLevels.isEmpty ? 0.0 : focusLevels.reduce(0, +) / Double(focusLevels.count)
            
            if avgStress > 0.7 {
                insights.append(InsightData(
                    type: .warning,
                    message: "Your stress levels have been consistently high this week. Consider implementing stress management techniques.",
                    priority: 8
                ))
            }
            
            if avgFocus < 0.4 {
                insights.append(InsightData(
                    type: .suggestion,
                    message: "Your focus has been lower than usual. Try breaking work into smaller, focused sessions.",
                    priority: 6
                ))
            }
        }
        
        // Filter and adapt insights
        insights = filterInsightsByComplexity(insights)
        
        // Ensure insights adaptation happens on the main thread
        Task { @MainActor in
            insights = insights.map { self.adaptInsightForProfile($0) }
        }
        
        // Sort by priority and engagement
        insights.sort { lhs, rhs in
            let lhsEngagement = userPreferences[lhs.type]?.engagementScore ?? 0.5
            let rhsEngagement = userPreferences[rhs.type]?.engagementScore ?? 0.5
            
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            return lhsEngagement > rhsEngagement
        }
        
        logger.info("Generated \(insights.count) personalized insights")
        return insights
    }
    
    // MARK: - Cleanup
    
    func cleanup() async {
        await flushPendingUpdates()
        cancellables.removeAll()
        logger.info("PersonalizationEngine cleanup completed")
    }
    
    deinit {
        // `cancellables` must be cleaned up in an actor-isolated context.
        // Since this is a singleton, deinit is not expected to be called during the app's lifecycle.
        // Proper cleanup should be handled by an explicit call to a cleanup() function if needed.
        logger.info("PersonalizationEngine deinitialized")
    }
}
