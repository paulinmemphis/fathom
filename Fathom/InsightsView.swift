import SwiftUI
import CoreData

struct InsightsView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingPaywall = false
    @StateObject private var personalizationEngine = PersonalizationEngine.shared
    
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

    @State private var insights: [Insight] = []
    @State private var showingPersonalizationSettings = false
    @State private var interactionHistory: [UUID: (dismissed: Bool, actionTaken: Bool)] = [:]

    private let analytics = AnalyticsService.shared

    @State private var userRole: WorkRole = .developer
    @State private var userIndustry: WorkIndustry = .technology
    @State private var currentComplexity: InsightComplexity = .intermediate

    var body: some View {
        NavigationView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if subscriptionManager.isProUser {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Header with personalization button
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Your Insights")
                                        .font(.largeTitle)
                                        .fontWeight(.bold)
                                    
                                    Text("Personalized for \(userRole.rawValue) in \(userIndustry.rawValue)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button {
                                    showingPersonalizationSettings = true
                                } label: {
                                    Image(systemName: "brain.head.profile")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal)
                            
                            // Insights complexity indicator
                            PersonalizationStatusView(complexity: currentComplexity)
                                .padding(.horizontal)
                            
                            if insights.isEmpty {
                                // Loading or empty state
                                VStack(spacing: 16) {
                                    ProgressView()
                                    Text("Generating personalized insights...")
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                // Personalized insights display
                                LazyVStack(spacing: 16) {
                                    ForEach(insights) { insight in
                                        PersonalizedInsightCard(
                                            insight: insight,
                                            onDismiss: {
                                                handleInsightInteraction(insight, dismissed: true, actionTaken: false)
                                            },
                                            onAction: {
                                                handleInsightInteraction(insight, dismissed: false, actionTaken: true)
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                } else {
                    // Paywall for non-Pro users
                    VStack(spacing: 20) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 64))
                            .foregroundColor(.blue)
                        
                        Text("Personalized Insights")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Unlock AI-powered, personalized insights that adapt to your unique work patterns and preferences.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        Button("Upgrade to Pro") {
                            showingPaywall = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadPersonalizedInsights()
                Task {
                    userRole = await personalizationEngine.getCurrentUserRole()
                    userIndustry = await personalizationEngine.getCurrentUserIndustry()
                    currentComplexity = await personalizationEngine.getCurrentInsightComplexity()
                }
            }
            .refreshable {
                loadPersonalizedInsights()
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView_Workplace()
        }
        .sheet(isPresented: $showingPersonalizationSettings) {
            PersonalizationSettingsView()
        }
    }
    
    private func loadPersonalizedInsights() {
        Task {
            let checkInsArray = Array(checkInLogs)
            let breathingArray = Array(breathingLogs)
            let journalEntries = journalStore.entries
            let goals = goalsManager.goals
            
            // Generate insights using PersonalizationEngine
            let insights = await personalizationEngine.generatePersonalizedInsights(
                checkIns: checkInsArray,
                breathingLogs: breathingArray,
                journalEntries: journalEntries,
                goals: goals,
                forLastDays: 7
            )
            
            await MainActor.run {
                // Filter out any insights that were previously dismissed
                let filteredInsights = insights.filter { insight in
                    !(interactionHistory[insight.id]?.dismissed ?? false)
                }
                self.insights = filteredInsights
            }
        }
    }
    
    private func handleInsightInteraction(_ insight: Insight, dismissed: Bool, actionTaken: Bool) {
        // Track interaction for personalization
        Task {
            await personalizationEngine.recordInteraction(for: insight.type, action: dismissed ? .dismissed : actionTaken ? .actionTaken : .viewed)
        }
        
        // Store interaction history
        interactionHistory[insight.id] = (dismissed: dismissed, actionTaken: actionTaken)
        
        // Log analytics
        AnalyticsService.shared.logEvent("insight_interaction", parameters: [
            "insight_message": insight.message,
            "action": dismissed ? "dismissed" : actionTaken ? "action_taken" : "viewed"
        ])
        
        // Remove insight from display if dismissed
        if dismissed {
            insights.removeAll { $0.id == insight.id }
        }
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
        case .warning: return "exclamationmark.triangle"
        case .celebration: return "party.popper"
        case .trend: return "chart.line.uptrend.xyaxis"
        case .correlation: return "link"
        case .goalProgress: return "target"
        case .workplaceSpecific: return "building.2"
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
        case .warning: return .red
        case .celebration: return .green
        case .trend: return .blue
        case .correlation: return .purple
        case .goalProgress: return .orange
        case .workplaceSpecific: return .blue
        }
    }
}

// MARK: - Supporting Views

struct PersonalizationStatusView: View {
    let complexity: InsightComplexity
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Insight Level")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(complexity.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                ForEach(1...4, id: \.self) { level in
                    Circle()
                        .fill(level <= complexity.intValue ? Color.blue : Color(.systemGray5))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct PersonalizedInsightCard: View {
    let insight: Insight
    let onDismiss: () -> Void
    let onAction: () -> Void
    
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with insight type and priority
            HStack {
                HStack(spacing: 6) {
                    insightTypeIcon
                    Text(insight.type.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if insight.confidence < 1.0 {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.fill")
                            .font(.caption2)
                        Text("\(Int(insight.confidence * 100))%")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            // Insight message
            Text(insight.message)
                .font(.body)
                .lineLimit(showingDetails ? nil : 3)
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Dismiss") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.secondary)
                
                if insight.type == .suggestion || insight.type == .alert {
                    Button("Take Action") {
                        onAction()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Spacer()
                
                if insight.message.count > 150 {
                    Button(showingDetails ? "Show Less" : "Show More") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingDetails.toggle()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(priorityColor, lineWidth: 2)
                .opacity(insight.priority >= 7 ? 1 : 0)
        )
    }
    
    private var insightTypeIcon: some View {
        VStack {
            switch insight.type {
            case .observation:
                Image(systemName: "eye.fill")
                    .foregroundColor(.blue)
            case .suggestion:
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.orange)
            case .alert:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            case .affirmation:
                Image(systemName: "heart.fill")
                    .foregroundColor(.pink)
            case .prediction:
                Image(systemName: "crystal.ball.fill")
                    .foregroundColor(.purple)
            case .anomaly:
                Image(systemName: "questionmark.diamond.fill")
                    .foregroundColor(.red)
            case .warning:
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
            case .celebration:
                Image(systemName: "party.popper")
                    .foregroundColor(.green)
            case .trend:
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.blue)
            case .correlation:
                Image(systemName: "link")
                    .foregroundColor(.purple)
            case .goalProgress:
                Image(systemName: "target")
                    .foregroundColor(.orange)
            case .workplaceSpecific:
                Image(systemName: "building.2")
                    .foregroundColor(.blue)
            default:
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.gray)
            }
        }
        .font(.caption)
    }
    
    private var priorityColor: Color {
        switch insight.priority {
        case 8...10:
            return .red
        case 6...7:
            return .orange
        case 4...5:
            return .yellow
        default:
            return .clear
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
