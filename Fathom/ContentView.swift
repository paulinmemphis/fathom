//
//  ContentView.swift
//  Fathom
//
//  Created by Paul Thomas on 6/10/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    var body: some View {
        TabView {
            // MARK: - Workplaces Tab
            WorkplaceListView()
                .tabItem {
                    Label("Workplaces", systemImage: "building.2.fill")
                }
                .environmentObject(subscriptionManager)

            // MARK: - Breathing Exercise Tab
            BreathingExerciseView()
                .tabItem {
                    Label("Breathe", systemImage: "wind")
                }

            // MARK: - Insights Tab
            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "brain.head.profile")
                }
                .environmentObject(subscriptionManager)

            // MARK: - Achievements Tab
            AchievementsView()
                .tabItem {
                    Label("Achievements", systemImage: "star.circle.fill")
                }
            
            // MARK: - Settings Tab (Placeholder)
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .environmentObject(subscriptionManager)
        }
        .onAppear {
            // Perform any initial setup when the main view appears
            print("Fathom app is running.")
        }
    }
}

// MARK: - Placeholder Settings View

struct OldSettingsView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Subscription")) {
                    if subscriptionManager.isProUser {
                        HStack {
                            Text("Status")
                            Spacer()
                            Text("Fathom Pro")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        NavigationLink(destination: PaywallView_Workplace()) {
                            Text("Upgrade to Pro")
                        }
                    }
                    
                    Button("Restore Purchases") {
                        Task {
                            await subscriptionManager.restorePurchases()
                        }
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}


// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let subManager = SubscriptionManager()
        // Simulate pro user for full feature preview
        subManager.isProUser = true
        
        return ContentView()
            .environmentObject(subManager)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
