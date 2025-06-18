import SwiftUI

// MARK: - Reusable Components for Work Profile

struct WorkProfileSection: View {
    @Binding var selectedRole: WorkRole
    @Binding var selectedIndustry: WorkIndustry
    @State private var isShowingWhyPopover = false // State for popover
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("What's your primary role?")
                        .font(.headline)
                    Spacer()
                    Button {
                        isShowingWhyPopover = true
                    } label: {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                    .popover(isPresented: $isShowingWhyPopover, arrowEdge: .top) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Why We Ask")
                                .font(.headline)
                            Text("Providing your role and industry helps Fathom tailor relevant insights, wellness tips, and content specifically for your work context. This information is kept private and used only to enhance your app experience.")
                                .font(.caption)
                        }
                        .padding()
                        .frame(idealWidth: 300) // Suggest an ideal width for the popover
                    }
                }
                
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(WorkRole.allCases, id: \.self) { role in
                            RoleChip(role: role.rawValue.capitalized, isSelected: selectedRole == role) {
                                selectedRole = role
                            }
                        }
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                // Consider adding another info button here if separate explanations are needed,
                // or if the single popover above covers both adequately.
                Text("And your industry?")
                    .font(.headline)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(WorkIndustry.allCases, id: \.self) { industry in
                            IndustryChip(industry: industry.rawValue.capitalized, isSelected: selectedIndustry == industry) {
                                selectedIndustry = industry
                            }
                        }
                    }
                }
            }
        }
    }
}

struct RoleChip: View {
    let role: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(role)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.secondary.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

struct IndustryChip: View {
    let industry: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(industry)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.green : Color.secondary.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}
