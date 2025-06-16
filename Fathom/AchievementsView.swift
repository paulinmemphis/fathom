import SwiftUI

struct AchievementsView: View {
    @StateObject private var achievementManager = AchievementManager.shared

    var body: some View {
        NavigationView {
            List {
                ForEach(AchievementCategory.allCases) { category in
                    let achievementsInCategory = achievementManager.achievementStatuses.filter { $0.definition.category == category }
                    if !achievementsInCategory.isEmpty {
                        Section(header: Text(category.rawValue).font(.headline)) {
                            ForEach(achievementsInCategory) { achievementData in
                                AchievementRow(achievementData: achievementData)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Achievements")
            .onAppear {
                // Data should be loaded by AchievementManager's configure method at app start
                // If direct refresh is needed: achievementManager.loadAndProcessAchievements() // or a more specific refresh method
            }
        }
    }
}

struct AchievementRow: View {
    let achievementData: AchievementManager.AchievementDisplayData

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: achievementData.definition.iconName)
                .font(.title)
                .frame(width: 40, height: 40)
                .foregroundColor(achievementData.isUnlocked ? .accentColor : .gray)
                .opacity(achievementData.isUnlocked ? 1.0 : 0.6)

            VStack(alignment: .leading) {
                Text(achievementData.definition.name)
                    .font(.headline)
                    .foregroundColor(achievementData.isUnlocked ? .primary : .secondary)
                Text(achievementData.definition.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                if achievementData.isUnlocked, let unlockedDate = achievementData.unlockedDate {
                    Text("Unlocked: \(unlockedDate, style: .date)")
                        .font(.caption)
                        .foregroundColor(.green)
                } else if !achievementData.isUnlocked {
                    // Placeholder for progress if we add it
                    // Text("Progress: ...")
                    //    .font(.caption)
                    //    .foregroundColor(.orange)
                }
            }
            Spacer()
            if achievementData.isUnlocked {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            }
        }
        .padding(.vertical, 8)
    }
}

struct AchievementsView_Previews: PreviewProvider {
    static var previews: some View {
        // To make previews work, we need to ensure AchievementManager is configured
        // and has some sample data. This might require a bit of setup.
        let manager = AchievementManager.shared
        // In a real preview, you'd want to inject a configured context
        // and potentially mock some UserStats to see achievements unlock.
        // For now, this will show the basic layout.
        
        // Example: Manually populating for preview purposes
        // This is a simplified approach. A better preview would involve a mock context.
        if manager.achievementStatuses.isEmpty {
            let sampleDefinitions = AchievementsList.all.prefix(3)
            manager.achievementStatuses = sampleDefinitions.map { def in
                AchievementManager.AchievementDisplayData(
                    definition: def, 
                    isUnlocked: def.id == AchievementsList.all.first?.id, // Unlock the first one for preview
                    unlockedDate: def.id == AchievementsList.all.first?.id ? Date() : nil
                )
            }
        }

        return AchievementsView()
            .environmentObject(manager) // Ensure the view can access the manager
    }
}
