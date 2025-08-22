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
    @State private var selection: AppScreen? = .today

    var body: some View {
        NavigationSplitView {
            Sidebar(selection: $selection)
                .environmentObject(subscriptionManager)
        } detail: {
            if let selection = selection {
                selection.destination
                    .environmentObject(subscriptionManager)
            } else {
                Text("Select a category")
            }
        }
    }
}

// MARK: - Sidebar & Navigation Model

enum AppScreen: CaseIterable, Identifiable {
    case today, workplaces, wellness, progress, profile
    
    var id: AppScreen { self }
    
    var label: Label<Text, Image> {
        switch self {
        case .today:
            return Label("Today", systemImage: "house.fill")
        case .workplaces:
            return Label("Workplaces", systemImage: "building.2.fill")
        case .wellness:
            return Label("Wellness", systemImage: "heart.fill")
        case .progress:
            return Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
        case .profile:
            return Label("Profile", systemImage: "person.circle.fill")
        }
    }
    
    @MainActor
    @ViewBuilder
    var destination: some View {
        switch self {
        case .today: TodayView()
        case .workplaces: WorkplaceListView()
        case .wellness: WellnessView()
        case .progress: UserProgressView()
        case .profile: ProfileView()
        }
    }
}

@MainActor
struct Sidebar: View {
    @Binding var selection: AppScreen?
    
    var body: some View {
        List(AppScreen.allCases, selection: $selection) { screen in
            screen.label
        }
        .navigationTitle("Fathom")
    }
}

// MARK: - Placeholder Settings View

struct OldSettingsView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    
    var body: some View {
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
