import Foundation
import SwiftUI
import UserNotifications
@preconcurrency import Combine
import CoreData
import os

// DTOs moved to `PersonalizationDTOs.swift` to avoid actor isolation warnings

enum PersonalizationError: Error, LocalizedError, Sendable {
    case initializationFailure
    
    nonisolated var errorDescription: String? {
        switch self {
        case .initializationFailure:
            return "PersonalizationEngine is not initialized yet."
        }
    }
}

@available(iOS 14.0, *)
@MainActor
final class PersonalizationEngine: ObservableObject {
    static let shared = PersonalizationEngine()

    // MARK: - Data Conversion Methods

    /// Convert Core Data BreathingExercise array to BreathingData array
    func convertBreathingExercises(_ coreDataExercises: [Fathom.BreathingExercise]) -> [BreathingData] {
        return coreDataExercises.map { BreathingData(from: $0) }
    }

    /// Convert Core Data WorkplaceCheckIn array to CheckInData array
    func convertWorkplaceCheckIns(_ coreDataCheckIns: [Fathom.WorkplaceCheckIn]) -> [WorkplaceCheckInData] {
        return coreDataCheckIns.map { WorkplaceCheckInData(from: $0) }
    }

    /// Convert Core Data WorkplaceJournalEntry array to the Sendable WorkplaceJournalEntry struct array
    func convertJournalEntries(_ coreDataEntries: [Fathom.JournalEntry]) -> [WorkplaceJournalEntryData] {
        return coreDataEntries.map { WorkplaceJournalEntryData(from: $0) }
    }

    /// Convert UserGoalData array to PersonalizationGoalData array
    func convertGoals(_ goals: [UserGoalData]) -> [PersonalizationGoalData] {
        return goals.map { goal in
            PersonalizationGoalData(
                id: goal.id,
                title: goal.title,
                targetDate: goal.targetDate ?? Date(),
                isCompleted: goal.isCompleted,
                progress: goal.progress
            )
        }
    }
    
    // MARK: - Published Properties
    @Published private(set) var userRole: WorkRole = .other
    @Published private(set) var userIndustry: WorkIndustry = .other
    @Published private(set) var insightComplexity: InsightComplexity = .basic
    @Published private(set) var isInitialized = false
    
    // MARK: - Private Properties
    private var userPreferences: UserPreferencesDictionary = [:]
    private var contextualTriggers: [ContextualTrigger] = []
    private var pendingPreferenceUpdates: [InsightType: InsightPreference] = [:]
    
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
        static let hasSetInsightComplexityManually = "PersonalizationEngine.hasSetInsightComplexityManually"
        static let contextualTriggers = "PersonalizationEngine.contextualTriggers"
    }
    
    private init() {
        notificationCenter = UNUserNotificationCenter.current()
        // Eagerly initialize so tests and first access see a ready engine
        performInitialSetup()
    }

    // MARK: - Initialization
    
    @MainActor func initialize() async throws {
        // Keep async signature for compatibility, but do synchronous setup
        guard !isInitialized else { return }
        performInitialSetup()
    }

    @MainActor private func performInitialSetup() {
        loadUserPreferences()
        setupDefaultTriggersIfNeeded()
        updateComplexityBasedOnUsage()
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
                    self.loadUserPreferences()
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
                    self?.flushPendingUpdates()
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
        
        updateContextualTriggersForProfile()
        
        logger.info("User profile updated: role=\(role.rawValue), industry=\(industry.rawValue)")
    }
    
    @MainActor func setInsightComplexity(_ complexity: InsightComplexity) throws {
        guard isInitialized else {
            throw PersonalizationError.initializationFailure
        }
        
        guard complexity != insightComplexity else { return }
        
        insightComplexity = complexity
        userDefaults.set(complexity.rawValue, forKey: Keys.insightComplexity)
        userDefaults.set(true, forKey: Keys.hasSetInsightComplexityManually)
        
        logger.info("Insight complexity updated to: \(complexity.rawValue)")
    }
    
    // MARK: - Preference Learning
    
    @MainActor func recordInsightEngagement(_ type: InsightType, wasDismissed: Bool, actionTaken: Bool) throws {
        guard isInitialized else {
            throw PersonalizationError.initializationFailure
        }
        
        var preference = userPreferences[type] ?? InsightPreference(insightType: type)
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
        
        var preference = userPreferences[insightType] ?? InsightPreference(insightType: insightType)
        
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
    
    @MainActor private func setupDefaultTriggersIfNeeded() {
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
        
        saveContextualTriggers()
    }

    @MainActor private func updateContextualTriggersForProfile() {
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
        
        saveContextualTriggers()
    }

    @MainActor private func addTriggerIfNeeded(_ trigger: ContextualTrigger) {
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
        
        saveContextualTriggers()
    }

    // MARK: - Progressive Insights

    @MainActor private func updateComplexityBasedOnUsage() {
        // Do not override if the user has set this manually
        guard !userDefaults.bool(forKey: Keys.hasSetInsightComplexityManually) else { return }
        
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
    
    // DTOs are defined at file scope to avoid actor isolation issues when nested in @MainActor types
    
    // Mapping helpers
    private func makeDTO(from preference: InsightPreference) -> InsightPreferenceDTO {
        InsightPreferenceDTO(
            viewCount: preference.viewCount,
            actionCount: preference.actionCount,
            dismissalCount: preference.dismissalCount,
            engagementScore: preference.engagementScore,
            lastUpdated: preference.lastUpdated
        )
    }
    
    private func makeModel(from dto: InsightPreferenceDTO, type: InsightType) -> InsightPreference {
        InsightPreference(
            insightType: type,
            viewCount: dto.viewCount,
            actionCount: dto.actionCount,
            dismissalCount: dto.dismissalCount,
            engagementScore: dto.engagementScore,
            lastUpdated: dto.lastUpdated
        )
    }
    
    private func makeDTO(from trigger: ContextualTrigger) -> ContextualTriggerDTO {
        ContextualTriggerDTO(
            id: trigger.id,
            name: trigger.name,
            type: trigger.type.rawValue,
            message: trigger.message,
            priority: trigger.priority,
            cooldownHours: trigger.cooldownHours,
            lastTriggered: trigger.lastTriggered
        )
    }
    
    private func makeModel(from dto: ContextualTriggerDTO) -> ContextualTrigger {
        ContextualTrigger(
            id: dto.id,
            name: dto.name,
            type: TriggerType(rawValue: dto.type) ?? .workplacePattern,
            message: dto.message,
            priority: dto.priority,
            cooldownHours: dto.cooldownHours,
            lastTriggered: dto.lastTriggered
        )
    }
    
    // Encoding/decoding helpers
    private func encodeUserPreferences(_ prefs: UserPreferencesDictionary) throws -> Data {
        // Persist as [String: DTO] to ensure stable JSON keys
        let dict: [String: InsightPreferenceDTO] = prefs.reduce(into: [:]) { acc, element in
            acc[element.key.rawValue] = makeDTO(from: element.value)
        }
        let encoder = JSONEncoder()
        return try encoder.encode(dict)
    }
    
    private func decodeUserPreferences(from data: Data) throws -> UserPreferencesDictionary {
        let decoder = JSONDecoder()
        // Primary path: [String: DTO]
        if let dict = try? decoder.decode([String: InsightPreferenceDTO].self, from: data) {
            var result: UserPreferencesDictionary = [:]
            for (raw, dto) in dict {
                if let type = InsightType(rawValue: raw) {
                    result[type] = makeModel(from: dto, type: type)
                }
            }
            return result
        }
        // Fallback: array of records
        if let records = try? decoder.decode([UserPreferenceRecordDTO].self, from: data) {
            var result: UserPreferencesDictionary = [:]
            for record in records {
                if let type = InsightType(rawValue: record.insightType) {
                    result[type] = makeModel(from: record.preference, type: type)
                }
            }
            return result
        }
        // If all decoding paths fail, throw
        throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unsupported user preferences format"))
    }
    
    private func encodeTriggers(_ triggers: [ContextualTrigger]) throws -> Data {
        let dtos = triggers.map { makeDTO(from: $0) }
        let encoder = JSONEncoder()
        return try encoder.encode(dtos)
    }
    
    private func decodeTriggers(from data: Data) throws -> [ContextualTrigger] {
        let decoder = JSONDecoder()
        let dtos = try decoder.decode([ContextualTriggerDTO].self, from: data)
        return dtos.map { makeModel(from: $0) }
    }
    
    @MainActor private func flushPendingUpdates() {
        guard !pendingPreferenceUpdates.isEmpty else { return }
        
        let updateCount = pendingPreferenceUpdates.count
        
        do {
            let data = try encodeUserPreferences(userPreferences)
            userDefaults.set(data, forKey: Keys.userPreferences)
            pendingPreferenceUpdates.removeAll()
            logger.debug("Flushed \(updateCount) preference updates")
        } catch {
            logger.error("Failed to flush preference updates: \(error)")
        }
    }

    @MainActor func persistUserPreferences() {
        do {
            let data = try encodeUserPreferences(userPreferences)
            userDefaults.set(data, forKey: Keys.userPreferences)
        } catch {
            logger.error("Failed to persist user preferences: \(error)")
        }
    }
    
    @MainActor private func saveContextualTriggers() {
        do {
            let data = try encodeTriggers(contextualTriggers)
            userDefaults.set(data, forKey: Keys.contextualTriggers)
        } catch {
            logger.error("Failed to save contextual triggers: \(error)")
        }
    }

    @MainActor private func loadUserPreferences() {
        // Load user preferences
        if let data = userDefaults.data(forKey: Keys.userPreferences) {
            do {
                userPreferences = try decodeUserPreferences(from: data)
            } catch {
                logger.error("Failed to load user preferences: \(error)")
                userPreferences = [:]
            }
        }
        
        // Load contextual triggers - preserve defaults if loading fails
        if let data = userDefaults.data(forKey: Keys.contextualTriggers) {
            do {
                let loadedTriggers = try decodeTriggers(from: data)
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
        breathingLogs: [BreathingData] = [],
        journalEntries: [WorkplaceJournalEntryData] = [],
        goals: [PersonalizationGoalData] = [],
        forLastDays days: Int = 7,
        referenceDate: Date = Date()
    ) async -> [InsightData] {
        guard isInitialized else { return [] }
        
        // Basic insight generation (you'll need to implement your specific logic)
        var insights: [InsightData] = []
        
        // Example insights based on check-ins
        if !checkIns.isEmpty {
            let stressLevels = checkIns.map(\.stressLevel)
            let avgStress = stressLevels.isEmpty ? 0.0 : stressLevels.reduce(0, +) / Double(stressLevels.count)

            let focusLevels = checkIns.map(\.focusLevel)
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
        
        // Ensure insights adaptation happens on the main thread before returning
        insights = insights.map { self.adaptInsightForProfile($0) }
        
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
        flushPendingUpdates()
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
