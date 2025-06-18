//
//  MainTabView.swift
//  Fathom
//
//  Created by Paul Thomas on 6/10/25.
//
// Fathom/MainTabView_Workplace.swift

import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case journal = "Journal"
    case dashboard = "Dashboard"
    case tools = "Tools"
    case settings = "Settings"
    
    var id: String { self.rawValue }
    
    var systemImageName: String {
        switch self {
        case .journal: return "book.fill"
        case .dashboard: return "chart.line.uptrend.xyaxis"
        case .tools: return "wrench.and.screwdriver.fill"
        case .settings: return "gearshape.2.fill"
        }
    }
}

struct MainTabView_Workplace: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var selectedTab: AppTab? = .dashboard

    private var tabSelection: Binding<AppTab> {
        Binding {
            selectedTab ?? .dashboard
        } set: {
            selectedTab = $0
        }
    }

    var body: some View {
        if horizontalSizeClass == .compact {
            // iPhone layout: Standard TabView
            TabView(selection: tabSelection) {
                content(for: .journal)
                    .tabItem { Label(AppTab.journal.rawValue, systemImage: AppTab.journal.systemImageName) }
                    .tag(AppTab.journal)
                
                content(for: .dashboard)
                    .tabItem { Label(AppTab.dashboard.rawValue, systemImage: AppTab.dashboard.systemImageName) }
                    .tag(AppTab.dashboard)
                
                content(for: .tools)
                    .tabItem { Label(AppTab.tools.rawValue, systemImage: AppTab.tools.systemImageName) }
                    .tag(AppTab.tools)
                
                content(for: .settings)
                    .tabItem { Label(AppTab.settings.rawValue, systemImage: AppTab.settings.systemImageName) }
                    .tag(AppTab.settings)
            }
        } else {
            // iPad layout: NavigationSplitView
            NavigationSplitView {
                List(selection: $selectedTab) {
                    ForEach(AppTab.allCases) { tabItem in
                        Label(tabItem.rawValue, systemImage: tabItem.systemImageName).tag(tabItem as AppTab?)
                    }
                }
                .navigationTitle("Fathom")
            } detail: {
                if let selectedTab {
                    content(for: selectedTab)
                } else {
                    Text("Select an item")
                }
            }
        }
    }
    
    // Helper function to return view for a given tab
    @ViewBuilder
    private func content(for tab: AppTab) -> some View {
        switch tab {
        case .journal:
            JournalEntriesView_Workplace()
        case .dashboard:
            InsightsView()
        case .tools:
            ToolsView()
        case .settings:
            SettingsView()
        }
    }
}

