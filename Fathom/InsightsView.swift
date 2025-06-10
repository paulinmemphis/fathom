import SwiftUI
import CoreData

struct InsightsView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingPaywall = false

    // FetchRequest for BreathingExerciseLog
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \BreathingExerciseLog.timestamp, ascending: false)],
        animation: .default) // Add animation for list updates
    private var breathingLogs: FetchedResults<BreathingExerciseLog>

    // FetchRequest for CheckIn entities
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \WorkplaceCheckIn.checkInTime, ascending: false)],
        animation: .default)
    private var checkInLogs: FetchedResults<WorkplaceCheckIn>

    // Date range for filtering (e.g., last 7 days)
    private var sevenDaysAgo: Date {
        Calendar.current.date(byAdding: .day, value: -7, to: Date())!
    }

    private var recentBreathingLogs: [BreathingExerciseLog] {
        breathingLogs.filter { $0.timestamp ?? Date() >= sevenDaysAgo }
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
                if subscriptionManager.isProUser || subscriptionManager.developerBypassEnabled {
                    // Placeholder for actual insights content
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Generate insights using the engine
                            let insights = insightEngine.generateInsights(
                                checkIns: Array(checkInLogs),
                                breathingLogs: Array(breathingLogs),
                                forLastDays: 7
                            )

                            if insights.isEmpty {
                                Text("No specific insights to show right now. Keep using Fathom to track your work and well-being, and check back soon!")
                                    .foregroundColor(.secondary)
                                    .padding()
                                    .multilineTextAlignment(.center)
                            } else {
                                ForEach(insights) { insight in
                                    InsightCardView(insight: insight)
                                }
                            }
                            
                            // Keep raw data summaries for now, or integrate them into InsightCards
                            Section(header: Text("Data Summary (Last 7 Days)").font(.caption).foregroundColor(.secondary).padding(.top)) {
                                GroupBox {
                                    VStack(alignment: .leading) {
                                        Text("Mindful Moments: \(recentBreathingLogs.count) session(s)")
                                        Text("Total Work: \(totalWorkHoursLast7Days, specifier: "%.1f") hours")
                                    }
                                }
                            }
                        }
                        .padding()
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
        }
    }

    private func colorForInsightType(_ type: InsightType) -> Color {
        switch type {
        case .observation: return .blue
        case .question: return .purple
        case .suggestion: return .orange
        case .affirmation: return .green
        case .alert: return .red
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
        // To preview the developer bypass view:
        // mockSubscriptionManager.developerBypassEnabled = true

        InsightsView()
            .environmentObject(mockSubscriptionManager)
    }
}
