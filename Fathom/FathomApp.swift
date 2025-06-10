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

    init() {
        FirebaseApp.configure() // Configure Firebase
        // Configure WorkplaceManager with its dependencies
        // This ensures that the shared instance is ready before any UI that might use it.
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
            MainTabView_Workplace()
                .environmentObject(journalStore)
                .environmentObject(themeManager)
                .environmentObject(subscriptionManager)
                .environmentObject(appLockManager)
        }
    }
}
