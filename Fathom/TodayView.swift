import SwiftUI
import CoreData

struct TodayView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var workplaceManager = WorkplaceManager.shared
    @StateObject private var userStatsManager = UserStatsManager.shared
    private let personalizationEngine = PersonalizationEngine.shared
    private let weeklyTargetSessions = 5
    
    @State private var showingBreathingExercise = false
    @State private var showingWorkplaceEntry = false
    @State private var showingInsights = false
    @State private var showingReflection = false
    @State private var showingTaskBreaker = false
    
    // Current date components
    private var currentDate: Date { Date() }
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }
    
    // Quick stats
    private var todayStats: DayStats {
        calculateTodayStats()
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: - Header Section
                headerSection
                
                // MARK: - Current Status Card
                currentStatusCard
                
                // MARK: - Quick Actions
                quickActionsSection
                
                // MARK: - Today's Summary
                todaySummaryCard
                
                // MARK: - Weekly Habit Recap
                weeklyHabitRecapCard
                
                // MARK: - Wellness Prompt
                wellnessPromptCard
                
                // MARK: - Recent Insights
                recentInsightsCard
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingReflection = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $showingBreathingExercise) {
            BreathingExerciseView()
        }
        .sheet(isPresented: $showingWorkplaceEntry) {
            JournalEntryComposeView(entryToEdit: nil)
                .environmentObject(subscriptionManager)
        }
        .sheet(isPresented: $showingInsights) {
            InsightsView()
        }
        .sheet(isPresented: $showingReflection) {
             JournalEntryComposeView(entryToEdit: nil)
                 .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingTaskBreaker) {
            TaskBreakerView()
                .environment(\.managedObjectContext, viewContext)
        }
        .onAppear {
            Task {
                await loadTodayData()
            }
        }
        .refreshable {
            await refreshData()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(greetingText)
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(dateFormatter.string(from: currentDate))
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // Streak indicator
                if userStatsManager.currentWorkSessionStreak > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(userStatsManager.currentWorkSessionStreak)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                        
                        Text("day streak")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Current Status Card
    private var currentStatusCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Current Status")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Status indicator
                statusIndicator
            }
            
            // Workplace context
            workplaceContextView
            
            // Quick check-in/out button
            checkInOutButton
        }
        .padding(20)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Weekly Habit Recap Card
    private var weeklyHabitRecapCard: some View {
        let (startOfWeek, endOfWeek) = weekDateRange(for: Date())
        let sessions = countWorkSessions(from: startOfWeek, to: endOfWeek)
        let daysLeft = daysLeftInWeek(from: Date(), endOfWeek: endOfWeek)
        let target = weeklyTargetSessions
        let progress = min(1.0, target > 0 ? Double(sessions) / Double(target) : 0)
        let suggestion = weeklySuggestionText(sessionsThisWeek: sessions, target: target, daysLeft: daysLeft)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Weekly Habit Recap")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }

            HStack(spacing: 12) {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current Streak: \(userStatsManager.currentWorkSessionStreak) days")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Best: \(userStatsManager.longestWorkSessionStreak) days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 12) {
                Image(systemName: "target")
                    .foregroundColor(.blue)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("This week: \(sessions)/\(target) sessions")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    ProgressView(value: progress)
                        .tint(.blue)
                }
            }

            Text(suggestion)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var statusIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(workplaceManager.activeCheckIn != nil ? Color.green : Color.gray)
                .frame(width: 10, height: 10)
            
            Text(workplaceManager.activeCheckIn != nil ? "Active" : "Inactive")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(workplaceManager.activeCheckIn != nil ? .green : .secondary)
        }
    }
    
    private var workplaceContextView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let activeCheckIn = workplaceManager.activeCheckIn,
               let workplace = activeCheckIn.workplace {
                
                HStack(spacing: 12) {
                    Image(systemName: "building.2.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text((workplace as? Workplace)?.name ?? "Unknown Workplace")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        if let checkInTime = activeCheckIn.checkInTime {
                            Text("Checked in at \(checkInTime, style: .time)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(sessionDurationText(from: activeCheckIn.checkInTime))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        
                        Text("session time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "location.slash")
                        .foregroundColor(.gray)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Not checked in")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text("Tap to check in when you arrive at work")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    private var checkInOutButton: some View {
        Button(action: {
            if workplaceManager.activeCheckIn != nil {
                // Check out
                Task {
                    await workplaceManager.checkOut()
                }
            } else {
                // Show workplace selection or quick check-in
                showingWorkplaceEntry = true
            }
        }) {
            HStack {
                Image(systemName: workplaceManager.activeCheckIn != nil ? "location.slash" : "location.fill")
                    .font(.title3)
                
                Text(workplaceManager.activeCheckIn != nil ? "Check Out" : "Check In")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(workplaceManager.activeCheckIn != nil ? Color.red : Color.blue)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Quick Actions")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                
                // Breathing Exercise
                QuickActionCard(
                    title: "Breathe",
                    subtitle: "2 min session",
                    icon: "wind",
                    color: .blue,
                    action: { showingBreathingExercise = true }
                )
                
                // Insights
                QuickActionCard(
                    title: "Insights",
                    subtitle: "View progress",
                    icon: "brain.head.profile",
                    color: .purple,
                    action: { showingInsights = true }
                )

                // Task Breaker
                QuickActionCard(
                    title: "Task Breaker",
                    subtitle: "Plan first steps",
                    icon: "checklist",
                    color: .teal,
                    action: {
                        showingTaskBreaker = true
                        AnalyticsService.shared.logEvent("tb_open_from_today", parameters: ["source": "today_quick_action"])
                    }
                )
                
                // Reflection (if checked in)
                if workplaceManager.activeCheckIn != nil {
                    QuickActionCard(
                        title: "Reflect",
                        subtitle: "Session notes",
                        icon: "doc.text.fill",
                        color: .green,
                        action: { showingReflection = true }
                    )
                }
                
                // Add Workplace
                QuickActionCard(
                    title: "Add Place",
                    subtitle: "New workplace",
                    icon: "plus.circle.fill",
                    color: .orange,
                    action: { showingWorkplaceEntry = true }
                )
            }
        }
    }
    
    // MARK: - Today's Summary Card
    private var todaySummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Today's Summary")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if subscriptionManager.isProUser {
                    Button("View Details") {
                        showingInsights = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }
            
            HStack(spacing: 16) {
                SummaryStatView(
                    title: "Work Time",
                    value: formatDuration(todayStats.workMinutes),
                    icon: "clock.fill",
                    color: .blue
                )
                
                SummaryStatView(
                    title: "Breathing",
                    value: "\(todayStats.breathingSessions)",
                    icon: "wind",
                    color: .green
                )
                
                SummaryStatView(
                    title: "Check-ins",
                    value: "\(todayStats.checkIns)",
                    icon: "location.fill",
                    color: .purple
                )
            }
        }
        .padding(20)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Wellness Prompt Card
    private var wellnessPromptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.title3)
                
                Text("Wellness Check")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Text(wellnessPromptText)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
            Button(action: {
                showingBreathingExercise = true
            }) {
                HStack {
                    Image(systemName: "play.fill")
                        .font(.subheadline)
                    
                    Text("Start Breathing Exercise")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color.red)
                .cornerRadius(10)
            }
        }
        .padding(20)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Recent Insights Card
    private var recentInsightsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Insights")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if subscriptionManager.isProUser {
                    Button("View All") {
                        showingInsights = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }
            
            if subscriptionManager.isProUser {
                // Show actual insights
                VStack(alignment: .leading, spacing: 8) {
                    Text("🎯 Your focus peaks in the afternoon")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Text("⏰ Consider scheduling important tasks after 2 PM")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            } else {
                // Pro upgrade prompt
                VStack(alignment: .leading, spacing: 8) {
                    Text("Unlock personalized insights")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Get AI-powered insights about your work patterns and wellness")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding(20)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Helper Methods
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: currentDate)
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }
    
    private var wellnessPromptText: String {
        let hour = Calendar.current.component(.hour, from: currentDate)
        let isWorkingHours = (9...17).contains(hour)
        
        if workplaceManager.activeCheckIn != nil && isWorkingHours {
            return "You've been working for a while. Take a moment to breathe and reset your focus."
        } else if isWorkingHours {
            return "Starting your workday? Begin with a quick breathing exercise to set a positive tone."
        } else {
            return "Wind down from your day with a relaxing breathing session."
        }
    }
    
    private func sessionDurationText(from startTime: Date?) -> String {
        guard let startTime = startTime else { return "0m" }
        let duration = Date().timeIntervalSince(startTime)
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(remainingMinutes)m"
        }
    }
    
    private func weekDateRange(for date: Date) -> (start: Date, end: Date) {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) ?? cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 7, to: start) ?? date
        return (start, end)
    }
    
    private func countWorkSessions(from start: Date, to end: Date) -> Int {
        let request: NSFetchRequest<Fathom.WorkplaceCheckIn> = Fathom.WorkplaceCheckIn.fetchRequest()
        request.predicate = NSPredicate(format: "checkInTime >= %@ AND checkInTime < %@", start as NSDate, end as NSDate)
        let results = (try? viewContext.fetch(request)) ?? []
        return results.count
    }
    
    private func daysLeftInWeek(from today: Date, endOfWeek: Date) -> Int {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: today)
        let days = cal.dateComponents([.day], from: startOfToday, to: endOfWeek).day ?? 0
        return max(0, days)
    }
    
    private func weeklySuggestionText(sessionsThisWeek: Int, target: Int, daysLeft: Int) -> String {
        if target <= 0 { return "Set a weekly session goal to get tailored suggestions." }
        if sessionsThisWeek >= target {
            return "Great job — you've hit your weekly goal! Keep your streak by planning one more short session."
        }
        if daysLeft == 0 {
            let remaining = max(0, target - sessionsThisWeek)
            return remaining > 0 ? "Week wraps today — try to squeeze in \(remaining) more session\(remaining == 1 ? "" : "s") if you can." : "Week wraps today — nice work!"
        }
        let remaining = max(0, target - sessionsThisWeek)
        let perDay = max(1, Int(ceil(Double(remaining) / Double(daysLeft))))
        return "You're \(remaining) away from your weekly goal of \(target). With \(daysLeft) day\(daysLeft == 1 ? "" : "s") left, aim for \(perDay) session\(perDay == 1 ? "" : "s") per day."
    }
    
    private func calculateTodayStats() -> DayStats {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        // Fetch today's check-ins using Core Data
        let request: NSFetchRequest<Fathom.WorkplaceCheckIn> = Fathom.WorkplaceCheckIn.fetchRequest()
        request.predicate = NSPredicate(format: "checkInTime >= %@ AND checkInTime < %@", today as NSDate, tomorrow as NSDate)
        
        let todayCheckIns = (try? viewContext.fetch(request)) ?? []
        
        let workMinutes = todayCheckIns.reduce(0) { total, checkIn in
            guard let checkInTime = checkIn.checkInTime else { return total }
            let checkOutTime = checkIn.checkOutTime ?? Date()
            let duration = checkOutTime.timeIntervalSince(checkInTime)
            return total + Int(duration / 60)
        }
        
        return DayStats(
            workMinutes: workMinutes,
            breathingSessions: 0, // TODO: Implement breathing session counting
            checkIns: todayCheckIns.count
        )
    }
    
    private func loadTodayData() async {
        await workplaceManager.loadWorkplaces()
        // Load other data as needed
    }
    
    private func refreshData() async {
        await workplaceManager.loadWorkplaces()
        // Refresh other data sources
    }
}

// MARK: - Supporting Views

struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct SummaryStatView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Data Models

struct DayStats {
    let workMinutes: Int
    let breathingSessions: Int
    let checkIns: Int
}

// MARK: - Preview

struct TodayView_Previews: PreviewProvider {
    static var previews: some View {
        TodayView()
            .environmentObject(SubscriptionManager())
    }
}
