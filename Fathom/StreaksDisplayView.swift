import SwiftUI

struct StreaksDisplayView: View {
    @StateObject private var userStatsManager = UserStatsManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Current Streaks")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.bottom, 5)

            HStack(spacing: 20) {
                StreakItemView(
                    iconName: "figure.walk",
                    iconColor: .blue,
                    streakName: "Work Sessions",
                    currentStreak: userStatsManager.currentWorkSessionStreak,
                    longestStreak: userStatsManager.longestWorkSessionStreak
                )
                Spacer()
                StreakItemView(
                    iconName: "wind",
                    iconColor: .green,
                    streakName: "Breathing",
                    currentStreak: userStatsManager.currentBreathingStreak,
                    longestStreak: userStatsManager.longestBreathingStreak
                )
                Spacer()
                StreakItemView(
                    iconName: "brain.head.profile",
                    iconColor: .purple,
                    streakName: "Reflections",
                    currentStreak: userStatsManager.currentDailyReflectionStreak,
                    longestStreak: userStatsManager.longestDailyReflectionStreak
                )
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct StreakItemView: View {
    let iconName: String
    let iconColor: Color
    let streakName: String
    let currentStreak: Int16
    let longestStreak: Int16

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.title)
                .foregroundColor(iconColor)
            Text("\(currentStreak)")
                .font(.title2)
                .fontWeight(.bold)
            Text(streakName)
                .font(.caption)
                .foregroundColor(.secondary)
//            Text("Best: \(longestStreak)")
//                .font(.caption2)
//                .foregroundColor(.gray)
        }
        .frame(minWidth: 0, maxWidth: .infinity)
    }
}

struct StreaksDisplayView_Previews: PreviewProvider {
    static var previews: some View {
        // To make preview work, ensure UserStatsManager is configured in a mock way if needed
        // For a simple preview, it might just show 0s if not configured.
        StreaksDisplayView()
            .padding()
    }
}
