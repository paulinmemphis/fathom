import SwiftUI
import CoreData

// Main Insights View
struct InsightsView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingPaywall = false
    @StateObject private var personalizationEngine = PersonalizationEngine.shared
    
    // FetchRequest for CheckIn entities
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Fathom.WorkplaceCheckIn.checkInTime, ascending: false)],
        animation: .default)
    private var checkInLogs: FetchedResults<Fathom.WorkplaceCheckIn>
    
    // FetchRequest for BreathingExercise entities
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Fathom.BreathingExercise.completedAt, ascending: false)],
        animation: .default)
    private var breathingLogs: FetchedResults<Fathom.BreathingExercise>

    // Access to journal entries
    @StateObject private var journalStore = WorkplaceJournalStore.shared

    // Access to user goals
    @StateObject private var goalsManager = UserGoalsManager.shared

    @State private var insights: [AppInsight] = []
    @State private var showingPersonalizationSettings = false // This might be unused if settings are in onboarding
    @State private var interactionHistory: [UUID: (dismissed: Bool, actionTaken: Bool)] = [:]

    @State private var userRole: WorkRole = .developer // Default, will be updated from PersonalizationEngine
    @State private var userIndustry: WorkIndustry = .technology // Default
    @State private var currentComplexity: InsightComplexity = .intermediate // Default
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var body: some View {
        NavigationView {
            Group {
                if subscriptionManager.isProUser {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Header
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
                            }
                            .padding(.horizontal)
                            
                            PersonalizationStatusView(complexity: currentComplexity)
                                .padding(.horizontal)
                            
                            if insights.isEmpty {
                                EmptyInsightsView()
                            } else {
                                InsightGridView(insights: insights, horizontalSizeClass: horizontalSizeClass, interactionHandler: handleInsightInteraction)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                } else {
                    PaywallContent(showingPaywall: $showingPaywall, horizontalSizeClass: horizontalSizeClass)
                }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.automatic)
            .onAppear {
                loadPersonalizedInsights()
            }
            .refreshable {
                loadPersonalizedInsights()
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView_Workplace()
                .environmentObject(subscriptionManager)
        }
    }
    

    
    private func loadPersonalizedInsights() {
        Task {
            // Map Core Data objects to data structs
            let checkInsData = checkInLogs.map(WorkplaceCheckInData.init(fromMO:))
            let breathingData = breathingLogs.map(BreathingSessionData.init(fromMO:))
            let journalData = journalStore.entries.map { WorkplaceJournalEntryData(from: $0) }
            let goalsArray = goalsManager.goals
            
            let generatedInsights = await personalizationEngine.generatePersonalizedInsights(
                checkIns: checkInsData,
                breathingLogs: breathingData,
                journalEntries: journalData,
                goals: goalsArray,
                forLastDays: 7
            )
            
            await MainActor.run {
                self.insights = generatedInsights.map { AppInsight(message: $0.message, type: $0.type, priority: $0.priority, confidence: $0.confidence) }.filter { insight in
                    !(interactionHistory[insight.id]?.dismissed ?? false)
                }
                self.userRole = personalizationEngine.userRole
                self.userIndustry = personalizationEngine.userIndustry
                self.currentComplexity = personalizationEngine.insightComplexity
            }
        }
    }
    
    private func handleInsightInteraction(_ insight: AppInsight, dismissed: Bool, actionTaken: Bool) {
        Task {
            do {
                try personalizationEngine.recordInteraction(for: insight.type, action: dismissed ? .dismissed : (actionTaken ? .actionTaken : .viewed))
            } catch {
                // Handle or log the error appropriately
                print("Failed to record interaction: \(error.localizedDescription)")
            }
        }
        interactionHistory[insight.id] = (dismissed: dismissed, actionTaken: actionTaken)
        
        AnalyticsService.shared.logEvent("insight_interaction", parameters: [
            "insight_id": insight.id.uuidString,
            "insight_type": insight.type.rawValue,
            "insight_message": insight.message,
            "action": dismissed ? "dismissed" : (actionTaken ? "action_taken" : "viewed")
        ])
        
        if dismissed {
            insights.removeAll { $0.id == insight.id }
        }
    }
}

// MARK: - Extracted Subviews

private struct EmptyInsightsView: View {
    var body: some View {
        VStack(spacing: 16) {
            UserProgressView()
            Text("Generating personalized insights...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct InsightGridView: View {
    let insights: [AppInsight]
    let horizontalSizeClass: UserInterfaceSizeClass?
    let interactionHandler: (AppInsight, Bool, Bool) -> Void

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                LazyVStack(spacing: 16) {
                    ForEach(insights) { insight in
                        PersonalizedInsightCard(
                            insight: insight,
                            onDismiss: { interactionHandler(insight, true, false) },
                            onAction: { interactionHandler(insight, false, true) }
                        )
                    }
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300, maximum: 400))], spacing: 16) {
                    ForEach(insights) { insight in
                        PersonalizedInsightCard(
                            insight: insight,
                            onDismiss: { interactionHandler(insight, true, false) },
                            onAction: { interactionHandler(insight, false, true) }
                        )
                    }
                }
            }
        }
    }
}

private struct PaywallContent: View {
    @Binding var showingPaywall: Bool
    let horizontalSizeClass: UserInterfaceSizeClass?

    var body: some View {
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
        .frame(maxWidth: horizontalSizeClass == .compact ? .infinity : 500)
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
    let insight: AppInsight
    let onDismiss: () -> Void
    let onAction: () -> Void
    
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    insightTypeIcon
                    Text(insight.type.rawValue.capitalized)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if insight.confidence < 1.0 {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar.fill")
                            .font(.caption2)
                        Text("\(Int(insight.confidence * 100))% conf.")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            // Message
            Text(insight.message)
                .font(.body)
                .lineLimit(showingDetails ? nil : 3)
            
            // Action Buttons
            HStack(spacing: 12) {
                Button("Dismiss") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.secondary)
                
                if insight.type == .suggestion || insight.type == .alert || insight.type == .question {
                    Button("Take Action") {
                        onAction()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Spacer()
                
                if insight.message.count > 100 {
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
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    @ViewBuilder
    private var insightTypeIcon: some View {
        switch insight.type {
        case .observation: Image(systemName: "eye.fill").foregroundColor(.blue)
        case .question: Image(systemName: "questionmark.circle.fill").foregroundColor(.purple)
        case .suggestion: Image(systemName: "lightbulb.fill").foregroundColor(.orange)
        case .affirmation: Image(systemName: "star.fill").foregroundColor(.green)
        case .alert: Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
        case .prediction: Image(systemName: "crystal.ball.fill").foregroundColor(.indigo)
        case .anomaly: Image(systemName: "waveform.path.ecg").foregroundColor(.pink)
        case .warning: Image(systemName: "exclamationmark.shield.fill").foregroundColor(.orange)
        case .celebration: Image(systemName: "party.popper.fill").foregroundColor(.green)
        case .trend: Image(systemName: "chart.line.uptrend.xyaxis").foregroundColor(.blue)
        case .correlation: Image(systemName: "link.circle.fill").foregroundColor(.purple)
        case .goalProgress: Image(systemName: "target").foregroundColor(.orange)
        case .workplaceSpecific: Image(systemName: "building.2.fill").foregroundColor(.cyan)
        }
    }
}


// MARK: - Previews
struct InsightsView_Previews: PreviewProvider {
    static var previews: some View {
        let mockSubscriptionManager = SubscriptionManager()
        let mockPersonalizationEngine = PersonalizationEngine.shared
        let context = PersistenceController.preview.container.viewContext

        // Example: Create mock insights directly in the preview if PersonalizationEngine can't be easily mocked for this.
        // This is a simplified approach. For robust previews, PersonalizationEngine might need a preview mode.
        // let mockInsights: [Insight] = [
        //     Insight(id: UUID(), type: .observation, message: "Preview observation insight.", confidence: 1.0, priority: .medium, relatedData: nil, actionType: nil, actionURL: nil, details: nil),
        //     Insight(id: UUID(), type: .suggestion, message: "Preview suggestion insight.", confidence: 0.8, priority: .high, relatedData: nil, actionType: .navigateToBreathing, actionURL: nil, details: nil)
        // ]

        let insightsView = InsightsView()
        // insightsView.insights = mockInsights // This won't work directly with @State; data loaded in onAppear.

        return insightsView
            .environmentObject(mockSubscriptionManager)
            .environmentObject(mockPersonalizationEngine)
            .environment(\.managedObjectContext, context)
    }
}
