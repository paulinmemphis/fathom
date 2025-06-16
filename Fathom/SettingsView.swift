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
    @State private var showingMailComposer = false
    @State private var showingSubscriptionSheet = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var showingOnboarding = false
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Subscription Section
                Section("Subscription") {
                    if subscriptionManager.isProUser {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                            Text("Fathom Pro")
                                .fontWeight(.medium)
                            Spacer()
                            Text("Active")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    } else {
                        Button(action: {
                            showingSubscriptionSheet = true
                        }) {
                            HStack {
                                Image(systemName: "star.circle.fill")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading) {
                                    Text("Upgrade to Pro")
                                        .fontWeight(.medium)
                                    Text("Unlock advanced features")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)
                    }
                    
                    Button(action: restorePurchases) {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .foregroundColor(.blue)
                            Text("Restore Purchases")
                        }
                    }
                }
                
                // MARK: - Support Section
                Section("Support") {
                    Button(action: sendFeedback) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.blue)
                            Text("Send Feedback")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    Button(action: rateApp) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("Rate Fathom")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    Button(action: {
                        showingOnboarding = true
                    }) {
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundColor(.blue)
                            Text("Onboarding")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                // MARK: - Legal Section
                Section("Legal") {
                    Button(action: openPrivacyPolicy) {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                                .foregroundColor(.green)
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    Button(action: openTermsOfService) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.blue)
                            Text("Terms of Service")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                // MARK: - App Info Section
                Section("About") {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "hammer.fill")
                            .foregroundColor(.orange)
                        Text("Build")
                        Spacer()
                        Text(buildNumber)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingSubscriptionSheet) {
                PaywallView_Workplace()
                    .environmentObject(subscriptionManager)
            }
            .sheet(isPresented: $showingMailComposer) {
                MailComposeView()
            }
            .sheet(isPresented: $showingOnboarding) {
                OnboardingView(isPresented: $showingOnboarding)
            }
            .alert(alertTitle, isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
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
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
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
