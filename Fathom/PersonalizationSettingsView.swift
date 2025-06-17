import SwiftUI

struct PersonalizationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var personalizationEngine = PersonalizationEngine.shared
    @State private var selectedRole: WorkRole = .developer
    @State private var selectedIndustry: WorkIndustry = .technology
    @State private var insightComplexity: InsightComplexity = .intermediate
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    HeaderSection()
                    WorkProfileSection(selectedRole: $selectedRole, selectedIndustry: $selectedIndustry)
                    InsightComplexitySection(insightComplexity: $insightComplexity)
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("Personalization")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // Load current values when view appears
                selectedRole = await personalizationEngine.getCurrentUserRole()
                selectedIndustry = await personalizationEngine.getCurrentUserIndustry()
                insightComplexity = await personalizationEngine.getCurrentInsightComplexity()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Changes") {
                        Task {
                            await personalizationEngine.setUserProfile(role: selectedRole, industry: selectedIndustry)
                            await personalizationEngine.setInsightComplexity(insightComplexity)
                            await personalizationEngine.savePreferences()
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

struct HeaderSection: View {
    var body: some View {
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
    }
}

struct WorkProfileSection: View {
    @Binding var selectedRole: WorkRole
    @Binding var selectedIndustry: WorkIndustry
    
    var body: some View {
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
                                role: role.rawValue.capitalized,
                                isSelected: selectedRole == role
                            ) {
                                selectedRole = role
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Which industry do you work in?")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(WorkIndustry.allCases, id: \.self) { industry in
                            IndustryChip(
                                industry: industry.rawValue.capitalized,
                                isSelected: selectedIndustry == industry
                            ) {
                                selectedIndustry = industry
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct InsightComplexitySection: View {
    @Binding var insightComplexity: InsightComplexity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.green)
                Text("Insight Complexity")
                    .font(.headline)
            }
            
            VStack(spacing: 12) {
                ForEach(InsightComplexity.allCases, id: \.self) { level in
                    ComplexityRow(
                        level: level.rawValue.capitalized,
                        isSelected: insightComplexity == level
                    ) {
                        insightComplexity = level
                    }
                }
            }
            
            Text(complexityDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var complexityDescription: String {
        switch insightComplexity {
        case .basic:
            return "Simple, actionable insights for quick understanding"
        case .intermediate:
            return "Balanced insights with some analysis"
        case .advanced:
            return "Detailed analysis with in-depth patterns and correlations"
        }
    }
}

struct RoleChip: View {
    let role: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(role.capitalized)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct IndustryChip: View {
    let industry: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(industry.capitalized)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.green : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct ComplexityRow: View {
    let level: String
    let isSelected: Bool
    let action: () -> Void
    
    private var description: String {
        guard let complexity = InsightComplexity(rawValue: level.lowercased()) else {
            return ""
        }
        
        switch complexity {
        case .basic:
            return "Simple observations and affirmations"
        case .intermediate:
            return "Patterns and mild suggestions"
        case .advanced:
            return "Complex correlations and predictions"
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(level.capitalized)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    PersonalizationSettingsView()
}
