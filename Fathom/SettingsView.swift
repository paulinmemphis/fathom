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
