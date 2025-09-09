//
//  SettingsView.swift
//  Fathom
//
//  Created by Paul Thomas on 6/10/25.
//

import SwiftUI
import MessageUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.requestReview) private var requestReview
    @State private var showingMailComposer = false
    @State private var showingSubscriptionSheet = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var isOnboardingPresented = false
    @State private var enableAnalytics = false
    @StateObject private var aiGate = AIFeatureGate.shared
    // Reminders
    @State private var dailyReminderEnabled: Bool = false
    @State private var dailyReminderTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Subscription Section
                Section("Account") {
                    NavigationLink {
                        SubscriptionView()
                    } label: {
                        Label("Subscription", systemImage: "crown.fill")
                    }

                // MARK: - Reminders
                Section("Reminders") {
                    Toggle(isOn: $dailyReminderEnabled) {
                        Label("Daily Focus Reminder", systemImage: "bell")
                    }
                    .onChange(of: dailyReminderEnabled) { newValue in
                        UserDefaults.standard.set(newValue, forKey: Self.kDailyReminderEnabled)
                        if newValue {
                            NotificationManager.shared.requestAuthorization()
                            scheduleDailyReminder()
                            AnalyticsService.shared.logEvent("reminder_daily_focus_enabled", parameters: ["enabled": true])
                        } else {
                            NotificationManager.shared.cancelDailyFocusReminder()
                            AnalyticsService.shared.logEvent("reminder_daily_focus_enabled", parameters: ["enabled": false])
                        }
                    }

                    DatePicker(
                        "Reminder Time",
                        selection: $dailyReminderTime,
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.compact)
                    .disabled(!dailyReminderEnabled)
                    .onChange(of: dailyReminderTime) { _ in
                        UserDefaults.standard.set(dailyReminderTime.timeIntervalSince1970, forKey: Self.kDailyReminderTime)
                        if dailyReminderEnabled {
                            scheduleDailyReminder()
                            AnalyticsService.shared.logEvent("reminder_daily_focus_time_changed", parameters: [
                                "hour": Calendar.current.component(.hour, from: dailyReminderTime),
                                "minute": Calendar.current.component(.minute, from: dailyReminderTime)
                            ])
                        }
                    }
                }
                }
                
                // MARK: - Personalization Section
                Section("Personalization") {
                    NavigationLink {
                        PersonalizationSettingsView()
                    } label: {
                        Label("Work Profile & Insights", systemImage: "brain.head.profile")
                    }
                    
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label("Smart Notifications", systemImage: "bell.badge")
                    }
                }
                
                // MARK: - App Settings Section
                Section("App Settings") {
                    Button {
                        isOnboardingPresented = true
                    } label: {
                        Label("Onboarding", systemImage: "questionmark.circle")
                    }
                    
                    Toggle(isOn: $enableAnalytics) {
                        Label("Analytics", systemImage: "chart.bar")
                    }
                }
                
                // MARK: - AI Features Section
                Section("AI Features") {
                    Toggle(isOn: $aiGate.userOptIn) {
                        Label("Enable AI Features", systemImage: "brain.head.profile")
                    }
                    .accessibilityLabel("Enable AI Features")
                    
                    Button {
                        aiGate.refreshRemoteConfig()
                    } label: {
                        Label("Refresh AI Settings", systemImage: "arrow.clockwise")
                    }
                    .disabled(!aiGate.userOptIn)
                    
                    HStack {
                        Text("Cloud AI")
                        Spacer()
                        Text(aiGate.allowsCloudAI ? "On" : "Off")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Summarization")
                        Spacer()
                        Text(aiGate.allowsCloudSummarization ? "On" : "Off")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Rewrites")
                        Spacer()
                        Text(aiGate.allowsCloudRewrite ? "On" : "Off")
                            .foregroundColor(.secondary)
                    }
                }
                
                // MARK: - Support Section
                Section("Support") {
                    Link(destination: URL(string: "mailto:support@fathomapp.com")!) {
                        Label("Contact Support", systemImage: "envelope")
                    }
                    
                    Link(destination: URL(string: "https://fathomapp.com/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    
                    Link(destination: URL(string: "https://fathomapp.com/terms")!) {
                        Label("Terms of Service", systemImage: "doc.text")
                    }
                }
                
                // MARK: - App Info Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "hammer.fill")
                            .foregroundColor(.orange)
                        Text("Build")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.automatic) // Added for iPadOS consistency
            .onAppear {
                // Refresh RC on entry to Settings
                aiGate.refreshRemoteConfig()
                // Load reminder defaults
                let enabled = UserDefaults.standard.bool(forKey: Self.kDailyReminderEnabled)
                dailyReminderEnabled = enabled
                if let stored = UserDefaults.standard.object(forKey: Self.kDailyReminderTime) as? TimeInterval {
                    dailyReminderTime = Date(timeIntervalSince1970: stored)
                }
                if enabled {
                    // Re-schedule on appear to ensure system has it after reinstalls or permission changes
                    scheduleDailyReminder()
                }
            }
            .onChange(of: aiGate.userOptIn) { newValue in
                AnalyticsService.shared.logEvent("ai_opt_in_changed", parameters: [
                    "opt_in": newValue
                ])
                AnalyticsService.shared.setUserProperty(newValue ? "true" : "false", forName: "ai_opt_in")
            }
            .sheet(isPresented: $showingSubscriptionSheet) {
                PaywallView_Workplace()
                    .environmentObject(subscriptionManager)
            }
            .sheet(isPresented: $showingMailComposer) {
                MailComposeView()
            }
            .sheet(isPresented: $isOnboardingPresented) {
                OnboardingView(isPresented: $isOnboardingPresented)
            }
            .alert(alertTitle, isPresented: $showingAlert, actions: {
                Button("OK") { }
            }, message: {
                Text(alertMessage)
            })
        }
    }
    
    // MARK: - Helper Properties
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    // MARK: - Actions
    
    private func restorePurchases() {
        Task {
            await subscriptionManager.restorePurchases()
            await MainActor.run {
                alertTitle = "Restore Purchases"
                if let error = subscriptionManager.purchaseError {
                    alertMessage = error
                } else {
                    alertMessage = "Purchases restored successfully!"
                }
                showingAlert = true
            }
        }
    }
    
    private func sendFeedback() {
        if MFMailComposeViewController.canSendMail() {
            showingMailComposer = true
        } else {
            alertTitle = "Email Not Available"
            alertMessage = "Please set up Mail app to send feedback, or contact us at support@fathomapp.com"
            showingAlert = true
        }
    }
    
    private func rateApp() {
        requestReview()
    }
    
    private func openPrivacyPolicy() {
        if let url = URL(string: "https://fathomapp.com/privacy") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openTermsOfService() {
        if let url = URL(string: "https://fathomapp.com/terms") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Mail Composer

struct MailComposeView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setSubject("Fathom App Feedback")
        composer.setToRecipients(["support@fathomapp.com"])
        
        // Add device info for debugging
        let deviceInfo = """
        
        ---
        Device Info:
        iOS Version: \(UIDevice.current.systemVersion)
        Device Model: \(UIDevice.current.model)
        App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
        Build: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
        """
        
        composer.setMessageBody("Hi Fathom team,\n\n\(deviceInfo)", isHTML: false)
        
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, @preconcurrency MFMailComposeViewControllerDelegate {
        let parent: MailComposeView
        
        init(_ parent: MailComposeView) {
            self.parent = parent
        }
        
        @MainActor
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.dismiss()
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SubscriptionManager())
}

// MARK: - Reminder Helpers and Keys
extension SettingsView {
    private static let kDailyReminderEnabled = "reminder.daily.focus.enabled"
    private static let kDailyReminderTime = "reminder.daily.focus.time"

    private func scheduleDailyReminder() {
        let hour = Calendar.current.component(.hour, from: dailyReminderTime)
        let minute = Calendar.current.component(.minute, from: dailyReminderTime)
        NotificationManager.shared.scheduleDailyFocusReminder(hour: hour, minute: minute)
    }
}
