import SwiftUI
import CoreData

struct InsightsView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingPaywall = false

    // FetchRequest for CheckIn entities
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \WorkplaceCheckIn.checkInTime, ascending: false)],
        animation: .default)
    private var checkInLogs: FetchedResults<WorkplaceCheckIn>

    // FetchRequest for BreathingExercise entities
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \BreathingExercise.completedAt, ascending: false)],
        animation: .default)
    private var breathingLogs: FetchedResults<BreathingExercise>

    // Access to journal entries
    @StateObject private var journalStore = WorkplaceJournalStore.shared

    // Access to user goals
    @StateObject private var goalsManager = UserGoalsManager.shared

    // Date range for filtering (e.g., last 7 days)
    private var sevenDaysAgo: Date {
        Calendar.current.date(byAdding: .day, value: -7, to: Date())!
    }

    // Instance of the InsightEngine
    private let insightEngine = InsightEngine()

    private var recentCheckInLogs: [WorkplaceCheckIn] {
        checkInLogs.filter { $0.checkInTime ?? Date() >= sevenDaysAgo && $0.checkOutTime != nil }
    }

    private var totalWorkHoursLast7Days: Double {
        recentCheckInLogs.reduce(0) { total, checkIn in
            guard let checkInTime = checkIn.checkInTime, let checkOutTime = checkIn.checkOutTime else {
                return total
            }
            let durationInSeconds = checkOutTime.timeIntervalSince(checkInTime)
            return total + (durationInSeconds / 3600) // Convert seconds to hours
        }
    }

    var body: some View {
        NavigationView {
            Group {
                if subscriptionManager.isProUser {
                    // Placeholder for actual insights content
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Header with period info
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Your Insights")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                Text("Based on your activity from the last 7 days")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            
                            // Generate insights using the engine
                            let insights = insightEngine.generateInsights(
                                checkIns: Array(recentCheckInLogs),
                                breathingLogs: Array(breathingLogs),
                                journalEntries: journalStore.entries,
                                goals: goalsManager.goals,
                                forLastDays: 7
                            )
                            
                            // Group insights by priority and type
                            let priorityInsights = insights.filter { $0.priority >= 5 }.sorted { $0.priority > $1.priority }
                            let generalInsights = insights.filter { $0.priority < 5 }.sorted { $0.priority > $1.priority }
                            let goalInsights = insights.filter { $0.message.contains("🎯") }
                            let otherInsights = insights.filter { !$0.message.contains("🎯") && $0.priority < 5 }
                            
                            // High Priority Insights Section
                            if !priorityInsights.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                        Text("Key Insights")
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                    }
                                    .padding(.horizontal)
                                    
                                    LazyVStack(spacing: 12) {
                                        ForEach(priorityInsights) { insight in
                                            InsightCardView(insight: insight)
                                                .padding(.horizontal)
                                        }
                                    }
                                }
                            }
                            
                            // Goals Progress Section
                            if !goalInsights.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "target")
                                            .foregroundColor(.blue)
                                        Text("Goal Progress")
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                    }
                                    .padding(.horizontal)
                                    
                                    LazyVStack(spacing: 12) {
                                        ForEach(goalInsights) { insight in
                                            InsightCardView(insight: insight)
                                                .padding(.horizontal)
                                        }
                                    }
                                }
                            }
                            
                            // Enhanced Weekly Progress Section
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .foregroundColor(.green)
                                    Text("Your Week at a Glance")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal)
                                
                                VStack(spacing: 16) {
                                    // Work hours with progress bar
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "clock.fill")
                                                .foregroundColor(.blue)
                                                .frame(width: 20)
                                            Text("Total Work Time")
                                            Spacer()
                                            Text("\(totalWorkHoursLast7Days, specifier: "%.1f") hours")
                                                .fontWeight(.semibold)
                                        }
                                        
                                        ProgressView(value: min(totalWorkHoursLast7Days / 40.0, 1.0))
                                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                        
                                        HStack {
                                            Text("Target: 40 hours")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text("\(Int((totalWorkHoursLast7Days / 40.0) * 100))%")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Divider()
                                    
                                    // Breathing sessions with visual indicator
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "lungs.fill")
                                                .foregroundColor(.green)
                                                .frame(width: 20)
                                            Text("Breathing Sessions")
                                            Spacer()
                                            Text("\(breathingLogs.count)")
                                                .fontWeight(.semibold)
                                        }
                                        
                                        let breathingTarget = 5.0
                                        ProgressView(value: min(Double(breathingLogs.count) / breathingTarget, 1.0))
                                            .progressViewStyle(LinearProgressViewStyle(tint: .green))
                                        
                                        HStack {
                                            Text("Weekly goal: \(Int(breathingTarget)) sessions")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text("\(Int((Double(breathingLogs.count) / breathingTarget) * 100))%")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Divider()
                                    
                                    // Reflections tracking
                                    let reflectionCount = checkInLogs.filter { $0.sessionNote != nil && !$0.sessionNote!.isEmpty }.count
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "doc.text.fill")
                                                .foregroundColor(.purple)
                                                .frame(width: 20)
                                            Text("Session Reflections")
                                            Spacer()
                                            Text("\(reflectionCount)")
                                                .fontWeight(.semibold)
                                        }
                                        
                                        let reflectionTarget = Double(recentCheckInLogs.count)
                                        if reflectionTarget > 0 {
                                            ProgressView(value: Double(reflectionCount) / reflectionTarget)
                                                .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                                            
                                            HStack {
                                                Text("Reflection rate")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                Spacer()
                                                Text("\(Int((Double(reflectionCount) / reflectionTarget) * 100))%")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    
                                    Divider()
                                    
                                    // Journal entries
                                    HStack {
                                        Image(systemName: "book.fill")
                                            .foregroundColor(.orange)
                                            .frame(width: 20)
                                        Text("Journal Entries")
                                        Spacer()
                                        VStack(alignment: .trailing) {
                                            Text("\(journalStore.entries.count)")
                                                .fontWeight(.semibold)
                                            Text("this week")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                            
                            // Other Insights Section
                            if !otherInsights.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "lightbulb.fill")
                                            .foregroundColor(.yellow)
                                        Text("Additional Insights")
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                    }
                                    .padding(.horizontal)
                                    
                                    LazyVStack(spacing: 12) {
                                        ForEach(otherInsights) { insight in
                                            InsightCardView(insight: insight)
                                                .padding(.horizontal)
                                        }
                                    }
                                }
                            }
                            
                            // Fallback message if no insights
                            if insights.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "chart.bar.doc.horizontal")
                                        .font(.system(size: 50))
                                        .foregroundColor(.secondary)
                                    
                                    Text("Building Your Insights")
                                        .font(.title3)
                                        .fontWeight(.medium)
                                    
                                    Text("Keep tracking your work sessions, reflections, and breathing exercises to unlock personalized insights about your productivity patterns.")
                                        .multilineTextAlignment(.center)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal)
                                }
                                .padding(.vertical, 40)
                            }
                        }
                        .padding(.vertical)
                    }
                } else {
                    // Upsell for non-Pro users
                    VStack(spacing: 20) {
                        Image(systemName: "chart.bar.xaxis.ascending") // Or a more relevant icon
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        Text("Unlock Your Personalized Insights")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Understand your work patterns, manage stress, and boost your productivity with Fathom Pro.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button {
                            showingPaywall.toggle()
                        } label: {
                            Text("Upgrade to Fathom Pro")
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal, 40)
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle("Your Fathom Insights")
            .sheet(isPresented: $showingPaywall) {
                PaywallView_Workplace()
                    .environmentObject(subscriptionManager)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Use StackNavigationViewStyle for a standard full-screen view
    }
}

// MARK: - Insight Card View
struct InsightCardView: View {
    let insight: Insight

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconForInsightType(insight.type))
                    .font(.title3)
                    .foregroundColor(colorForInsightType(insight.type))
                Text(insight.type.rawValue)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                Spacer()
                // Optionally show priority or a subtle indicator
            }
            Text(insight.message)
                .font(.body)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
    }

    private func iconForInsightType(_ type: InsightType) -> String {
        switch type {
        case .observation: return "eye.fill"
        case .question: return "questionmark.circle.fill"
        case .suggestion: return "lightbulb.fill"
        case .affirmation: return "star.fill"
        case .alert: return "exclamationmark.triangle.fill"
        case .prediction: return "crystal.ball.fill"
        case .anomaly: return "waveform.path.ecg"
        }
    }

    private func colorForInsightType(_ type: InsightType) -> Color {
        switch type {
        case .observation: return .blue
        case .question: return .purple
        case .suggestion: return .orange
        case .affirmation: return .green
        case .alert: return .red
        case .prediction: return .indigo
        case .anomaly: return .pink
        }
    }
}

// MARK: - Preview
struct InsightsView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock SubscriptionManager for preview
        let mockSubscriptionManager = SubscriptionManager()
        // To preview the Pro view:
        // mockSubscriptionManager.isProUser = true 

        InsightsView()
            .environmentObject(mockSubscriptionManager)
    }
}
