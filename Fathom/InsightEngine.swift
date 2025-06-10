import Foundation

// MARK: - Insight Data Structures

struct Insight: Identifiable, Hashable {
    let id = UUID()
    var message: String
    var type: InsightType
    var priority: Int = 0 // Higher is more important
    // let relatedDataIDs: [UUID]? // Optional: to link to specific Core Data objectIDs if needed later

    // Conformance to Hashable (primarily for use in ForEach if keys are not stable)
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Insight, rhs: Insight) -> Bool {
        lhs.id == rhs.id
    }
}

enum InsightType: String, CaseIterable {
    case observation = "Observation"
    case question = "Question"
    case suggestion = "Suggestion"
    case affirmation = "Affirmation"
    case alert = "Alert" // For more critical patterns
}

// MARK: - Insight Engine

@MainActor
class InsightEngine {

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

    func generateInsights(checkIns: [WorkplaceCheckIn], breathingLogs: [BreathingExerciseLog], forLastDays days: Int = 7, referenceDate: Date = Date()) -> [Insight] {
        var generatedInsights: [Insight] = []

        let calendar = Calendar.current
        // Current period (e.g., last 7 days)
        guard let currentPeriodEndDate = calendar.startOfDay(for: referenceDate) as Date?,
              let currentPeriodStartDate = calendar.date(byAdding: .day, value: -days, to: currentPeriodEndDate) else {
            return []
        }

        // Previous period (e.g., days 8-14 ago for trend comparison)
        guard let previousPeriodEndDate = calendar.date(byAdding: .day, value: -1, to: currentPeriodStartDate),
              let previousPeriodStartDate = calendar.date(byAdding: .day, value: -days, to: previousPeriodEndDate) else {
            return []
        }

        // Historical period for calculating averages (e.g., last 4 weeks, excluding current week)
        // This would be days 8 to 35 ago if 'days' is 7.
        let historicalWeeksForAverage = 4
        guard let historicalAverageEndDate = calendar.date(byAdding: .day, value: -1, to: currentPeriodStartDate),
              let historicalAverageStartDate = calendar.date(byAdding: .day, value: -(days * historicalWeeksForAverage), to: historicalAverageEndDate) else {
            return []
        }

        // Filter data for the relevant periods
        let currentPeriodCheckIns = checkIns.filter { ($0.checkInTime ?? Date.distantPast >= currentPeriodStartDate && $0.checkInTime ?? Date.distantFuture < currentPeriodEndDate) && $0.checkOutTime != nil }
        let currentPeriodBreathingLogs = breathingLogs.filter { $0.timestamp ?? Date.distantPast >= currentPeriodStartDate && $0.timestamp ?? Date.distantFuture < currentPeriodEndDate }

        let previousPeriodBreathingLogs = breathingLogs.filter { $0.timestamp ?? Date.distantPast >= previousPeriodStartDate && $0.timestamp ?? Date.distantFuture < previousPeriodEndDate }
        
        let historicalCheckInsForAverage = checkIns.filter { ($0.checkInTime ?? Date.distantPast >= historicalAverageStartDate && $0.checkInTime ?? Date.distantFuture < historicalAverageEndDate) && $0.checkOutTime != nil }

        // --- Insight Rule 1: Total Work Hours & Breathing Balance (Personalized) ---
        let totalWorkHoursThisPeriod = currentPeriodCheckIns.reduce(0.0) { total, checkIn in
            guard let start = checkIn.checkInTime, let end = checkIn.checkOutTime else { return total }
            return total + end.timeIntervalSince(start) / 3600 // hours
        }
        let numberOfBreathingSessionsThisPeriod = currentPeriodBreathingLogs.count

        // Calculate historical average weekly work hours
        let totalHistoricalWorkHours = historicalCheckInsForAverage.reduce(0.0) { total, checkIn in
            guard let start = checkIn.checkInTime, let end = checkIn.checkOutTime else { return total }
            return total + end.timeIntervalSince(start) / 3600
        }
        let averageWeeklyWorkHoursHistorical = historicalWeeksForAverage > 0 ? totalHistoricalWorkHours / Double(historicalWeeksForAverage) : 0.0
        let workHoursThisPeriodFormatted = String(format: "%.1f", totalWorkHoursThisPeriod)

        if totalWorkHoursThisPeriod > 0 {
            // Compare to historical average if available, otherwise use fixed threshold
            let significantlyAboveAverage = averageWeeklyWorkHoursHistorical > 0 && totalWorkHoursThisPeriod > averageWeeklyWorkHoursHistorical * 1.2 // 20% above average
            let significantlyBelowAverage = averageWeeklyWorkHoursHistorical > 0 && totalWorkHoursThisPeriod < averageWeeklyWorkHoursHistorical * 0.8 // 20% below average

            if significantlyAboveAverage || (averageWeeklyWorkHoursHistorical == 0 && totalWorkHoursThisPeriod > maxWeeklyHoursThreshold) {
                // Condition for high workload
                if numberOfBreathingSessionsThisPeriod < minBreathingSessionsForHighWorkload {
                    generatedInsights.append(Insight(message: "You've logged \(workHoursThisPeriodFormatted) hours in the last \(days) days, which is more than usual for you (or above the typical threshold). We also noticed only \(numberOfBreathingSessionsThisPeriod) breathing session(s). Mindful breaks are key during intense periods. Consider one?", type: .suggestion, priority: 10))
                } else {
                    generatedInsights.append(Insight(message: "You've worked \(workHoursThisPeriodFormatted) hours in the last \(days) days—a significant amount. It's good to see you've included \(numberOfBreathingSessionsThisPeriod) breathing exercises. How is this balance feeling?", type: .question, priority: 5))
                }
            } else if significantlyBelowAverage {
                 generatedInsights.append(Insight(message: "Your work hours this past period (\(workHoursThisPeriodFormatted) hrs) were lower than your recent average. You also completed \(numberOfBreathingSessionsThisPeriod) breathing exercise(s). How did this change in pace affect you?", type: .question, priority: 2))
            } else {
                 // Around average or not enough historical data for strong comparison, but still some work done
                 generatedInsights.append(Insight(message: "This past period, you logged \(workHoursThisPeriodFormatted) work hours and completed \(numberOfBreathingSessionsThisPeriod) breathing exercise(s). How did this rhythm feel for you?", type: .question, priority: 2))
            }
        }
        
        // --- Insight Rule 2: Consistency of Breathing Exercises (using current period data) ---
        let minWorkHoursForNoBreathingInsight = averageWeeklyWorkHoursHistorical > 0 ? averageWeeklyWorkHoursHistorical * 0.20 : 5.0
        if totalWorkHoursThisPeriod > minWorkHoursForNoBreathingInsight && numberOfBreathingSessionsThisPeriod == 0 {
             generatedInsights.append(Insight(message: "Noticing you've been working but haven't logged any breathing exercises recently. Even a brief mindful pause can make a difference. Consider exploring one in the 'Breathe' tab.", type: .suggestion, priority: 3))
        } else if numberOfBreathingSessionsThisPeriod >= days / 2 && numberOfBreathingSessionsThisPeriod > 2 { // e.g., at least 3-4 for a week
            generatedInsights.append(Insight(message: "Consistent effort! You've used mindful breathing \(numberOfBreathingSessionsThisPeriod) times in the last \(days) days. Keep up the great practice for managing stress and enhancing focus.", type: .affirmation, priority: 4))
        }

        // --- Add more rules here ---

        // --- Insight Rule 3: Reflections on Focus & Stress (using current period data) ---
        let checkInsWithReflections = currentPeriodCheckIns.filter { ($0.focusRating ?? 0) > 0 || ($0.stressRating ?? 0) > 0 } // Use nil coalescing for optional Int16

        if !checkInsWithReflections.isEmpty {
            // Calculate averages only if count > 0 to avoid division by zero
            let reflectionCount = checkInsWithReflections.count
            let averageFocus: Int16 = reflectionCount > 0 ? checkInsWithReflections.compactMap { $0.focusRating }.reduce(0, +) / Int16(reflectionCount) : 0
            let averageStress: Int16 = reflectionCount > 0 ? checkInsWithReflections.compactMap { $0.stressRating }.reduce(0, +) / Int16(reflectionCount) : 0

            if averageFocus <= lowFocusThreshold && checkInsWithReflections.count >= minReflectionsForAverageInsight {
                generatedInsights.append(Insight(message: "Lately, your average focus rating after work sessions has been around \(averageFocus)/5. What factors do you think are influencing your concentration?", type: .question, priority: 6))
            }
            if averageStress >= highStressThreshold && checkInsWithReflections.count >= minReflectionsForAverageInsight {
                generatedInsights.append(Insight(message: "Your average stress rating recently is about \(averageStress)/5. Remember to utilize mindful moments and breaks. How are you managing stress levels this week?", type: .question, priority: 7))
            }

            // Insight for the most recent session with reflection
            if let lastReflectedSession = checkInsWithReflections.sorted(by: { $0.checkOutTime ?? Date.distantPast > $1.checkOutTime ?? Date.distantPast }).first {
                var reflectionMessages: [String] = []
                if lastReflectedSession.focusRating > 0 {
                    reflectionMessages.append("focus: \(lastReflectedSession.focusRating)/5")
                }
                if lastReflectedSession.stressRating > 0 {
                    reflectionMessages.append("stress: \(lastReflectedSession.stressRating)/5")
                }
                if !reflectionMessages.isEmpty {
                    let workplaceName = lastReflectedSession.workplace?.name ?? "your last workplace"
                    generatedInsights.append(Insight(message: "After your session at \(workplaceName), you noted (\(reflectionMessages.joined(separator: ", "))). Taking a moment to acknowledge these feelings is a great step.", type: .affirmation, priority: 5))
                }
                
                if let note = lastReflectedSession.sessionNote, !note.isEmpty {
                    generatedInsights.append(Insight(message: "You also noted: '\(note)'. Sometimes, writing things down can provide clarity. Does this note highlight anything important for you?", type: .question, priority: 4))
                }
            }
        }

        // e.g., Late night work, weekend work, work session length consistency etc.

        // --- Insight Rule 4: Trend in Breathing Exercise Usage (Enhanced) ---
        let numberOfBreathingSessionsPreviousPeriod = previousPeriodBreathingLogs.count

        // Only show trend if there's some data in at least one period to compare, or if user just started
        if numberOfBreathingSessionsThisPeriod > 0 || numberOfBreathingSessionsPreviousPeriod > 0 {
            let diff = numberOfBreathingSessionsThisPeriod - numberOfBreathingSessionsPreviousPeriod

            if diff > 1 { // Significantly more
                let messages = [
                    "Great progress! You've completed \(numberOfBreathingSessionsThisPeriod) breathing session(s) this period, up from \(numberOfBreathingSessionsPreviousPeriod). Keep building that mindful habit!",
                    "Nice increase in your mindful moments! \(numberOfBreathingSessionsThisPeriod) sessions this period (was \(numberOfBreathingSessionsPreviousPeriod)). That's the way!",
                    "Seeing more breathing exercises logged: \(numberOfBreathingSessionsThisPeriod) this period (prev: \(numberOfBreathingSessionsPreviousPeriod)). Fantastic commitment!"
                ]
                generatedInsights.append(Insight(message: Self.randomMessage(from: messages), type: .affirmation, priority: 6))
            } else if diff < -1 && numberOfBreathingSessionsPreviousPeriod > 1 { // Significantly less, and previous was not minimal
                let messages = [
                    "It looks like mindful breathing sessions decreased to \(numberOfBreathingSessionsThisPeriod) this period from \(numberOfBreathingSessionsPreviousPeriod). Anything making it harder to find those moments?",
                    "Noticing fewer breathing exercises lately (\(numberOfBreathingSessionsThisPeriod) vs \(numberOfBreathingSessionsPreviousPeriod) previously). How are you feeling about your routine?",
                    "Your breathing session count changed from \(numberOfBreathingSessionsPreviousPeriod) to \(numberOfBreathingSessionsThisPeriod). If you're aiming for consistency, what could help?"
                ]
                generatedInsights.append(Insight(message: Self.randomMessage(from: messages), type: .question, priority: 6))
            } else if abs(diff) <= 1 && numberOfBreathingSessionsThisPeriod > 1 && numberOfBreathingSessionsPreviousPeriod > 1 { // Stayed about the same, and was active
                let messages = [
                    "You've maintained a steady rhythm with \(numberOfBreathingSessionsThisPeriod) breathing session(s) this period, similar to the previous. Consistency is valuable!",
                    "Keeping up with your mindful moments: \(numberOfBreathingSessionsThisPeriod) sessions again this period. Well done!",
                    "Another period with around \(numberOfBreathingSessionsThisPeriod) breathing exercises. How is this consistency working for you?"
                ]
                generatedInsights.append(Insight(message: Self.randomMessage(from: messages), type: .affirmation, priority: 5))
            } else if numberOfBreathingSessionsThisPeriod > 0 && numberOfBreathingSessionsPreviousPeriod == 0 { // Started this period
                let messages = [
                    "Welcome to mindful breathing! You've completed \(numberOfBreathingSessionsThisPeriod) session(s) this period. A great start to a beneficial habit!",
                    "First breathing exercises logged! \(numberOfBreathingSessionsThisPeriod) session(s). How did you find them?",
                    "It's great to see you starting with \(numberOfBreathingSessionsThisPeriod) breathing session(s). Every moment counts!"
                ]
                generatedInsights.append(Insight(message: Self.randomMessage(from: messages), type: .affirmation, priority: 7)) // Higher priority for new habit
            }
        }

        // --- Insight Rule 5: Late Night Work ---
        var lateNightCount = 0
        for checkIn in currentPeriodCheckIns {
            if let checkOutTime = checkIn.checkOutTime {
                let hour = calendar.component(.hour, from: checkOutTime)
                if hour >= lateNightHourThreshold {
                    lateNightCount += 1
                }
            } else if let checkInTime = checkIn.checkInTime { // If still checked in, consider check-in time for ongoing late sessions
                 let hour = calendar.component(.hour, from: checkInTime)
                 if hour >= lateNightHourThreshold {
                    lateNightCount += 1
                 }
            }
        }

        if lateNightCount >= minLateNightsForInsight {
            let messages = [
                "Noticed \(lateNightCount) work session(s) extended past \(lateNightHourThreshold):00 this period. How is this impacting your rest?",
                "Seeing a pattern of late nights (\(lateNightCount) times). Remember that quality sleep is key for focus and well-being.",
                "\(lateNightCount) of your recent work sessions went into the late evening. Are you finding enough time to wind down?"
            ]
            generatedInsights.append(Insight(message: Self.randomMessage(from: messages), type: .question, priority: 5))
        }

        // --- Insight Rule 6: Weekend Work ---
        var weekendSessionCount = 0
        for checkIn in currentPeriodCheckIns {
            if let checkInTime = checkIn.checkInTime {
                let dayOfWeek = calendar.component(.weekday, from: checkInTime) // 1 = Sunday, 7 = Saturday
                if dayOfWeek == 1 || dayOfWeek == 7 {
                    weekendSessionCount += 1
                }
            }
        }

        if weekendSessionCount >= minWeekendSessionsForInsight {
            let messages = [
                "Saw \(weekendSessionCount) work session(s) logged over the weekend. Hope you're also finding time to recharge!",
                "Weekend work (\(weekendSessionCount) session(s) this period). How did this fit into your rest and personal time?",
                "Noticed some activity on the weekend (\(weekendSessionCount) session(s)). Is this helping you get ahead, or do you need more downtime?"
            ]
            // Use a slightly lower priority if it's just one session, could be normal for some
            let priority = weekendSessionCount > 1 ? 4 : 3 
            generatedInsights.append(Insight(message: Self.randomMessage(from: messages), type: .question, priority: Int16(priority)))
        }

        // --- Insight Rule 7: Session Duration vs. Reflection ---
        let checkInsWithReflectionData = currentPeriodCheckIns.filter { ($0.focusRating ?? 0) > 0 || ($0.stressRating ?? 0) > 0 }

        if checkInsWithReflectionData.count >= minSessionsForDurationCorrelationInsight * 2 { // Need enough data overall
            var longSessionFocusRatings: [Int16] = []
            var longSessionStressRatings: [Int16] = []
            var shortSessionFocusRatings: [Int16] = []
            var shortSessionStressRatings: [Int16] = []

            for checkIn in checkInsWithReflectionData {
                guard let start = checkIn.checkInTime, let end = checkIn.checkOutTime else { continue }
                let durationHours = end.timeIntervalSince(start) / 3600
                let focus = checkIn.focusRating ?? 0
                let stress = checkIn.stressRating ?? 0

                if durationHours >= longSessionDurationHours {
                    if focus > 0 { longSessionFocusRatings.append(focus) }
                    if stress > 0 { longSessionStressRatings.append(stress) }
                } else if durationHours <= shortSessionDurationHours {
                    if focus > 0 { shortSessionFocusRatings.append(focus) }
                    if stress > 0 { shortSessionStressRatings.append(stress) }
                }
            }

            // Focus: Long vs. Short
            if longSessionFocusRatings.count >= minSessionsForDurationCorrelationInsight && shortSessionFocusRatings.count >= minSessionsForDurationCorrelationInsight {
                let avgLongFocus = Double(longSessionFocusRatings.reduce(0, +)) / Double(longSessionFocusRatings.count)
                let avgShortFocus = Double(shortSessionFocusRatings.reduce(0, +)) / Double(shortSessionFocusRatings.count)

                if abs(avgLongFocus - avgShortFocus) >= Double(reflectionDifferenceThreshold) {
                    let comparison = avgLongFocus > avgShortFocus ? "higher" : "lower"
                    let messages = [
                        "When your sessions are longer (over \(Int(longSessionDurationHours)) hrs), your average focus is \(String(format: "%.1f", avgLongFocus))/5, compared to \(String(format: "%.1f", avgShortFocus))/5 for shorter sessions. Interesting pattern?",
                        "Noticing a difference: focus seems \(comparison) (avg \(String(format: "%.1f", avgLongFocus))) during long sessions vs. short ones (avg \(String(format: "%.1f", avgShortFocus))). Any thoughts?"
                    ]
                    generatedInsights.append(Insight(message: Self.randomMessage(from: messages), type: .question, priority: 4))
                }
            }
            // Stress: Long vs. Short
            if longSessionStressRatings.count >= minSessionsForDurationCorrelationInsight && shortSessionStressRatings.count >= minSessionsForDurationCorrelationInsight {
                let avgLongStress = Double(longSessionStressRatings.reduce(0, +)) / Double(longSessionStressRatings.count)
                let avgShortStress = Double(shortSessionStressRatings.reduce(0, +)) / Double(shortSessionStressRatings.count)

                if abs(avgLongStress - avgShortStress) >= Double(reflectionDifferenceThreshold) {
                    let comparison = avgLongStress > avgShortStress ? "higher" : "lower"
                    let messages = [
                        "For longer sessions, your average stress is \(String(format: "%.1f", avgLongStress))/5, versus \(String(format: "%.1f", avgShortStress))/5 for shorter ones. What does this suggest to you?",
                        "Stress levels appear \(comparison) (avg \(String(format: "%.1f", avgLongStress))) for long work periods compared to shorter ones (avg \(String(format: "%.1f", avgShortStress))). How does duration impact you?"
                    ]
                    generatedInsights.append(Insight(message: Self.randomMessage(from: messages), type: .question, priority: 4))
                }
            }
        }

        // --- Insight Rule 8: Same-Day Breathing & Reflection Correlation ---
        if !currentPeriodBreathingLogs.isEmpty && checkInsWithReflectionData.count >= minSessionsForBreathingCorrelationInsight * 2 {
            let breathingDays = Set(currentPeriodBreathingLogs.compactMap { log -> Date? in
                guard let timestamp = log.timestamp else { return nil }
                return calendar.startOfDay(for: timestamp)
            })

            var focusOnBreathingDays: [Int16] = []
            var stressOnBreathingDays: [Int16] = []
            var focusOnNonBreathingDays: [Int16] = []
            var stressOnNonBreathingDays: [Int16] = []

            for checkIn in checkInsWithReflectionData {
                guard let checkInTime = checkIn.checkInTime else { continue }
                let sessionDay = calendar.startOfDay(for: checkInTime)
                let focus = checkIn.focusRating ?? 0
                let stress = checkIn.stressRating ?? 0

                if breathingDays.contains(sessionDay) {
                    if focus > 0 { focusOnBreathingDays.append(focus) }
                    if stress > 0 { stressOnBreathingDays.append(stress) }
                } else {
                    if focus > 0 { focusOnNonBreathingDays.append(focus) }
                    if stress > 0 { stressOnNonBreathingDays.append(stress) }
                }
            }

            // Focus: Breathing Days vs. Non-Breathing Days
            if focusOnBreathingDays.count >= minSessionsForBreathingCorrelationInsight && focusOnNonBreathingDays.count >= minSessionsForBreathingCorrelationInsight {
                let avgFocusBreath = Double(focusOnBreathingDays.reduce(0, +)) / Double(focusOnBreathingDays.count)
                let avgFocusNoBreath = Double(focusOnNonBreathingDays.reduce(0, +)) / Double(focusOnNonBreathingDays.count)

                if abs(avgFocusBreath - avgFocusNoBreath) >= Double(reflectionDifferenceThreshold) {
                    let comparison = avgFocusBreath > avgFocusNoBreath ? "higher" : "lower"
                    let messages = [
                        "On days you log breathing exercises, your average focus is \(String(format: "%.1f", avgFocusBreath))/5, compared to \(String(format: "%.1f", avgFocusNoBreath))/5 on other days. Interesting link?",
                        "Your focus seems \(comparison) (avg \(String(format: "%.1f", avgFocusBreath))) on days with mindful breathing, vs. days without (avg \(String(format: "%.1f", avgFocusNoBreath))). What's your experience?"
                    ]
                    generatedInsights.append(Insight(message: Self.randomMessage(from: messages), type: .question, priority: 5))
                }
            }

            // Stress: Breathing Days vs. Non-Breathing Days
            if stressOnBreathingDays.count >= minSessionsForBreathingCorrelationInsight && stressOnNonBreathingDays.count >= minSessionsForBreathingCorrelationInsight {
                let avgStressBreath = Double(stressOnBreathingDays.reduce(0, +)) / Double(stressOnBreathingDays.count)
                let avgStressNoBreath = Double(stressOnNonBreathingDays.reduce(0, +)) / Double(stressOnNonBreathingDays.count)

                if abs(avgStressBreath - avgStressNoBreath) >= Double(reflectionDifferenceThreshold) {
                    let comparison = avgStressBreath < avgStressNoBreath ? "lower" : "higher" // Lower stress is better
                    let messages = [
                        "Average stress on breathing exercise days is \(String(format: "%.1f", avgStressBreath))/5, vs. \(String(format: "%.1f", avgStressNoBreath))/5 on days without. Does mindfulness help your stress?",
                        "Stress levels appear \(comparison) (avg \(String(format: "%.1f", avgStressBreath))) on days you use breathing exercises, compared to days you don't (avg \(String(format: "%.1f", avgStressNoBreath))). Food for thought?"
                    ]
                    generatedInsights.append(Insight(message: Self.randomMessage(from: messages), type: .question, priority: 5))
                }
            }
        }

        // --- Insight Rule 9: Prompt for Reflection if Data is Sparse ---
        let completedCheckInsInPeriod = currentPeriodCheckIns.filter { $0.checkOutTime != nil }
        let reflectionsMadeInPeriod = completedCheckInsInPeriod.filter { ($0.focusRating ?? 0) > 0 || ($0.stressRating ?? 0) > 0 }.count

        if completedCheckInsInPeriod.count >= minCompletedSessionsForReflectionPrompt && reflectionsMadeInPeriod <= maxReflectionsForReflectionPrompt {
            let messages = [
                "Noticing you haven't logged reflections after your recent work sessions. These quick notes on focus & stress can unlock deeper insights into your work patterns. Try it next time!",
                "Curious about how your sessions are impacting you? Adding a reflection on focus and stress after checkout can provide valuable personal data for Fathom's insights.",
                "Unlock more personalized feedback by adding a reflection (focus/stress rating) when you check out. It only takes a moment!"
            ]
            generatedInsights.append(Insight(message: Self.randomMessage(from: messages), type: .suggestion, priority: 3)) // Lower priority, gentle nudge
        }

        // --- Insight Rule 10: Workplace-Specific Reflection Patterns ---
        struct WorkplaceReflectionStats {
            let name: String
            var focusRatings: [Int16] = []
            var stressRatings: [Int16] = []
            var avgFocus: Double { focusRatings.isEmpty ? 0 : Double(focusRatings.reduce(0, +)) / Double(focusRatings.count) }
            var avgStress: Double { stressRatings.isEmpty ? 0 : Double(stressRatings.reduce(0, +)) / Double(stressRatings.count) }
        }

        var statsByWorkplace: [String: WorkplaceReflectionStats] = [:]

        for checkIn in checkInsWithReflectionData { // Assumes checkInsWithReflectionData is already defined and filtered
            guard let workplace = checkIn.workplace, let workplaceName = workplace.name else { continue }
            
            statsByWorkplace[workplaceName, default: WorkplaceReflectionStats(name: workplaceName)].focusRatings.append(checkIn.focusRating ?? 0)
            statsByWorkplace[workplaceName, default: WorkplaceReflectionStats(name: workplaceName)].stressRatings.append(checkIn.stressRating ?? 0)
        }

        let validWorkplaceStats = statsByWorkplace.values.filter {
            ($0.focusRatings.filter{$0 > 0}.count >= minSessionsPerWorkplaceForCorrelation || 
             $0.stressRatings.filter{$0 > 0}.count >= minSessionsPerWorkplaceForCorrelation)
        }

        if validWorkplaceStats.count >= minWorkplacesForComparison {
            // Simple pairwise comparison for now. More complex ranking could be done.
            for i in 0..<validWorkplaceStats.count {
                for j in (i + 1)..<validWorkplaceStats.count {
                    let wp1 = validWorkplaceStats[i]
                    let wp2 = validWorkplaceStats[j]

                    // Compare Focus
                    if wp1.focusRatings.filter({$0 > 0}).count >= minSessionsPerWorkplaceForCorrelation && wp2.focusRatings.filter({$0 > 0}).count >= minSessionsPerWorkplaceForCorrelation {
                        if abs(wp1.avgFocus - wp2.avgFocus) >= Double(reflectionDifferenceThreshold) {
                            let higherFocusWP = wp1.avgFocus > wp2.avgFocus ? wp1 : wp2
                            let lowerFocusWP = wp1.avgFocus > wp2.avgFocus ? wp2 : wp1
                            let messages = [
                                "Your average focus at '\(higherFocusWP.name)' (\(String(format: "%.1f", higherFocusWP.avgFocus))/5) seems different from '\(lowerFocusWP.name)' (\(String(format: "%.1f", lowerFocusWP.avgFocus))/5). Any thoughts on why?",
                                "Noticing a focus difference: \(String(format: "%.1f", higherFocusWP.avgFocus))/5 at '\(higherFocusWP.name)' vs. \(String(format: "%.1f", lowerFocusWP.avgFocus))/5 at '\(lowerFocusWP.name)'. What makes one place more conducive to focus?"
                            ]
                            generatedInsights.append(Insight(message: Self.randomMessage(from: messages), type: .question, priority: 4))
                        }
                    }

                    // Compare Stress
                    if wp1.stressRatings.filter({$0 > 0}).count >= minSessionsPerWorkplaceForCorrelation && wp2.stressRatings.filter({$0 > 0}).count >= minSessionsPerWorkplaceForCorrelation {
                        if abs(wp1.avgStress - wp2.avgStress) >= Double(reflectionDifferenceThreshold) {
                            let higherStressWP = wp1.avgStress > wp2.avgStress ? wp1 : wp2
                            let lowerStressWP = wp1.avgStress > wp2.avgStress ? wp2 : wp1
                            let messages = [
                                "Stress levels appear to differ: \(String(format: "%.1f", higherStressWP.avgStress))/5 at '\(higherStressWP.name)' compared to \(String(format: "%.1f", lowerStressWP.avgStress))/5 at '\(lowerStressWP.name)'. What factors might be at play?",
                                "Is '\(higherStressWP.name)' (avg stress \(String(format: "%.1f", higherStressWP.avgStress))) more stressful for you than '\(lowerStressWP.name)' (avg stress \(String(format: "%.1f", lowerStressWP.avgStress)))? Your reflections suggest a difference."
                            ]
                            generatedInsights.append(Insight(message: Self.randomMessage(from: messages), type: .question, priority: 4))
                        }
                    }
                }
            }
        }

        // --- Insight Rule 11: Time of Day of Work Session vs. Reflection ---
        enum TimeBlock: String, CaseIterable {
            case morning = "Morning (6 AM - 12 PM)"
            case afternoon = "Afternoon (12 PM - 6 PM)"
            case evening = "Evening (6 PM - 10 PM)"
        }
        struct TimeBlockReflectionStats {
            let block: TimeBlock
            var focusRatings: [Int16] = []
            var stressRatings: [Int16] = []
            var avgFocus: Double { focusRatings.isEmpty ? 0 : Double(focusRatings.reduce(0, +)) / Double(focusRatings.count) }
            var avgStress: Double { stressRatings.isEmpty ? 0 : Double(stressRatings.reduce(0, +)) / Double(stressRatings.count) }
        }

        var statsByTimeBlock: [TimeBlock: TimeBlockReflectionStats] = [
            .morning: TimeBlockReflectionStats(block: .morning),
            .afternoon: TimeBlockReflectionStats(block: .afternoon),
            .evening: TimeBlockReflectionStats(block: .evening)
        ]

        for checkIn in checkInsWithReflectionData {
            guard let startTime = checkIn.checkInTime else { continue }
            let hour = calendar.component(.hour, from: startTime)
            var currentBlock: TimeBlock?

            if hour >= 6 && hour < morningBlockEndHour {
                currentBlock = .morning
            } else if hour >= morningBlockEndHour && hour < afternoonBlockEndHour {
                currentBlock = .afternoon
            } else if hour >= afternoonBlockEndHour && hour < lateNightHourThreshold { // Avoid overlap with late night rule
                currentBlock = .evening
            }

            if let block = currentBlock {
                if let focus = checkIn.focusRating, focus > 0 {
                    statsByTimeBlock[block]?.focusRatings.append(focus)
                }
                if let stress = checkIn.stressRating, stress > 0 {
                    statsByTimeBlock[block]?.stressRatings.append(stress)
                }
            }
        }

        let validTimeBlockStats = statsByTimeBlock.values.filter {
            ($0.focusRatings.count >= minSessionsPerTimeBlockForCorrelation || 
             $0.stressRatings.count >= minSessionsPerTimeBlockForCorrelation)
        }.sorted(by: { $0.block.rawValue < $1.block.rawValue })

        if validTimeBlockStats.count >= 2 { // Need at least two blocks with enough data to compare
            for i in 0..<validTimeBlockStats.count {
                for j in (i + 1)..<validTimeBlockStats.count {
                    let block1Stats = validTimeBlockStats[i]
                    let block2Stats = validTimeBlockStats[j]

                    // Compare Focus
                    if block1Stats.focusRatings.count >= minSessionsPerTimeBlockForCorrelation && block2Stats.focusRatings.count >= minSessionsPerTimeBlockForCorrelation {
                        if abs(block1Stats.avgFocus - block2Stats.avgFocus) >= Double(reflectionDifferenceThreshold) {
                            let higherFocusBlock = block1Stats.avgFocus > block2Stats.avgFocus ? block1Stats : block2Stats
                            let lowerFocusBlock = block1Stats.avgFocus > block2Stats.avgFocus ? block2Stats : block1Stats
                            let messages = [
                                "Focus seems to vary by time of day: avg \(String(format: "%.1f", higherFocusBlock.avgFocus))/5 in the \(higherFocusBlock.block.rawValue.components(separatedBy: " ").first!.lowercased()) vs. \(String(format: "%.1f", lowerFocusBlock.avgFocus))/5 in the \(lowerFocusBlock.block.rawValue.components(separatedBy: " ").first!.lowercased()). Any patterns here for you?",
                                "Your reflections suggest focus is \(higherFocusBlock.avgFocus > lowerFocusBlock.avgFocus ? "higher" : "lower") in the \(higherFocusBlock.block.rawValue.components(separatedBy: " ").first!.lowercased()) (avg \(String(format: "%.1f", higherFocusBlock.avgFocus))) compared to the \(lowerFocusBlock.block.rawValue.components(separatedBy: " ").first!.lowercased()) (avg \(String(format: "%.1f", lowerFocusBlock.avgFocus))). What's your take?"
                            ]
                            generatedInsights.append(Insight(message: Self.randomMessage(from: messages), type: .question, priority: 4))
                        }
                    }

                    // Compare Stress
                    if block1Stats.stressRatings.count >= minSessionsPerTimeBlockForCorrelation && block2Stats.stressRatings.count >= minSessionsPerTimeBlockForCorrelation {
                        if abs(block1Stats.avgStress - block2Stats.avgStress) >= Double(reflectionDifferenceThreshold) {
                            let higherStressBlock = block1Stats.avgStress > block2Stats.avgStress ? block1Stats : block2Stats
                            let lowerStressBlock = block1Stats.avgStress > block2Stats.avgStress ? block2Stats : block1Stats
                            let messages = [
                                "Stress levels by time of day: seeing avg \(String(format: "%.1f", higherStressBlock.avgStress))/5 in the \(higherStressBlock.block.rawValue.components(separatedBy: " ").first!.lowercased()) and \(String(format: "%.1f", lowerStressBlock.avgStress))/5 in the \(lowerStressBlock.block.rawValue.components(separatedBy: " ").first!.lowercased()). Does this resonate?",
                                "Is the \(higherStressBlock.block.rawValue.components(separatedBy: " ").first!.lowercased()) (avg stress \(String(format: "%.1f", higherStressBlock.avgStress))) typically more stressful than the \(lowerStressBlock.block.rawValue.components(separatedBy: " ").first!.lowercased()) (avg stress \(String(format: "%.1f", lowerStressBlock.avgStress))) for you?"
                            ]
                            generatedInsights.append(Insight(message: Self.randomMessage(from: messages), type: .question, priority: 4))
                        }
                    }
                }
            }
        }

        // --- Insight Rule 12: Day of the Week vs. Reflection ---
        struct DayOfWeekReflectionStats {
            let dayName: String
            let dayOfWeek: Int // 1 (Sun) to 7 (Sat)
            var focusRatings: [Int16] = []
            var stressRatings: [Int16] = []
            var avgFocus: Double { focusRatings.isEmpty ? 0 : Double(focusRatings.reduce(0, +)) / Double(focusRatings.count) }
            var avgStress: Double { stressRatings.isEmpty ? 0 : Double(stressRatings.reduce(0, +)) / Double(stressRatings.count) }
        }

        var statsByDayOfWeek: [Int: DayOfWeekReflectionStats] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE" // Full day name, e.g., "Monday"

        for checkIn in checkInsWithReflectionData {
            guard let startTime = checkIn.checkInTime else { continue }
            let dayOfWeek = calendar.component(.weekday, from: startTime)
            let dayName = dateFormatter.string(from: startTime)

            if statsByDayOfWeek[dayOfWeek] == nil {
                statsByDayOfWeek[dayOfWeek] = DayOfWeekReflectionStats(dayName: dayName, dayOfWeek: dayOfWeek)
            }
            if let focus = checkIn.focusRating, focus > 0 {
                statsByDayOfWeek[dayOfWeek]?.focusRatings.append(focus)
            }
            if let stress = checkIn.stressRating, stress > 0 {
                statsByDayOfWeek[dayOfWeek]?.stressRatings.append(stress)
            }
        }

        let validDayStats = statsByDayOfWeek.values.filter {
            ($0.focusRatings.count >= minSessionsPerDayForCorrelation || 
             $0.stressRatings.count >= minSessionsPerDayForCorrelation)
        }.sorted(by: { $0.dayOfWeek < $1.dayOfWeek })

        if validDayStats.count >= 2 { // Need at least two different days with enough data
            for i in 0..<validDayStats.count {
                for j in (i + 1)..<validDayStats.count {
                    let day1Stats = validDayStats[i]
                    let day2Stats = validDayStats[j]

                    // Compare Focus
                    if day1Stats.focusRatings.count >= minSessionsPerDayForCorrelation && day2Stats.focusRatings.count >= minSessionsPerDayForCorrelation {
                        if abs(day1Stats.avgFocus - day2Stats.avgFocus) >= Double(reflectionDifferenceThreshold) {
                            let higherFocusDay = day1Stats.avgFocus > day2Stats.avgFocus ? day1Stats : day2Stats
                            let lowerFocusDay = day1Stats.avgFocus > day2Stats.avgFocus ? day2Stats : day1Stats
                            let messages = [
                                "On \(higherFocusDay.dayName)s, your average focus is \(String(format: "%.1f", higherFocusDay.avgFocus))/5, compared to \(String(format: "%.1f", lowerFocusDay.avgFocus))/5 on \(lowerFocusDay.dayName)s. See a pattern?",
                                "Your reflections hint that focus might be different on \(higherFocusDay.dayName)s (avg \(String(format: "%.1f", higherFocusDay.avgFocus))) vs. \(lowerFocusDay.dayName)s (avg \(String(format: "%.1f", lowerFocusDay.avgFocus))). What do you think?"
                            ]
                            generatedInsights.append(Insight(message: Self.randomMessage(from: messages), type: .question, priority: 4))
                        }
                    }

                    // Compare Stress
                    if day1Stats.stressRatings.count >= minSessionsPerDayForCorrelation && day2Stats.stressRatings.count >= minSessionsPerDayForCorrelation {
                        if abs(day1Stats.avgStress - day2Stats.avgStress) >= Double(reflectionDifferenceThreshold) {
                            let higherStressDay = day1Stats.avgStress > day2Stats.avgStress ? day1Stats : day2Stats
                            let lowerStressDay = day1Stats.avgStress > day2Stats.avgStress ? day2Stats : day1Stats
                            let messages = [
                                "Average stress on \(higherStressDay.dayName)s (\(String(format: "%.1f", higherStressDay.avgStress))/5) seems different from \(lowerStressDay.dayName)s (\(String(format: "%.1f", lowerStressDay.avgStress))/5). Does your week have a rhythm to it?",
                                "Are \(higherStressDay.dayName)s (avg stress \(String(format: "%.1f", higherStressDay.avgStress))) generally more stressful for you than \(lowerStressDay.dayName)s (avg stress \(String(format: "%.1f", lowerStressDay.avgStress)))?"
                            ]
                            generatedInsights.append(Insight(message: Self.randomMessage(from: messages), type: .question, priority: 4))
                        }
                    }
                }
            }
        }

        // Sort insights by priority (descending)
        return generatedInsights.sorted { $0.priority > $1.priority }
    }
}
