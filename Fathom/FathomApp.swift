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
    init() {
        FirebaseApp.configure()
    }
    // MARK: - State Objects for Core Services
    @StateObject private var persistenceController = PersistenceController.shared
    @StateObject private var subscriptionManager = SubscriptionManager()
    @StateObject private var appLockManager = AppLockManager()
    @StateObject private var themeManager = ProfessionalThemeManager()
    @StateObject private var journalStore = WorkplaceJournalStore()
    @StateObject private var locationManager = LocationManager()

    @State private var isDataLoaded = false
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

    var body: some Scene {
        WindowGroup {
            if !isDataLoaded {
                ProgressView("Loading...")
                    .onAppear {
                        persistenceController.loadStore { error in
                    if let error = error {
                        // In a real app, you should show an error view to the user.
                        fatalError("Failed to load Core Data: \(error)")
                    }
                            isDataLoaded = true
                            // Configure other managers after data is loaded
                            UserStatsManager.shared.configure(context: persistenceController.container.viewContext)
                            AchievementManager.shared.configure(context: persistenceController.container.viewContext)
                            WorkplaceManager.configureShared(
                                viewContext: persistenceController.container.viewContext,
                                locationManager: locationManager,
                                subscriptionManager: subscriptionManager
                            )
                        }
                    }
            } else if showOnboarding {
                OnboardingView(isPresented: $showOnboarding)
            } else {
                MainTabView_Workplace()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
                    .environmentObject(subscriptionManager)
                    .environmentObject(appLockManager)
                    .environmentObject(themeManager)
                    .environmentObject(journalStore)
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()

    return true
  }
}

struct YourApp: App {
  // register app delegate for Firebase setup
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate


  var body: some Scene {
    WindowGroup {
      NavigationView {
        ContentView()
      }
    }
  }
}
