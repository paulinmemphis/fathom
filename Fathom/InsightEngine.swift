import Foundation
import CoreData
import NaturalLanguage

// MARK: - Insight Data Structures

struct Insight: Identifiable, Hashable {
    let id = UUID()
    var message: String
    var type: InsightType
    var priority: Int = 0 // Higher is more important
    var confidence: Double = 1.0 // 0.0 to 1.0 statistical confidence
    var isAnomaly: Bool = false // Flagged as unusual pattern
    var prediction: PredictionData? = nil // Predictive modeling data
    
    // Conformance to Hashable (primarily for use in ForEach if keys are not stable)
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Insight, rhs: Insight) -> Bool {
        lhs.id == rhs.id
    }
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

// MARK: - Phase 2 Algorithmic Data Structures

struct PredictionData {
    let forecastPeriod: String // "next week", "next month"
    let predictedValue: Double
    let trendDirection: TrendDirection
    let confidenceInterval: (lower: Double, upper: Double)
    
    init(forecastPeriod: String, predictedValue: Double, trendDirection: TrendDirection, confidenceInterval: (lower: Double, upper: Double)) {
        self.forecastPeriod = forecastPeriod
        self.predictedValue = predictedValue
        self.trendDirection = trendDirection
        self.confidenceInterval = confidenceInterval
    }
}

enum TrendDirection {
    case increasing, decreasing, stable, volatile
}

struct AdaptiveThreshold {
    let name: String
    var currentValue: Double
    let baselineValue: Double
    let adaptationFactor: Double = 0.1 // Learning rate
    let minValue: Double
    let maxValue: Double
    var historicalValues: [Double] = []
    
    mutating func adapt(newDataPoint: Double) {
        // Simple exponential moving average adaptation
        currentValue = (1 - adaptationFactor) * currentValue + adaptationFactor * newDataPoint
        currentValue = max(minValue, min(maxValue, currentValue))
        historicalValues.append(newDataPoint)
        
        // Keep only last 50 values for memory efficiency
        if historicalValues.count > 50 {
            historicalValues.removeFirst()
        }
    }
    
    func getStandardDeviation() -> Double {
        guard historicalValues.count > 1 else { return 0.0 }
        let mean = historicalValues.reduce(0, +) / Double(historicalValues.count)
        let squaredDifferences = historicalValues.map { pow($0 - mean, 2) }
        let variance = squaredDifferences.reduce(0, +) / Double(historicalValues.count - 1)
        return sqrt(variance)
    }
}

struct ConfidenceMetrics {
    let sampleSize: Int
    let standardError: Double
    let confidenceLevel: Double // 0.95 for 95% confidence
    
    func getConfidenceScore() -> Double {
        // Higher sample size and lower standard error = higher confidence
        let sizeScore = min(1.0, Double(sampleSize) / 30.0) // Normalize to 30 samples
        let errorScore = max(0.0, 1.0 - standardError)
        return (sizeScore + errorScore) / 2.0
    }
}

// MARK: - Insight Engine

@MainActor
class InsightEngine {
    
    static let shared = InsightEngine()

    // MARK: - Phase 2: Adaptive Thresholds
    private var adaptiveThresholds: [String: AdaptiveThreshold] = [
        "maxWeeklyHours": AdaptiveThreshold(name: "maxWeeklyHours", currentValue: 50.0, baselineValue: 50.0, minValue: 35.0, maxValue: 65.0),
        "highStress": AdaptiveThreshold(name: "highStress", currentValue: 4.0, baselineValue: 4.0, minValue: 3.0, maxValue: 5.0),
        "lowFocus": AdaptiveThreshold(name: "lowFocus", currentValue: 2.0, baselineValue: 2.0, minValue: 1.0, maxValue: 3.0),
        "sessionDuration": AdaptiveThreshold(name: "sessionDuration", currentValue: 3.0, baselineValue: 3.0, minValue: 2.0, maxValue: 5.0)
    ]

    // Example: Maximum work hours per week before suggesting a break or concern
    private let maxWeeklyHoursThreshold: Double = 50.0
    private let minBreathingSessionsForHighWorkload: Int = 3
    private let highStressThreshold: Int16 = 4
    private let lowFocusThreshold: Int16 = 2
    private let minReflectionsForAverageInsight = 3 // For Rule 3
    private let lateNightHourThreshold = 22 // 10 PM
    private let minLateNightsForInsight = 2
    private let minWeekendSessionsForInsight = 1

    // Thresholds for Rule 7 (Session Duration vs Reflection)
    private let longSessionDurationHours: Double = 3.0
    private let shortSessionDurationHours: Double = 1.0
    private let minSessionsForDurationCorrelationInsight = 3 // Min sessions in each category (e.g., long and short)
    private let reflectionDifferenceThreshold: Int16 = 1 // Min difference in avg focus/stress to be notable

    // Thresholds for Rule 8 (Same-Day Breathing vs Reflection)
    private let minSessionsForBreathingCorrelationInsight = 3 // Min sessions on breathing days and non-breathing days

    // Thresholds for Rule 9 (Prompt for Reflection)
    private let minCompletedSessionsForReflectionPrompt = 3
    private let maxReflectionsForReflectionPrompt = 0 // Prompt if 0 reflections in the period

    // Thresholds for Rule 10 (Workplace-Specific Reflections)
    private let minWorkplacesForComparison = 2
    private let minSessionsPerWorkplaceForCorrelation = 3
    // Reuses reflectionDifferenceThreshold from Rule 7

    // Thresholds for Rule 11 (Time of Day vs Reflection)
    private let morningBlockEndHour = 12 // Up to 11:59 AM
    private let afternoonBlockEndHour = 18 // Up to 5:59 PM
    // Evening is after afternoonBlockEndHour, before lateNightHourThreshold
    private let minSessionsPerTimeBlockForCorrelation = 3
    // Reuses reflectionDifferenceThreshold from Rule 7

    // Thresholds for Rule 12 (Day of Week vs Reflection)
    private let minSessionsPerDayForCorrelation = 2 // Min sessions on a specific day (e.g. 2 Mondays) to be included
    // Reuses reflectionDifferenceThreshold from Rule 7

    // Helper for message variation - accessible to all rules
    private static func randomMessage(from messages: [String]) -> String {
        return messages.randomElement() ?? messages.first ?? ""
    }

    func generateInsights(checkIns: [CheckInData], breathingLogs: [BreathingData] = [], journalEntries: [WorkplaceJournalEntry] = [], goals: [UserGoal] = [], forLastDays days: Int = 7, referenceDate: Date = Date()) -> [Insight] {
        var generatedInsights: [Insight] = []

        // MARK: - Phase 2: Update Adaptive Thresholds
        updateAdaptiveThresholds(checkIns: checkIns, breathingLogs: breathingLogs)
        
        let calendar = Calendar.current
        // Current period (e.g., last 7 days)
        guard let currentPeriodEndDate = calendar.startOfDay(for: referenceDate) as Date?,
              let currentPeriodStartDate = calendar.date(byAdding: .day, value: -days, to: currentPeriodEndDate) else {
            return generatedInsights
        }

        // Filter check-ins to current period
        let currentPeriodCheckIns = checkIns.filter { checkIn in
            return checkIn.timestamp >= currentPeriodStartDate && checkIn.timestamp <= currentPeriodEndDate
        }

        // Filter breathing logs to current period
        let currentPeriodBreathingLogs = breathingLogs.filter { log in
            return log.timestamp >= currentPeriodStartDate && log.timestamp <= currentPeriodEndDate
        }

        // Filter journal entries to current period
        let currentPeriodJournalEntries = journalEntries.compactMap { entry -> WorkplaceJournalEntry? in
            return entry.date >= currentPeriodStartDate && entry.date < referenceDate ? entry : nil
        }

        // MARK: - Phase 2: Enhanced Analytics with Confidence and Anomaly Detection
        
        // Analyze work patterns with confidence scoring
        let workHours = currentPeriodCheckIns.map { Double($0.sessionDuration) / 3600.0 }
        
        if !workHours.isEmpty {
            // Detect anomalies in work hours
            let anomalies = detectAnomalies(values: workHours)
            let variance = workHours.map { pow($0 - workHours.reduce(0, +) / Double(workHours.count), 2) }.reduce(0, +) / Double(workHours.count - 1)
            let confidence = calculateConfidence(sampleSize: workHours.count, variance: variance)
            
            // Generate predictive insights
            if let prediction = predictTrend(values: workHours) {
                var insight = Insight(
                    message: "📈 Predicted work pattern: Your work hours trend is \(prediction.trendDirection == .increasing ? "increasing" : prediction.trendDirection == .decreasing ? "decreasing" : "stable"). Expected average for \(prediction.forecastPeriod): \(String(format: "%.1f", prediction.predictedValue)) hours.",
                    type: .prediction,
                    priority: 2
                )
                insight.confidence = confidence.getConfidenceScore()
                insight.prediction = prediction
                generatedInsights.append(insight)
            }
            
            // Flag anomalous sessions
            for (index, isAnomaly) in anomalies.enumerated() where isAnomaly {
                var insight = Insight(
                    message: "⚠️ Unusual work session detected: \(String(format: "%.1f", workHours[index])) hours - significantly different from your typical pattern.",
                    type: .anomaly,
                    priority: 3
                )
                insight.confidence = confidence.getConfidenceScore()
                insight.isAnomaly = true
                generatedInsights.append(insight)
            }
        }

        // MARK: - Enhanced Stress/Focus Analysis with Adaptive Thresholds
        let stressRatings = currentPeriodCheckIns.map { $0.stressLevel }
        let focusRatings = currentPeriodCheckIns.map { $0.focusLevel }
        
        if !stressRatings.isEmpty {
            let adaptiveStressThreshold = adaptiveThresholds["highStress"]?.currentValue ?? 4.0
            let highStressCount = stressRatings.filter { $0 >= adaptiveStressThreshold }.count
            let variance = stressRatings.map { pow($0 - stressRatings.reduce(0, +) / Double(stressRatings.count), 2) }.reduce(0, +) / Double(stressRatings.count - 1)
            let confidence = calculateConfidence(sampleSize: stressRatings.count, variance: variance)
            
            if highStressCount > stressRatings.count / 2 {
                var insight = Insight(
                    message: "🔍 Adaptive Analysis: Your stress threshold has been personalized to \(String(format: "%.1f", adaptiveStressThreshold)). Recent pattern shows elevated stress in \(highStressCount)/\(stressRatings.count) sessions.",
                    type: .observation,
                    priority: 2
                )
                insight.confidence = confidence.getConfidenceScore()
                generatedInsights.append(insight)
            }
        }
        
        if !focusRatings.isEmpty {
            let adaptiveFocusThreshold = adaptiveThresholds["lowFocus"]?.currentValue ?? 2.0
            let lowFocusCount = focusRatings.filter { $0 <= adaptiveFocusThreshold }.count
            let variance = focusRatings.map { pow($0 - focusRatings.reduce(0, +) / Double(focusRatings.count), 2) }.reduce(0, +) / Double(focusRatings.count - 1)
            let confidence = calculateConfidence(sampleSize: focusRatings.count, variance: variance)
            
            if let prediction = predictTrend(values: focusRatings) {
                var insight = Insight(
                    message: "🎯 Focus Forecast: Your focus trend is \(prediction.trendDirection == .increasing ? "improving" : prediction.trendDirection == .decreasing ? "declining" : "stable"). Predicted focus level for \(prediction.forecastPeriod): \(String(format: "%.1f", prediction.predictedValue))/5.",
                    type: .prediction,
                    priority: 2
                )
                insight.confidence = confidence.getConfidenceScore()
                insight.prediction = prediction
                generatedInsights.append(insight)
            }
        }

        // MARK: - Phase 2: Enhanced Insight Generation with Original Logic
        
        // Previous period (e.g., days 8-14 ago for trend comparison)
        guard let previousPeriodEndDate = calendar.date(byAdding: .day, value: -1, to: currentPeriodStartDate),
              let previousPeriodStartDate = calendar.date(byAdding: .day, value: -days, to: previousPeriodEndDate) else {
            return generatedInsights
        }

        // Historical period for calculating averages (e.g., last 4 weeks, excluding current week)
        let historicalWeeksForAverage = 4
        guard let historicalAverageEndDate = calendar.date(byAdding: .day, value: -1, to: currentPeriodStartDate),
              let historicalAverageStartDate = calendar.date(byAdding: .day, value: -(days * historicalWeeksForAverage), to: historicalAverageEndDate) else {
            return generatedInsights
        }

        // Filter data for the relevant periods
        let previousPeriodBreathingLogs = breathingLogs.filter { $0.timestamp >= previousPeriodStartDate && $0.timestamp < previousPeriodEndDate }
        let historicalCheckInsForAverage = checkIns.filter { $0.timestamp >= historicalAverageStartDate && $0.timestamp < historicalAverageEndDate }

        // Analyze sentiment for both journal entries and session notes
        var sentimentInsights: [Insight] = []
        
        // Journal entries sentiment analysis
        for entry in currentPeriodJournalEntries {
            let sentiment = sentimentAnalysis(for: entry.text)
            if sentiment > 0.3 {
                sentimentInsights.append(Insight(message: "Your journal entry '\(entry.title)' has a positive tone. What's been going well?", type: .question, priority: 3))
            } else if sentiment < -0.3 {
                sentimentInsights.append(Insight(message: "Your journal entry '\(entry.title)' reflects some challenges. Would you like to explore what's been difficult?", type: .question, priority: 3))
            }
        }
        
        // Session notes sentiment analysis
        let checkInsWithNotes = currentPeriodCheckIns.filter { $0.sessionNote != nil && !$0.sessionNote!.isEmpty }
        var positiveSessions = 0
        var negativeSessions = 0
        
        for checkIn in checkInsWithNotes {
            let sentiment = sentimentAnalysis(for: checkIn.sessionNote!)
            if sentiment > 0.3 {
                positiveSessions += 1
            } else if sentiment < -0.3 {
                negativeSessions += 1
            }
        }
        
        // Generate insights based on session note sentiment patterns
        if positiveSessions > negativeSessions && positiveSessions >= 2 {
            sentimentInsights.append(Insight(message: "Your session reflections show a positive pattern this week. Keep up the good work!", type: .affirmation, priority: 2))
        } else if negativeSessions > positiveSessions && negativeSessions >= 2 {
            sentimentInsights.append(Insight(message: "Your session reflections suggest some challenges this week. Consider what support might help.", type: .question, priority: 2))
        }

        generatedInsights.append(contentsOf: sentimentInsights)

        // MARK: - Enhanced Original Rules with Adaptive Thresholds
        
        // --- Insight Rule 1: Total Work Hours & Breathing Balance (Enhanced with Adaptive Thresholds) ---
        let totalWorkHoursThisPeriod = currentPeriodCheckIns.reduce(0.0) { total, checkIn in
            return total + (Double(checkIn.sessionDuration) / 3600.0)
        }
        let numberOfBreathingSessionsThisPeriod = currentPeriodBreathingLogs.count

        // Calculate historical average weekly work hours
        let totalHistoricalWorkHours = historicalCheckInsForAverage.reduce(0.0) { total, checkIn in
            return total + (Double(checkIn.sessionDuration) / 3600.0)
        }
        let averageWeeklyWorkHoursHistorical = historicalWeeksForAverage > 0 ? totalHistoricalWorkHours / Double(historicalWeeksForAverage) : 0.0
        let workHoursThisPeriodFormatted = String(format: "%.1f", totalWorkHoursThisPeriod)

        // Use adaptive threshold for max weekly hours
        let adaptiveMaxWeeklyHours = adaptiveThresholds["maxWeeklyHours"]?.currentValue ?? maxWeeklyHoursThreshold

        if totalWorkHoursThisPeriod > 0 {
            // Compare to historical average if available, otherwise use adaptive threshold
            let significantlyAboveAverage = averageWeeklyWorkHoursHistorical > 0 && totalWorkHoursThisPeriod > averageWeeklyWorkHoursHistorical * 1.2 // 20% above average
            let significantlyBelowAverage = averageWeeklyWorkHoursHistorical > 0 && totalWorkHoursThisPeriod < averageWeeklyWorkHoursHistorical * 0.8 // 20% below average

            if significantlyAboveAverage || (averageWeeklyWorkHoursHistorical == 0 && totalWorkHoursThisPeriod > adaptiveMaxWeeklyHours) {
                // Condition for high workload
                if numberOfBreathingSessionsThisPeriod < minBreathingSessionsForHighWorkload {
                    var insight = Insight(message: "You've logged \(workHoursThisPeriodFormatted) hours in the last \(days) days, which is more than usual for you. We also noticed only \(numberOfBreathingSessionsThisPeriod) breathing session(s). Mindful breaks are key during intense periods. Consider one?", type: .suggestion, priority: 10)
                    insight.confidence = currentPeriodCheckIns.count >= 3 ? 0.8 : 0.5
                    generatedInsights.append(insight)
                } else {
                    var insight = Insight(message: "You've worked \(workHoursThisPeriodFormatted) hours in the last \(days) days—a significant amount. It's good to see you've included \(numberOfBreathingSessionsThisPeriod) breathing exercises. How is this balance feeling?", type: .question, priority: 5)
                    insight.confidence = currentPeriodCheckIns.count >= 3 ? 0.8 : 0.5
                    generatedInsights.append(insight)
                }
            } else if significantlyBelowAverage {
                var insight = Insight(message: "Your work hours this past period (\(workHoursThisPeriodFormatted) hrs) were lower than your recent average. You also completed \(numberOfBreathingSessionsThisPeriod) breathing exercise(s). How did this change in pace affect you?", type: .question, priority: 2)
                insight.confidence = 0.7
                generatedInsights.append(insight)
            } else {
                var insight = Insight(message: "This past period, you logged \(workHoursThisPeriodFormatted) work hours and completed \(numberOfBreathingSessionsThisPeriod) breathing exercise(s). How did this rhythm feel for you?", type: .question, priority: 2)
                insight.confidence = 0.6
                generatedInsights.append(insight)
            }
        }

        // Continue with remaining rules...
        generatedInsights.append(contentsOf: generateRemainingInsightRules(
    }

    // Filter breathing logs to current period
    let currentPeriodBreathingLogs = breathingLogs.filter { log in
        return log.timestamp >= currentPeriodStartDate && log.timestamp <= currentPeriodEndDate
    }

    // Filter journal entries to current period
    let currentPeriodJournalEntries = journalEntries.compactMap { entry -> WorkplaceJournalEntry? in
        return entry.date >= currentPeriodStartDate && entry.date < referenceDate ? entry : nil
    }

    // MARK: - Phase 2: Enhanced Analytics with Confidence and Anomaly Detection
    
    // Analyze work patterns with confidence scoring
    let workHours = currentPeriodCheckIns.map { Double($0.sessionDuration) / 3600.0 }
    
    if !workHours.isEmpty {
        // Detect anomalies in work hours
        let anomalies = detectAnomalies(values: workHours)
        let variance = workHours.map { pow($0 - workHours.reduce(0, +) / Double(workHours.count), 2) }.reduce(0, +) / Double(workHours.count - 1)
        let confidence = calculateConfidence(sampleSize: workHours.count, variance: variance)
        
        // Generate predictive insights
        if let prediction = predictTrend(values: workHours) {
            var insight = Insight(
                message: "📈 Predicted work pattern: Your work hours trend is \(prediction.trendDirection == .increasing ? "increasing" : prediction.trendDirection == .decreasing ? "decreasing" : "stable"). Expected average for \(prediction.forecastPeriod): \(String(format: "%.1f", prediction.predictedValue)) hours.",
                type: .prediction,
                priority: 2
            )
            insight.confidence = confidence.getConfidenceScore()
            insight.prediction = prediction
            generatedInsights.append(insight)
        }
        
        // Flag anomalous sessions
        for (index, isAnomaly) in anomalies.enumerated() where isAnomaly {
            var insight = Insight(
                message: "⚠️ Unusual work session detected: \(String(format: "%.1f", workHours[index])) hours - significantly different from your typical pattern.",
                type: .anomaly,
                priority: 3
            )
            insight.confidence = confidence.getConfidenceScore()
            insight.isAnomaly = true
            generatedInsights.append(insight)
        }
    }

    // MARK: - Enhanced Stress/Focus Analysis with Adaptive Thresholds
    let stressRatings = currentPeriodCheckIns.map { $0.stressLevel }
    let focusRatings = currentPeriodCheckIns.map { $0.focusLevel }
    
    if !stressRatings.isEmpty {
        let adaptiveStressThreshold = adaptiveThresholds["highStress"]?.currentValue ?? 4.0
        let highStressCount = stressRatings.filter { $0 >= adaptiveStressThreshold }.count
        let variance = stressRatings.map { pow($0 - stressRatings.reduce(0, +) / Double(stressRatings.count), 2) }.reduce(0, +) / Double(stressRatings.count - 1)
        let confidence = calculateConfidence(sampleSize: stressRatings.count, variance: variance)
        
        if highStressCount > stressRatings.count / 2 {
            var insight = Insight(
                message: "🔍 Adaptive Analysis: Your stress threshold has been personalized to \(String(format: "%.1f", adaptiveStressThreshold)). Recent pattern shows elevated stress in \(highStressCount)/\(stressRatings.count) sessions.",
                type: .observation,
                priority: 2
            )
            insight.confidence = confidence.getConfidenceScore()
            generatedInsights.append(insight)
        }
    }
    
    if !focusRatings.isEmpty {
        let adaptiveFocusThreshold = adaptiveThresholds["lowFocus"]?.currentValue ?? 2.0
        let lowFocusCount = focusRatings.filter { $0 <= adaptiveFocusThreshold }.count
        let variance = focusRatings.map { pow($0 - focusRatings.reduce(0, +) / Double(focusRatings.count), 2) }.reduce(0, +) / Double(focusRatings.count - 1)
        let confidence = calculateConfidence(sampleSize: focusRatings.count, variance: variance)
        
        if let prediction = predictTrend(values: focusRatings) {
            var insight = Insight(
                message: "🎯 Focus Forecast: Your focus trend is \(prediction.trendDirection == .increasing ? "improving" : prediction.trendDirection == .decreasing ? "declining" : "stable"). Predicted focus level for \(prediction.forecastPeriod): \(String(format: "%.1f", prediction.predictedValue))/5.",
                type: .prediction,
                priority: 2
            )
            insight.confidence = confidence.getConfidenceScore()
            insight.prediction = prediction
            generatedInsights.append(insight)
        }
    }

    // MARK: - Phase 2: Enhanced Insight Generation with Original Logic
    
    // Previous period (e.g., days 8-14 ago for trend comparison)
    guard let previousPeriodEndDate = calendar.date(byAdding: .day, value: -1, to: currentPeriodStartDate),
          let previousPeriodStartDate = calendar.date(byAdding: .day, value: -days, to: previousPeriodEndDate) else {
        return generatedInsights
    }

    // Historical period for calculating averages (e.g., last 4 weeks, excluding current week)
    let historicalWeeksForAverage = 4
    guard let historicalAverageEndDate = calendar.date(byAdding: .day, value: -1, to: currentPeriodStartDate),
          let historicalAverageStartDate = calendar.date(byAdding: .day, value: -(days * historicalWeeksForAverage), to: historicalAverageEndDate) else {
        return generatedInsights
    }

    // Filter data for the relevant periods
    let previousPeriodBreathingLogs = breathingLogs.filter { $0.timestamp >= previousPeriodStartDate && $0.timestamp < previousPeriodEndDate }
    let historicalCheckInsForAverage = checkIns.filter { $0.timestamp >= historicalAverageStartDate && $0.timestamp < historicalAverageEndDate }

    // Analyze sentiment for both journal entries and session notes
    var sentimentInsights: [Insight] = []
    
    // Journal entries sentiment analysis
    for entry in currentPeriodJournalEntries {
        let sentiment = sentimentAnalysis(for: entry.text)
        if sentiment > 0.3 {
            sentimentInsights.append(Insight(message: "Your journal entry '\(entry.title)' has a positive tone. What's been going well?", type: .question, priority: 3))
        } else if sentiment < -0.3 {
            sentimentInsights.append(Insight(message: "Your journal entry '\(entry.title)' reflects some challenges. Would you like to explore what's been difficult?", type: .question, priority: 3))
        }
    }
    
    // Session notes sentiment analysis
    let checkInsWithNotes = currentPeriodCheckIns.filter { $0.sessionNote != nil && !$0.sessionNote!.isEmpty }
    var positiveSessions = 0
    var negativeSessions = 0
    
    for checkIn in checkInsWithNotes {
        let sentiment = sentimentAnalysis(for: checkIn.sessionNote!)
        if sentiment > 0.3 {
            positiveSessions += 1
        } else if sentiment < -0.3 {
            negativeSessions += 1
        }
    }
    
    // Generate insights based on session note sentiment patterns
    if positiveSessions > negativeSessions && positiveSessions >= 2 {
        sentimentInsights.append(Insight(message: "Your session reflections show a positive pattern this week. Keep up the good work!", type: .affirmation, priority: 2))
    } else if negativeSessions > positiveSessions && negativeSessions >= 2 {
        sentimentInsights.append(Insight(message: "Your session reflections suggest some challenges this week. Consider what support might help.", type: .question, priority: 2))
    }

    generatedInsights.append(contentsOf: sentimentInsights)

    // MARK: - Enhanced Original Rules with Adaptive Thresholds
    
    // --- Insight Rule 1: Total Work Hours & Breathing Balance (Enhanced with Adaptive Thresholds) ---
    let totalWorkHoursThisPeriod = currentPeriodCheckIns.reduce(0.0) { total, checkIn in
        return total + (Double(checkIn.sessionDuration) / 3600.0)
    }
    let numberOfBreathingSessionsThisPeriod = currentPeriodBreathingLogs.count

    // Calculate historical average weekly work hours
    let totalHistoricalWorkHours = historicalCheckInsForAverage.reduce(0.0) { total, checkIn in
        return total + (Double(checkIn.sessionDuration) / 3600.0)
    }
    let averageWeeklyWorkHoursHistorical = historicalWeeksForAverage > 0 ? totalHistoricalWorkHours / Double(historicalWeeksForAverage) : 0.0
    let workHoursThisPeriodFormatted = String(format: "%.1f", totalWorkHoursThisPeriod)

    // Use adaptive threshold for max weekly hours
    let adaptiveMaxWeeklyHours = adaptiveThresholds["maxWeeklyHours"]?.currentValue ?? maxWeeklyHoursThreshold

    if totalWorkHoursThisPeriod > 0 {
        // Compare to historical average if available, otherwise use adaptive threshold
        let significantlyAboveAverage = averageWeeklyWorkHoursHistorical > 0 && totalWorkHoursThisPeriod > averageWeeklyWorkHoursHistorical * 1.2 // 20% above average
        let significantlyBelowAverage = averageWeeklyWorkHoursHistorical > 0 && totalWorkHoursThisPeriod < averageWeeklyWorkHoursHistorical * 0.8 // 20% below average

        if significantlyAboveAverage || (averageWeeklyWorkHoursHistorical == 0 && totalWorkHoursThisPeriod > adaptiveMaxWeeklyHours) {
            // Condition for high workload
            if numberOfBreathingSessionsThisPeriod < minBreathingSessionsForHighWorkload {
                var insight = Insight(message: "You've logged \(workHoursThisPeriodFormatted) hours in the last \(days) days, which is more than usual for you. We also noticed only \(numberOfBreathingSessionsThisPeriod) breathing session(s). Mindful breaks are key during intense periods. Consider one?", type: .suggestion, priority: 10)
                insight.confidence = currentPeriodCheckIns.count >= 3 ? 0.8 : 0.5
                generatedInsights.append(insight)
            } else {
                var insight = Insight(message: "You've worked \(workHoursThisPeriodFormatted) hours in the last \(days) days—a significant amount. It's good to see you've included \(numberOfBreathingSessionsThisPeriod) breathing exercises. How is this balance feeling?", type: .question, priority: 5)
                insight.confidence = currentPeriodCheckIns.count >= 3 ? 0.8 : 0.5
                generatedInsights.append(insight)
            }
        } else if significantlyBelowAverage {
            var insight = Insight(message: "Your work hours this past period (\(workHoursThisPeriodFormatted) hrs) were lower than your recent average. You also completed \(numberOfBreathingSessionsThisPeriod) breathing exercise(s). How did this change in pace affect you?", type: .question, priority: 2)
            insight.confidence = 0.7
            generatedInsights.append(insight)

        // --- Insight Rule 3: Reflections on Focus & Stress (Enhanced with Adaptive Thresholds) ---
        let checkInsWithReflections = currentPeriodCheckIns.filter { checkIn in
            return checkIn.focusRating > 0 || checkIn.stressRating > 0
        }

        if !checkInsWithReflections.isEmpty {
            let reflectionCount = checkInsWithReflections.count
            let averageFocus: Double = checkInsWithReflections.reduce(0.0) { total, checkIn in
                total + Double(checkIn.focusRating)
            } / Double(reflectionCount)
            let averageStress: Double = checkInsWithReflections.reduce(0.0) { total, checkIn in
                total + Double(checkIn.stressRating)
            } / Double(reflectionCount)

            let adaptiveLowFocusThreshold = adaptiveThresholds["lowFocus"]?.currentValue ?? Double(lowFocusThreshold)
            let adaptiveHighStressThreshold = adaptiveThresholds["highStress"]?.currentValue ?? Double(highStressThreshold)

            if averageFocus <= adaptiveLowFocusThreshold && checkInsWithReflections.count >= minReflectionsForAverageInsight {
                var insight = Insight(message: "Lately, your average focus rating after work sessions has been around \(String(format: "%.1f", averageFocus))/5. What factors do you think are influencing your concentration?", type: .question, priority: 6)
                insight.confidence = min(0.9, Double(reflectionCount) / 10.0)
                insights.append(insight)
            }
            if averageStress >= adaptiveHighStressThreshold && checkInsWithReflections.count >= minReflectionsForAverageInsight {
                var insight = Insight(message: "Your average stress rating recently is about \(String(format: "%.1f", averageStress))/5. Remember to utilize mindful moments and breaks. How are you managing stress levels this week?", type: .question, priority: 7)
                insight.confidence = min(0.9, Double(reflectionCount) / 10.0)
                insights.append(insight)
            }
        }

        return insights
    }

    // MARK: - Helper Methods

    private func sentimentAnalysis(for text: String) -> Double {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        
        let (sentiment, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        
        if let sentimentScore = sentiment {
            // Convert string sentiment score to Double
            return Double(sentimentScore.rawValue) ?? 0.0
            let weekOfYear = calendar.component(.weekOfYear, from: checkInTime)
            let year = calendar.component(.year, from: checkInTime)
            return "\(year)-\(weekOfYear)"
        }
        
        for (_, weekCheckIns) in groupedByWeek {
            let totalHours = weekCheckIns.reduce(0.0) { total, checkIn in
                guard let start = checkIn.checkInTime, let end = checkIn.checkOutTime else { return total }
                return total + end.timeIntervalSince(start) / 3600
            }
            weeklyHours.append(totalHours)
        }
        
        return weeklyHours
    }

    // MARK: - Phase 2: Confidence Scoring
    
    private func calculateConfidence(sampleSize: Int, variance: Double) -> ConfidenceMetrics {
        let baseConfidence: Double
        
        // Confidence based on sample size
        switch sampleSize {
        case 0...2:
            baseConfidence = 0.3
        case 3...5:
            baseConfidence = 0.6
        case 6...10:
            baseConfidence = 0.8
        default:
            baseConfidence = 0.9
        }
        
        // Adjust for variance (lower variance = higher confidence)
        let varianceAdjustment = max(0.0, min(0.2, variance / 10.0))
        let finalConfidence = max(0.1, baseConfidence - varianceAdjustment)
        
        return ConfidenceMetrics(sampleSize: sampleSize, standardError: varianceAdjustment, confidenceLevel: finalConfidence)
    }

    // MARK: - Phase 2: Anomaly Detection
    
    private func detectAnomalies(values: [Double], threshold: Double = 2.0) -> [Bool] {
        guard values.count >= 3 else { return [] }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        let standardDeviation = sqrt(variance)
        
        var anomalies: [Bool] = []
        
        for (_, value) in values.enumerated() {
            let zScore = abs(value - mean) / standardDeviation
            if zScore > threshold {
                anomalies.append(true)
            } else {
                anomalies.append(false)
            }
        }
        
        return anomalies
    }

    // MARK: - Phase 2: Predictive Modeling
    
    private func predictTrend(values: [Double]) -> PredictionData? {
        guard values.count >= 3 else { return nil }
        
        // Simple linear regression for trend prediction
        let n = Double(values.count)
        let xValues = Array(0..<values.count).map { Double($0) }
        
        let sumX = xValues.reduce(0, +)
        let sumY = values.reduce(0, +)
        let sumXY = zip(xValues, values).map(*).reduce(0, +)
        let sumXX = xValues.map { $0 * $0 }.reduce(0, +)
        
        let slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX)
        let intercept = (sumY - slope * sumX) / n
        
        // Predict next value
        let nextX = Double(values.count)
        let predictedValue = slope * nextX + intercept
        
        // Determine trend direction
        let trendDirection: TrendDirection
        if slope > 0.1 {
            trendDirection = .increasing
        } else if slope < -0.1 {
            trendDirection = .decreasing
        } else {
            trendDirection = .stable
        }
        
        return PredictionData(
            forecastPeriod: "next session",
            predictedValue: max(0, min(5, predictedValue)), // Clamp to valid range
            trendDirection: trendDirection,
            confidenceInterval: (lower: predictedValue - 1, upper: predictedValue + 1)
        )
    }
}
