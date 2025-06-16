//
//  FathomApp.swift
//  Fathom
//
//  Created by Paul Thomas on 6/10/25.
//

import SwiftUI
import CoreData // Added CoreData import
import FirebaseCore

@main



struct FathomApp: App {
    // MARK: - State Objects for Core Services
    @StateObject private var journalStore = WorkplaceJournalStore()
    @StateObject private var themeManager = ProfessionalThemeManager()
    @StateObject private var subscriptionManager = SubscriptionManager() // Re-using from previous for demo
    @StateObject private var appLockManager = AppLockManager()
    @StateObject private var locationManager = LocationManager() // Added LocationManager
    
    // Onboarding state
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    let persistenceController = PersistenceController.shared // Your Core Data stack

    init() {
        // FirebaseApp.configure() // Configure Firebase - TODO: Add GoogleService-Info.plist when ready
        // Configure WorkplaceManager with its dependencies
        // This ensures that the shared instance is ready before any UI that might use it.
        UserStatsManager.shared.configure(context: persistenceController.container.viewContext)
        AchievementManager.shared.configure(context: persistenceController.container.viewContext) // Configure AchievementManager
        WorkplaceManager.configureShared(
            viewContext: PersistenceController.shared.container.viewContext,
            locationManager: locationManager,
            subscriptionManager: subscriptionManager
        )
    }

    
    var body: some Scene {
        WindowGroup {
            // MainTabView is the root, with all services injected into the environment.
            // This architecture is clean, scalable, and easy to maintain.
            if showOnboarding {
                OnboardingView(isPresented: $showOnboarding)
            } else {
                MainTabView_Workplace()
                    .environmentObject(journalStore)
                    .environmentObject(themeManager)
                    .environmentObject(subscriptionManager)
                    .environmentObject(appLockManager)
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
            }
        }
    }
}
