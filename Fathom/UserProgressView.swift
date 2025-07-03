import SwiftUI
import CoreData

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
                    action: "Schedule Tasks"
                )
                
                DetailedInsightCard(
                    icon: "moon.fill",
                    title: "Rest Recommendation",
                    description: "You've been working long hours. Consider taking a 15-minute break every 2 hours.",
                    action: "Set Reminders"
                )
                
                DetailedInsightCard(
                    icon: "figure.walk",
                    title: "Movement Suggestion",
                    description: "Your focus improves after short walks. Try a 5-minute walk between tasks.",
                    action: "Plan Walks"
                )
            }
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
        .task {
            complexity = await personalizationEngine.getCurrentInsightComplexity()
            role = await personalizationEngine.getCurrentUserRole()
            industry = await personalizationEngine.getCurrentUserIndustry()
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
            
            VStack(spacing: 4) {
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: CGFloat(progress) * 150, height: 4)
                }
                .frame(width: 150)
                .cornerRadius(2)
                
                Text("Progress")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
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
                // Handle action
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

// MARK: - Preview

struct UserProgressView_Previews: PreviewProvider {
    static var previews: some View {
        UserProgressView()
            .environmentObject(SubscriptionManager())
    }
}
