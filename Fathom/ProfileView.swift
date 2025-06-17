import SwiftUI
import CoreData

struct ProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var personalizationEngine = PersonalizationEngine.shared
    @StateObject private var userStatsManager = UserStatsManager.shared
    
    @State private var showingSubscriptionView = false
    @State private var showingPersonalizationSettings = false
    @State private var showingNotificationSettings = false
    @State private var showingOnboarding = false
    @State private var showingAbout = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Profile Header
                    profileHeader
                    
                    // MARK: - Subscription Status
                    subscriptionStatusCard
                    
                    // MARK: - Settings Sections
                    settingsSection
                    
                    // MARK: - Support & Info
                    supportSection
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingSubscriptionView) {
            SubscriptionView()
        }
        .sheet(isPresented: $showingPersonalizationSettings) {
            PersonalizationSettingsView()
        }
        .sheet(isPresented: $showingNotificationSettings) {
            NotificationSettingsView()
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView(isPresented: $showingOnboarding)
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Profile Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Text(profileInitials)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 4) {
                Text(greetingText)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if subscriptionManager.isProUser {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        
                        Text("Fathom Pro")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Fathom Free")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Quick Stats
            HStack(spacing: 32) {
                ProfileStatView(
                    title: "Streak",
                    value: "\(userStatsManager.currentWorkSessionStreak)",
                    subtitle: "days"
                )
                
                ProfileStatView(
                    title: "Sessions",
                    value: "\(userStatsManager.totalWorkSessionsCompleted)",
                    subtitle: "total"
                )
                
                ProfileStatView(
                    title: "Hours",
                    value: "0", // Placeholder - would need to calculate from check-ins
                    subtitle: "worked"
                )
            }
        }
        .padding(.top, 16)
    }
    
    // MARK: - Subscription Status Card
    private var subscriptionStatusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subscriptionManager.isProUser ? "Fathom Pro" : "Upgrade to Pro")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(subscriptionManager.isProUser ? 
                         "Enjoying all Pro features" : 
                         "Unlock advanced insights and tools")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: subscriptionManager.isProUser ? "checkmark.seal.fill" : "star.fill")
                    .font(.title2)
                    .foregroundColor(subscriptionManager.isProUser ? .green : .yellow)
            }
            
            if subscriptionManager.isProUser {
                // Pro features list
                VStack(alignment: .leading, spacing: 8) {
                    ProfileProFeatureRow(icon: "brain.head.profile", text: "AI-Powered Insights", isActive: true)
                    ProfileProFeatureRow(icon: "location.fill", text: "Geofencing Auto Check-in", isActive: true)
                    ProfileProFeatureRow(icon: "bell.fill", text: "Smart Notifications", isActive: true)
                    ProfileProFeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Advanced Analytics", isActive: true)
                }
            } else {
                // Upgrade button
                Button(action: {
                    showingSubscriptionView = true
                }) {
                    HStack {
                        Image(systemName: "star.fill")
                            .font(.subheadline)
                        
                        Text("Upgrade to Pro")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
            }
        }
        .padding(20)
        .background(
            subscriptionManager.isProUser ?
            AnyView(Color.green.opacity(0.1)) :
            AnyView(LinearGradient(
                colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        )
        .cornerRadius(16)
    }
    
    // MARK: - Settings Section
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 0) {
                // Personalization Settings
                if subscriptionManager.isProUser {
                    SettingsRow(
                        icon: "brain.head.profile",
                        title: "Personalization",
                        subtitle: "Customize insights for your role",
                        color: .blue
                    ) {
                        showingPersonalizationSettings = true
                    }
                    
                    Divider()
                        .padding(.leading, 52)
                }
                
                // Notification Settings
                SettingsRow(
                    icon: "bell.fill",
                    title: "Notifications",
                    subtitle: "Manage alerts and reminders",
                    color: .orange
                ) {
                    showingNotificationSettings = true
                }
                
                Divider()
                    .padding(.leading, 52)
                
                // Subscription Management
                SettingsRow(
                    icon: subscriptionManager.isProUser ? "creditcard.fill" : "star.fill",
                    title: subscriptionManager.isProUser ? "Manage Subscription" : "Upgrade to Pro",
                    subtitle: subscriptionManager.isProUser ? "Billing and account settings" : "Unlock premium features",
                    color: subscriptionManager.isProUser ? .green : .purple
                ) {
                    showingSubscriptionView = true
                }
                
                if subscriptionManager.isProUser {
                    Divider()
                        .padding(.leading, 52)
                    
                    // Data Export (Pro feature)
                    SettingsRow(
                        icon: "square.and.arrow.up.fill",
                        title: "Export Data",
                        subtitle: "Download your workplace data",
                        color: .indigo
                    ) {
                        exportData()
                    }
                }
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Support Section
    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Support & Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 0) {
                // Onboarding Tutorial
                SettingsRow(
                    icon: "play.circle.fill",
                    title: "Tutorial",
                    subtitle: "Learn how to use Fathom",
                    color: .blue
                ) {
                    showingOnboarding = true
                }
                
                Divider()
                    .padding(.leading, 52)
                
                // About
                SettingsRow(
                    icon: "info.circle.fill",
                    title: "About Fathom",
                    subtitle: "Version, privacy policy, terms",
                    color: .gray
                ) {
                    showingAbout = true
                }
                
                Divider()
                    .padding(.leading, 52)
                
                // Contact Support
                SettingsRow(
                    icon: "envelope.fill",
                    title: "Contact Support",
                    subtitle: "Get help with your account",
                    color: .teal
                ) {
                    contactSupport()
                }
                
                Divider()
                    .padding(.leading, 52)
                
                // Rate App
                SettingsRow(
                    icon: "heart.fill",
                    title: "Rate Fathom",
                    subtitle: "Share your feedback on the App Store",
                    color: .red
                ) {
                    rateApp()
                }
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Helper Properties
    private var profileInitials: String {
        // For now, use generic initials. In a real app, this would come from user profile
        return "FM"
    }
    
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let greeting = switch hour {
        case 0..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
        return "\(greeting)!"
    }
    
    // MARK: - Helper Methods
    private func exportData() {
        // Implement data export functionality
        print("Exporting user data...")
    }
    
    private func contactSupport() {
        // Open email or support system
        if let url = URL(string: "mailto:support@fathomapp.com?subject=Fathom%20Support") {
            UIApplication.shared.open(url)
        }
    }
    
    private func rateApp() {
        // Open App Store rating
        if let url = URL(string: "https://apps.apple.com/app/id1234567890?action=write-review") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Supporting Views

struct ProfileStatView: View {
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct ProfileProFeatureRow: View {
    let icon: String
    let text: String
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(isActive ? .green : .gray)
                .frame(width: 20, height: 20)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(isActive ? .primary : .secondary)
            
            Spacer()
            
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 28, height: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct AboutView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // App Icon and Info
                    VStack(spacing: 16) {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        VStack(spacing: 4) {
                            Text("Fathom")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("Workplace Wellness Companion")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("Version 1.0.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
                    
                    // About Text
                    VStack(alignment: .leading, spacing: 16) {
                        Text("About Fathom")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("Fathom helps you maintain workplace wellness through intelligent tracking, personalized insights, and mindfulness tools. Track your work patterns, manage stress, and build healthy habits with AI-powered recommendations.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Features")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ProfileFeatureRow(icon: "location.fill", text: "Smart workplace tracking with geofencing")
                            ProfileFeatureRow(icon: "wind", text: "Guided breathing exercises for stress relief")  
                            ProfileFeatureRow(icon: "brain.head.profile", text: "AI-powered insights and recommendations")
                            ProfileFeatureRow(icon: "star.circle.fill", text: "Achievement system and progress tracking")
                            ProfileFeatureRow(icon: "bell.fill", text: "Contextual wellness notifications")
                        }
                    }
                    
                    // Legal Links
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Legal")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Button("Privacy Policy") {
                                // Open privacy policy
                            }
                            .foregroundColor(.blue)
                            
                            Button("Terms of Service") {
                                // Open terms
                            }
                            .foregroundColor(.blue)
                            
                            Button("Open Source Licenses") {
                                // Open licenses
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    
                    Spacer(minLength: 32)
                }
                .padding(.horizontal)
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(false)
        }
    }
}

struct ProfileFeatureRow: View {
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
        }
    }
}

// MARK: - Preview

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(SubscriptionManager())
    }
}
