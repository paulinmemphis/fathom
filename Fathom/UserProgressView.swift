import SwiftUI
import CoreData
import Combine
@preconcurrency import EventKit

struct UserProgressView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var achievementManager = AchievementManager.shared
    @StateObject private var userStatsManager = UserStatsManager.shared
    @StateObject private var personalizationEngine = PersonalizationEngine.shared
    
    @State private var selectedTab = 0
    @State private var showingPaywall = false
    @State private var showingPersonalizationSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Custom Tab Picker
            customTabPicker
            
            // MARK: - Content
            Group {
                if selectedTab == 0 {
                    insightsContent
                } else {
                    achievementsContent
                }
            }
        }
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if selectedTab == 0 && subscriptionManager.isProUser {
                    Button {
                        showingPersonalizationSettings = true
                    } label: {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView_Workplace()
        }
        .sheet(isPresented: $showingPersonalizationSettings) {
            PersonalizationSettingsView()
        }
    }
    
    // MARK: - Custom Tab Picker
    private var customTabPicker: some View {
        HStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = 0
                }
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "brain.head.profile")
                        .font(.title3)
                    Text("Insights")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(selectedTab == 0 ? .blue : .gray)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(selectedTab == 0 ? Color.blue.opacity(0.1) : Color.clear)
            }
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = 1
                }
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "star.circle.fill")
                        .font(.title3)
                    Text("Achievements")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(selectedTab == 1 ? .blue : .gray)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(selectedTab == 1 ? Color.blue.opacity(0.1) : Color.clear)
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    // MARK: - Insights Content
    private var insightsContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                if subscriptionManager.isProUser {
                    // Pro insights content
                    proInsightsContent
                } else {
                    // Free tier insights
                    freeInsightsContent
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
    
    private var proInsightsContent: some View {
        VStack(spacing: 20) {
            // MARK: - Personalization Status
            PersonalizationStatusCard()
            
            // MARK: - Key Insights Summary
            keyInsightsSummary
            
            // MARK: - Progress Charts
            progressChartsSection
            
            // MARK: - Weekly Summary
            weeklySummaryCard
            
            // MARK: - Detailed Insights
            detailedInsightsSection
        }
    }
    
    private var freeInsightsContent: some View {
        VStack(spacing: 20) {
            // MARK: - Basic Stats
            basicStatsCard
            
            // MARK: - Upgrade Prompt
            upgradePromptCard
            
            // MARK: - Preview Insights
            previewInsightsCard
        }
    }
    
    // MARK: - Key Insights Summary
    private var keyInsightsSummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Key Insights")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                
                InsightSummaryCard(
                    title: "Peak Focus",
                    value: "2-4 PM",
                    icon: "brain.head.profile",
                    color: .blue,
                    trend: .up
                )
                
                InsightSummaryCard(
                    title: "Avg Session",
                    value: "4.2 hrs",
                    icon: "clock.fill",
                    color: .green,
                    trend: .up
                )
                
                InsightSummaryCard(
                    title: "Stress Level",
                    value: "Low",
                    icon: "heart.fill",
                    color: .orange,
                    trend: .down
                )
                
                InsightSummaryCard(
                    title: "Productivity",
                    value: "High",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .purple,
                    trend: .up
                )
            }
        }
    }
    
    // MARK: - Progress Charts Section
    private var progressChartsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Progress Charts")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // Work Hours Chart
                ProgressChartCard(
                    title: "Work Hours This Week",
                    value: "32.5 hrs",
                    progress: 0.65,
                    color: .blue
                )
                
                // Wellness Score Chart
                ProgressChartCard(
                    title: "Wellness Score",
                    value: "8.2/10",
                    progress: 0.82,
                    color: .green
                )
                
                // Focus Rating Chart
                ProgressChartCard(
                    title: "Average Focus",
                    value: "7.5/10",
                    progress: 0.75,
                    color: .purple
                )
            }
        }
    }
    
    // MARK: - Weekly Summary Card
    private var weeklySummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("This Week")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("vs. Last Week")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                WeeklySummaryRow(
                    title: "Total Work Time",
                    value: "32.5 hrs",
                    change: "+2.3 hrs",
                    isPositive: true
                )
                
                WeeklySummaryRow(
                    title: "Breathing Sessions",
                    value: "12",
                    change: "+5",
                    isPositive: true
                )
                
                WeeklySummaryRow(
                    title: "Average Stress",
                    value: "3.2/10",
                    change: "-1.1",
                    isPositive: true
                )
                
                WeeklySummaryRow(
                    title: "Focus Rating",
                    value: "7.5/10",
                    change: "+0.8",
                    isPositive: true
                )
            }
        }
        .padding(20)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Detailed Insights Section
    @State private var showingTaskScheduler = false

    private var detailedInsightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Detailed Insights")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                DetailedInsightCard(
                    icon: "lightbulb.fill",
                    title: "Productivity Pattern",
                    description: "Your productivity peaks between 2-4 PM. Consider scheduling important tasks during this window.",
                    action: "Schedule Tasks",
                    onAction: { showingTaskScheduler = true }
                )
                
                DetailedInsightCard(
                    icon: "moon.fill",
                    title: "Rest Recommendation",
                    description: "You've been working long hours. Consider taking a 15-minute break every 2 hours.",
                    action: "Set Reminders",
                    onAction: { /* TODO: Implement Set Reminders */ }
                )
                
                DetailedInsightCard(
                    icon: "figure.walk",
                    title: "Movement Suggestion",
                    description: "Your focus improves after short walks. Try a 5-minute walk between tasks.",
                    action: "Plan Walks",
                    onAction: { /* TODO: Implement Plan Walks */ }
                )
            }
        }
        .sheet(isPresented: $showingTaskScheduler) {
            TaskSchedulingSheet()
        }
    }
    
    // MARK: - Basic Stats Card (Free Tier)
    private var basicStatsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Basic Stats")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                BasicStatRow(
                    icon: "clock.fill",
                    title: "Total Work Time",
                    value: "32.5 hrs this week"
                )
                
                BasicStatRow(
                    icon: "location.fill",
                    title: "Check-ins",
                    value: "15 this week"
                )
                
                BasicStatRow(
                    icon: "wind",
                    title: "Breathing Sessions",
                    value: "3 this week"
                )
            }
        }
        .padding(20)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Upgrade Prompt Card
    private var upgradePromptCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unlock AI-Powered Insights")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Get personalized insights about your work patterns")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ProfileProFeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Advanced Analytics", isActive: true)
                ProfileProFeatureRow(icon: "lightbulb.fill", text: "Productivity Recommendations", isActive: true)
                ProfileProFeatureRow(icon: "target", text: "Goal Tracking & Insights", isActive: true)
                ProfileProFeatureRow(icon: "brain.head.profile", text: "AI-Powered Patterns", isActive: true)
            }
            
            Button(action: {
                showingPaywall = true
            }) {
                Text("Upgrade to Pro")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.cyan.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }
    
    // MARK: - Preview Insights Card
    private var previewInsightsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Insight Preview")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "clock.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Peak Performance Time")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Your focus is highest in the afternoon")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Divider()
                
                HStack {
                    Text("Unlock full insights with Pro")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Upgrade") {
                        showingPaywall = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
        }
        .padding(20)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Achievements Content
    private var achievementsContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Achievement Progress
                achievementProgressCard
                
                // MARK: - Achievement Categories
                achievementCategoriesSection
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
    
    private var achievementProgressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Achievement Progress")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    let unlockedCount = achievementManager.achievementStatuses.filter { $0.isUnlocked }.count
                    let totalCount = achievementManager.achievementStatuses.count
                    
                    Text("\(unlockedCount)/\(totalCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("unlocked")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Progress bar
            let progress = achievementManager.achievementStatuses.isEmpty ? 0.0 : 
                Double(achievementManager.achievementStatuses.filter { $0.isUnlocked }.count) / 
                Double(achievementManager.achievementStatuses.count)
            
            VStack(spacing: 4) {
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: CGFloat(progress) * 200, height: 4)
                }
                .frame(width: 200)
                .cornerRadius(2)
                
                Text("Progress")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var achievementCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Categories")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(AchievementCategory.allCases) { category in
                let categoryAchievements = achievementManager.achievementStatuses.filter { 
                    $0.definition.category == category 
                }
                
                if !categoryAchievements.isEmpty {
                    AchievementCategoryCard(
                        category: category,
                        achievements: categoryAchievements
                    )
                }
            }
        }
    }
}

struct PersonalizationStatusCard: View {
    @StateObject private var personalizationEngine = PersonalizationEngine.shared
    @State private var complexity: InsightComplexity = .basic
    @State private var role: WorkRole = .developer
    @State private var industry: WorkIndustry = .technology
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Personalization")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("Level \(complexity.rawValue)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
            
            Text("Personalized for \(role.rawValue) in \(industry.rawValue)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            self.complexity = personalizationEngine.insightComplexity
            self.role = personalizationEngine.userRole
            self.industry = personalizationEngine.userIndustry
        }
    }
}

struct InsightSummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: TrendDirection
    
    enum TrendDirection {
        case up, down, stable
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Spacer()
                
                Image(systemName: trendIcon)
                    .font(.caption)
                    .foregroundColor(trendColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var trendIcon: String {
        switch trend {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .stable: return "minus"
        }
    }
    
    private var trendColor: Color {
        switch trend {
        case .up: return .green
        case .down: return .red
        case .stable: return .gray
        }
    }
}

struct ProgressChartCard: View {
    let title: String
    let value: String
    let progress: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
                .frame(height: 4)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct WeeklySummaryRow: View {
    let title: String
    let value: String
    let change: String
    let isPositive: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(change)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isPositive ? .green : .red)
        }
    }
}

struct DetailedInsightCard: View {
    let icon: String
    let title: String
    let description: String
    let action: String
    let onAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
            Button(action) {
                onAction()
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct BasicStatRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(value)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct AchievementCategoryCard: View {
    let category: AchievementCategory
    let achievements: [AchievementManager.AchievementDisplayData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(category.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                let unlockedCount = achievements.filter { $0.isUnlocked }.count
                Text("\(unlockedCount)/\(achievements.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(achievements.prefix(6), id: \.definition.id) { achievement in
                    AchievementBadge(achievement: achievement)
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct AchievementBadge: View {
    let achievement: AchievementManager.AchievementDisplayData
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: achievement.definition.iconName)
                .font(.title3)
                .foregroundColor(achievement.isUnlocked ? .blue : .gray)
                .opacity(achievement.isUnlocked ? 1.0 : 0.5)
            
            Text(achievement.definition.name)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(achievement.isUnlocked ? .primary : .secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(width: 60, height: 60)
    }
}

@MainActor
final class EventKitManager: ObservableObject {
    static let shared = EventKitManager()
    @Published var hasAccess: Bool = false
    @Published var reminderLists: [EKCalendar] = []
    @Published var fetchedReminders: [EKReminder] = []

    private let eventStore = EKEventStore()
    private let queue = DispatchQueue(label: "com.fathom.eventkit-manager")
    
    enum EventKitError: Error {
        case accessDenied
        case operationFailed
    }

    init() {
        Task {
            await checkAccess()
        }
    }

    func checkAccess() async {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        var hasAccess = false
        if #available(iOS 17.0, *) {
            hasAccess = (status == .fullAccess || status == .writeOnly)
        } else {
            hasAccess = (status == .authorized)
        }
        
        self.hasAccess = hasAccess
        if hasAccess {
            await self.loadReminderLists()
        }
    }

    func requestAccess() async -> Bool {
        let granted: Bool
        if #available(iOS 17.0, *) {
            do {
                granted = try await eventStore.requestFullAccessToReminders()
            } catch {
                print("Failed to request reminder access: \(error)")
                granted = false
            }
        } else {
            let eventStore = self.eventStore // Capture before background
            granted = await withCheckedContinuation { continuation in
                queue.async {
                    eventStore.requestAccess(to: .reminder) { granted, error in
                        if let error = error {
                            print("Failed to request reminder access: \(error)")
                        }
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
        
        self.hasAccess = granted
        if granted {
            await self.loadReminderLists()
        }
        return granted
    }

    private func loadReminderLists() async {
        guard self.hasAccess else { return }
        
        let eventStore = self.eventStore // Capture before background
        let calendars = await withCheckedContinuation { (continuation: CheckedContinuation<[EKCalendar], Never>) in
            queue.async {
                let cals = eventStore.calendars(for: .reminder)
                continuation.resume(returning: cals)
            }
        }
        self.reminderLists = calendars
    }

    func addReminder(title: String, due: Date, notes: String?, recurrenceRule: EKRecurrenceRule?, list: EKCalendar?) async throws {
        guard self.hasAccess else { throw EventKitError.accessDenied }
        
        let eventStore = self.eventStore // Capture before background
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                let reminder = EKReminder(eventStore: eventStore)
                reminder.title = title
                reminder.calendar = list ?? eventStore.defaultCalendarForNewReminders()
                reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due)
                reminder.notes = notes
                if let recurrenceRule = recurrenceRule {
                    reminder.addRecurrenceRule(recurrenceRule)
                }

                do {
                    try eventStore.save(reminder, commit: true)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func save(reminder: EKReminder) async throws {
        let eventStore = self.eventStore // Capture before background
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try eventStore.save(reminder, commit: true)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func complete(reminder: EKReminder) async throws {
        let eventStore = self.eventStore // Capture before background
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                reminder.isCompleted = true
                do {
                    try eventStore.save(reminder, commit: true)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchReminders() async {
        guard self.hasAccess else {
            self.fetchedReminders = []
            return
        }

        let eventStore = self.eventStore // Capture for use in background

        // Fetch reminder IDENTIFIERS on the background queue.
        let reminderIDs: [String] = await withCheckedContinuation { continuation in
            queue.async {
                let predicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
                eventStore.fetchReminders(matching: predicate) { fetchedReminders in
                    let ids = fetchedReminders?.map { $0.calendarItemIdentifier } ?? []
                    continuation.resume(returning: ids) // Return [String], which is Sendable
                }
            }
        }

        // Now on the MainActor, use the IDs to get the full objects.
        let reminders = reminderIDs.compactMap { eventStore.calendarItem(withIdentifier: $0) as? EKReminder }
        self.fetchedReminders = reminders
    }
}

enum BannerType {
    case success
    case error
}

struct BannerView: View {
    let message: String
    let type: BannerType

    var body: some View {
        HStack {
            Image(systemName: type == .success ? "checkmark.circle.fill" : "xmark.octagon.fill")
                .foregroundColor(type == .success ? .green : .red)
            Text(message)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 5)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

struct TaskSchedulingSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var taskTitle: String = ""
    @State private var scheduledTime: Date = Date()
    @State private var notes: String = ""
    @State private var isRecurring = false
    @State private var recurrenceFrequency: EKRecurrenceFrequency = .daily
    @State private var recurrenceInterval: Int = 1
    @State private var saveToReminders = false
    
    @State private var isSaving = false
    @State private var showSaveSuccessBanner = false
    @State private var showSaveErrorBanner = false
    @State private var showRemindersDeniedAlert = false
    
    @State private var selectedReminderList: EKCalendar?
    @ObservedObject private var eventKitManager = EventKitManager.shared

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Task Title", text: $taskTitle)
                    DatePicker("Scheduled Time", selection: $scheduledTime, displayedComponents: [.date, .hourAndMinute])
                    TextField("Notes (Optional)", text: $notes)
                }

                recurrenceSection

                saveDestinationSection
            }
            .navigationTitle("Schedule Task")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    saveTask()
                }
                .disabled(taskTitle.isEmpty || isSaving)
            )
            .overlay(
                Group {
                    if showSaveSuccessBanner {
                        BannerView(message: "Task saved successfully!", type: .success)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showSaveSuccessBanner = false
                                    presentationMode.wrappedValue.dismiss()
                                }
                            }
                    }
                    if showSaveErrorBanner {
                        BannerView(message: "Failed to save task.", type: .error)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showSaveErrorBanner = false
                                }
                            }
                    }
                }
                .animation(.easeInOut, value: showSaveSuccessBanner || showSaveErrorBanner)
            )
            .alert("Access Denied", isPresented: $showRemindersDeniedAlert) {
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please enable Reminders access in Settings to save tasks.")
            }
        }
    }

    private var recurrenceSection: some View {
        Section(header: Text("Recurrence")) {
            Toggle("Recurring Task", isOn: $isRecurring.animation())

            if isRecurring {
                Picker("Frequency", selection: $recurrenceFrequency) {
                    Text("Daily").tag(EKRecurrenceFrequency.daily)
                    Text("Weekly").tag(EKRecurrenceFrequency.weekly)
                    Text("Monthly").tag(EKRecurrenceFrequency.monthly)
                    Text("Yearly").tag(EKRecurrenceFrequency.yearly)
                }
                .pickerStyle(.segmented)

                Stepper(value: $recurrenceInterval, in: 1...100) {
                    Text("Every \(recurrenceInterval) \(frequencyString(for: recurrenceFrequency))s")
                }
            }
        }
    }

    private var saveDestinationSection: some View {
        Section(header: Text("Save Destination")) {
            Toggle("Save to Apple Reminders", isOn: $saveToReminders)
                .onChange(of: saveToReminders) {
                    if saveToReminders && !eventKitManager.hasAccess {
                        Task {
                            await eventKitManager.requestAccess()
                        }
                    }
                }

            if saveToReminders {
                if eventKitManager.hasAccess {
                    if eventKitManager.reminderLists.isEmpty {
                        Text("No reminder lists found.")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("List", selection: $selectedReminderList) {
                            Text("Default List").tag(nil as EKCalendar?)
                            ForEach(eventKitManager.reminderLists, id: \.self) { list in
                                Text(list.title).tag(list as EKCalendar?)
                            }
                        }
                        .onAppear {
                            if selectedReminderList == nil {
                                selectedReminderList = eventKitManager.reminderLists.first
                            }
                        }
                    }
                } else {
                    Text("Enable Reminders access to select a list.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func saveTask() {
        isSaving = true
        
        Task {
            defer { isSaving = false }
            
            if saveToReminders {
                guard eventKitManager.hasAccess else {
                    showRemindersDeniedAlert = true
                    return
                }

                let recurrenceRule = isRecurring ? EKRecurrenceRule(recurrenceWith: recurrenceFrequency, interval: recurrenceInterval, end: nil) : nil

                do {
                    try await eventKitManager.addReminder(title: taskTitle, due: scheduledTime, notes: notes, recurrenceRule: recurrenceRule, list: selectedReminderList)
                    showSaveSuccessBanner = true
                } catch {
                    print("Failed to save reminder: \(error)")
                    showSaveErrorBanner = true
                }
            } else {
                // Save to Core Data
                let newItem = Item(context: viewContext)
                newItem.timestamp = scheduledTime
                // newItem.title = taskTitle // ERROR: 'Item' has no 'title' property.
                // To add a title, you must edit the Core Data Model file (e.g., Fathom.xcdatamodeld)
                // and add a 'title' attribute of type String to the 'Item' entity.

                do {
                    try viewContext.save()
                    showSaveSuccessBanner = true
                } catch {
                    let nsError = error as NSError
                    print("Unresolved error \(nsError), \(nsError.userInfo)")
                    showSaveErrorBanner = true
                }
            }
        }
    }

    private func frequencyString(for frequency: EKRecurrenceFrequency) -> String {
        switch frequency {
        case .daily: return "day"
        case .weekly: return "week"
        case .monthly: return "month"
        case .yearly: return "year"
        @unknown default: return ""
        }
    }
}


// MARK: - Scheduled Tasks Section (surfacing scheduled tasks)
struct ScheduledTasksSection: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default)
    private var localTasks: FetchedResults<Item>

    @ObservedObject private var eventKitManager = EventKitManager.shared
    @State private var showReminders = false
    @State private var editingReminder: EKReminder? = nil
    @State private var editingTitle: String = ""
    @State private var editingNotes: String = ""
    @State private var showEditSheet = false
    @State private var showCompleteBanner = false
    @State private var showEditBanner = false
    @State private var showErrorBanner = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Scheduled Tasks")
                    .font(.headline)
                Spacer()
                Button(action: {
                    Task {
                        let granted = await eventKitManager.requestAccess()
                        if granted {
                            await eventKitManager.fetchReminders()
                            showReminders = true
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Sync")
                    }
                }
            }
            if !localTasks.isEmpty {
                ForEach(localTasks) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            // The default 'Item' entity has no title. Displaying placeholder.
                            Text("Scheduled Task")
                                .font(.subheadline)
                        }
                        Spacer()
                        if let date = item.timestamp {
                            Text(date, style: .time)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Text("Local")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            } else {
                Text("No scheduled tasks.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if showReminders {
                Divider()
                Text("Apple Reminders")
                    .font(.headline)
                ForEach(eventKitManager.fetchedReminders, id: \.self) { reminder in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(reminder.title)
                                .font(.subheadline)
                            if let notes = reminder.notes, !notes.isEmpty {
                                Text(notes).font(.caption).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        if let due = reminder.dueDateComponents?.date {
                            Text(due, style: .time)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Text("Reminders")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    .contextMenu {
                        Button(action: {
                            markReminderCompleted(reminder)
                        }) {
                            Label("Mark Completed", systemImage: "checkmark.circle")
                        }
                        Button(action: {
                            beginEdit(reminder)
                        }) {
                            Label("Edit", systemImage: "pencil")
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .sheet(isPresented: $showEditSheet) {
            NavigationView {
                Form {
                    Section(header: Text("Title")) {
                        TextField("Title", text: $editingTitle)
                    }
                    Section(header: Text("Notes")) {
                        TextField("Notes", text: $editingNotes)
                    }
                }
                .navigationBarTitle("Edit Reminder", displayMode: .inline)
                .navigationBarItems(leading: Button("Cancel") {
                    showEditSheet = false
                }, trailing: Button("Save") {
                    saveEdit()
                })
            }
        }
        .overlay(
            VStack {
                if showCompleteBanner {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        Text("Marked as completed!")
                    }
                    .padding()
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(10)
                    .transition(.move(edge: .top))
                }
                if showEditBanner {
                    HStack {
                        Image(systemName: "pencil.circle.fill").foregroundColor(.blue)
                        Text("Reminder updated!")
                    }
                    .padding()
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(10)
                    .transition(.move(edge: .top))
                }
                if showErrorBanner {
                    HStack {
                        Image(systemName: "xmark.octagon.fill").foregroundColor(.red)
                        Text("Operation failed.")
                    }
                    .padding()
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(10)
                    .transition(.move(edge: .top))
                }
                Spacer()
            }
            .animation(.easeInOut, value: showCompleteBanner || showEditBanner || showErrorBanner)
        )
    }
    
    private func markReminderCompleted(_ reminder: EKReminder) {
        Task {
            do {
                try await eventKitManager.complete(reminder: reminder)
                showCompleteBanner = true
                await eventKitManager.fetchReminders()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showCompleteBanner = false }
            } catch {
                showErrorBanner = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { showErrorBanner = false }
            }
        }
    }
    
    private func beginEdit(_ reminder: EKReminder) {
        editingReminder = reminder
        editingTitle = reminder.title
        editingNotes = reminder.notes ?? ""
        showEditSheet = true
    }
    
    private func saveEdit() {
        guard let reminder = editingReminder else { return }
        reminder.title = editingTitle
        reminder.notes = editingNotes
        
        Task {
            do {
                try await eventKitManager.save(reminder: reminder)
                showEditBanner = true
                await eventKitManager.fetchReminders()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showEditBanner = false }
            } catch {
                showErrorBanner = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { showErrorBanner = false }
            }
        }
        showEditSheet = false
    }
}


// MARK: - Preview

struct UserProgressView_Previews: PreviewProvider {
    static var previews: some View {
        UserProgressView()
            .environmentObject(SubscriptionManager())
    }
}
