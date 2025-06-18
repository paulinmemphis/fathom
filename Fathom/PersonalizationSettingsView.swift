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
