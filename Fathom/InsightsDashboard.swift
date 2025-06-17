//
//  InsightsDashboard.swift
//  Fathom
//
//  Created by Paul Thomas on 6/10/25.
//

import SwiftUI
import Charts

@available(iOS 16.0, *)
struct InsightsDashboard_Workplace: View {
    // This will now correctly find the WorkplaceJournalStore instance from the environment.
    @EnvironmentObject var journalStore: WorkplaceJournalStore

    var body: some View {
        NavigationView {
            if journalStore.entries.isEmpty {
                Text("Start journaling to see your dashboard.")
                    .navigationTitle("Dashboard")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        ChartCard(title: "Stress & Focus Trend") {
                            StressFocusChart(entries: journalStore.entries)
                        }
                    }
                    .padding()
                }
                .navigationTitle("Dashboard")
                .background(Color(.systemGroupedBackground))
            }
        }
    }
}

/// This helper view was missing from the target, causing the "Cannot find type" error.
struct ChartCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .padding([.top, .leading], 16)
            
            content
                .padding([.horizontal, .bottom], 16)
        }
        .background(Material.regularMaterial)
        .cornerRadius(16)
    }
}


@available(iOS 16.0, *)
struct StressFocusChart: View {
    let entries: [WorkplaceJournalEntry]

    var body: some View {
        Chart {
            ForEach(entries) { entry in
                if let stress = entry.stressLevel {
                    LineMark(
                        x: .value("Date", entry.date, unit: .day),
                        y: .value("Level", stress)
                    )
                    .foregroundStyle(by: .value("Metric", "Stress"))
                }
            }
            
            ForEach(entries) { entry in
                if let focus = entry.focusScore {
                    LineMark(
                        x: .value("Date", entry.date, unit: .day),
                        y: .value("Level", focus)
                    )
                    .foregroundStyle(by: .value("Metric", "Focus"))
                }
            }
        }
        .chartYScale(domain: 0...1)
        .frame(height: 250)
        .chartForegroundStyleScale([
            "Stress": Color.red,
            "Focus": Color.blue
        ])
    }
}
