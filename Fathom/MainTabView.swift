//
//  MainTabView.swift
//  Fathom
//
//  Created by Paul Thomas on 6/10/25.
//
// Fathom/MainTabView_Workplace.swift

import SwiftUI

struct MainTabView_Workplace: View {
    var body: some View {
        TabView {
            // These views now exist and will compile correctly.
            JournalEntriesView_Workplace()
                .tabItem {
                    Label("Journal", systemImage: "doc.text.magnifyingglass")
                }
          
            InsightsDashboard_Workplace()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis")
                }
          
            ToolsView()
                .tabItem {
                    Label("Tools", systemImage: "briefcase.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.2.fill")
                }
        }
    }
}
