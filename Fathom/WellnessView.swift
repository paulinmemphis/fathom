import SwiftUI
import CoreData

struct WellnessView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var userStatsManager = UserStatsManager.shared
    
    @State private var showingBreathingExercise = false
    @State private var showingTaskBreaker = false
    @State private var showingCognitiveReframing = false
    @State private var showingFocusTimer = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Header
                    headerSection
                    
                    // MARK: - Featured Exercise
                    featuredExerciseCard
                    
                    // MARK: - Wellness Tools Grid
                    wellnessToolsGrid
                    
                    // MARK: - Recent Activity
                    recentActivitySection
                    
                    // MARK: - Pro Features
                    if !subscriptionManager.isProUser {
                        proFeaturesCard
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .navigationTitle("Wellness")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await refreshData()
            }
        }
        .sheet(isPresented: $showingBreathingExercise) {
            BreathingExerciseView()
        }
        .sheet(isPresented: $showingTaskBreaker) {
            TaskBreakerView()
        }
        .sheet(isPresented: $showingCognitiveReframing) {
            CognitiveReframingView()
        }
        .sheet(isPresented: $showingFocusTimer) {
            FocusTimerView()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Wellness Journey")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("Take care of your mind and body")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Wellness streak
                if userStatsManager.currentWorkSessionStreak > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(userStatsManager.totalBreathingExercisesLogged)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        
                        Text("sessions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Featured Exercise Card
    private var featuredExerciseCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recommended for You")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Start with a 2-minute breathing exercise")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "wind")
                    .font(.largeTitle)
                    .foregroundColor(.blue)
            }
            
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
    
    // MARK: - Wellness Tools Grid
    private var wellnessToolsGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Wellness Tools")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                
                WellnessToolCard(
                    title: "Breathing",
                    subtitle: "Calm your mind",
                    icon: "wind",
                    color: .blue,
                    isLocked: false,
                    action: { showingBreathingExercise = true }
                )
                
                WellnessToolCard(
                    title: "Focus Timer",
                    subtitle: "Pomodoro technique",
                    icon: "timer",
                    color: .orange,
                    isLocked: !subscriptionManager.isProUser,
                    action: { showingFocusTimer = true }
                )
                
                WellnessToolCard(
                    title: "Task Breaker",
                    subtitle: "Overcome blocks",
                    icon: "hammer.fill",
                    color: .green,
                    isLocked: !subscriptionManager.isProUser,
                    action: { showingTaskBreaker = true }
                )
                
                WellnessToolCard(
                    title: "Reframing",
                    subtitle: "Shift perspective",
                    icon: "brain.head.profile",
                    color: .purple,
                    isLocked: !subscriptionManager.isProUser,
                    action: { showingCognitiveReframing = true }
                )
            }
        }
    }
    
    // MARK: - Recent Activity Section
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    // Navigate to detailed activity view
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            if userStatsManager.totalBreathingExercisesLogged > 0 {
                VStack(spacing: 12) {
                    ActivityRow(
                        icon: "wind",
                        title: "Breathing Exercise",
                        subtitle: "2 minutes",
                        time: "Today, 2:30 PM",
                        color: .blue
                    )
                    
                    if subscriptionManager.isProUser {
                        ActivityRow(
                            icon: "timer",
                            title: "Focus Session",
                            subtitle: "25 minutes",
                            time: "Today, 10:15 AM",
                            color: .orange
                        )
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    
                    Text("Start Your Wellness Journey")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Complete your first breathing exercise to see your progress here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
            }
        }
        .padding(20)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Pro Features Card
    private var proFeaturesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unlock Pro Wellness Tools")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Get access to advanced wellness features")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                WellnessProFeatureRow(icon: "timer", text: "Focus Timer & Pomodoro")
                WellnessProFeatureRow(icon: "hammer.fill", text: "Task Breaking Exercises")
                WellnessProFeatureRow(icon: "brain.head.profile", text: "Cognitive Reframing Tools")
                WellnessProFeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Advanced Progress Tracking")
            }
            
            Button(action: {
                // Show subscription view
            }) {
                Text("Upgrade to Pro")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.purple)
                    .cornerRadius(12)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.1), Color.pink.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }
    
    // MARK: - Helper Methods
    private func refreshData() async {
        // Refresh user stats and activity data
    }
}

// MARK: - Supporting Views

struct WellnessToolCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isLocked: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(isLocked ? .gray : color)
                    
                    if isLocked {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Color.gray)
                                    .clipShape(Circle())
                            }
                        }
                    }
                }
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(isLocked ? .gray : .primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
    }
}

struct ActivityRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let time: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(time)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct WellnessProFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.blue)
                .frame(width: 20, height: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - Preview

struct WellnessView_Previews: PreviewProvider {
    static var previews: some View {
        WellnessView()
            .environmentObject(SubscriptionManager())
    }
}
