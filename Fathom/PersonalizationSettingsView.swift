import SwiftUI

struct PersonalizationSettingsView: View {
    @StateObject private var personalizationEngine = PersonalizationEngine.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)
                        
                        Text("Personalization Settings")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Help us understand your work style to provide better insights")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    // Work Profile Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "briefcase.fill")
                                .foregroundColor(.blue)
                            Text("Work Profile")
                                .font(.headline)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("What's your primary role?")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(WorkRole.allCases, id: \.self) { role in
                                        RoleChip(
                                            role: role,
                                            isSelected: personalizationEngine.userRole == role
                                        ) {
                                            personalizationEngine.setUserProfile(
                                                role: role,
                                                industry: personalizationEngine.userIndustry
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("What industry do you work in?")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(WorkIndustry.allCases, id: \.self) { industry in
                                        IndustryChip(
                                            industry: industry,
                                            isSelected: personalizationEngine.userIndustry == industry
                                        ) {
                                            personalizationEngine.setUserProfile(
                                                role: personalizationEngine.userRole,
                                                industry: industry
                                            )
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    
                    // Insight Complexity Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundColor(.green)
                            Text("Insight Complexity")
                                .font(.headline)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Current Level: \(personalizationEngine.insightComplexity.description)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("Your insight complexity level is automatically adjusted based on your engagement with the app. As you use Fathom more, you'll unlock more sophisticated insights and predictions.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ProgressView(value: Double(personalizationEngine.insightComplexity.rawValue), total: 4.0)
                                .progressViewStyle(LinearProgressViewStyle(tint: .green))
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    
                    // Engagement Statistics Section
                    if !personalizationEngine.userPreferences.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "chart.bar.fill")
                                    .foregroundColor(.orange)
                                Text("Insight Preferences")
                                    .font(.headline)
                            }
                            
                            VStack(spacing: 8) {
                                ForEach(Array(personalizationEngine.userPreferences.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { insightType in
                                    if let preference = personalizationEngine.userPreferences[insightType] {
                                        PreferenceRow(insightType: insightType, preference: preference)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    }
                    
                    // Tips Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                            Text("Personalization Tips")
                                .font(.headline)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            TipRow(icon: "hand.tap", text: "Interact with insights to improve recommendations")
                            TipRow(icon: "bell", text: "Contextual notifications adapt to your work patterns")
                            TipRow(icon: "chart.line.uptrend.xyaxis", text: "Insight complexity grows with your engagement")
                            TipRow(icon: "person.crop.circle", text: "Role-specific insights are tailored to your work style")
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
                .padding()
            }
            .navigationTitle("Personalization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct RoleChip: View {
    let role: WorkRole
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(role.rawValue)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct IndustryChip: View {
    let industry: WorkIndustry
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(industry.rawValue)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PreferenceRow: View {
    let insightType: InsightType
    let preference: UserPreference
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(insightType.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Engagement: \(Int(preference.engagementScore * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            CircularProgressView(progress: preference.engagementScore)
        }
        .padding(.vertical, 4)
    }
}

struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 3)
                .frame(width: 24, height: 24)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 24, height: 24)
                .rotationEffect(.degrees(-90))
        }
    }
}

struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    PersonalizationSettingsView()
}
