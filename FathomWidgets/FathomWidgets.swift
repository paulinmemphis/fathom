//
//  FathomWidgets.swift
//  FathomWidgets
//
//  Created by Paul Thomas on 6/10/25.
//

// FathomWidgets/FathomWidgets.swift

import WidgetKit
import SwiftUI
import AppIntents
import Combine


struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func snapshot(for configuration: QuickActionsConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date())
    }
    
    func timeline(for configuration: QuickActionsConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        let timeline = Timeline(entries: [SimpleEntry(date: Date())], policy: .atEnd)
        return timeline
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct FathomWidgetsEntryView : View {
    var body: some View {
        VStack {
            Text("Fathom Actions")
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// NO @main attribute here.
struct FathomWidgets: Widget {
    let kind: String = "FathomWidgets"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: QuickActionsConfigurationAppIntent.self, provider: Provider()) { entry in
            FathomWidgetsEntryView()
        }
        .configurationDisplayName("Fathom Quick Actions")
        .description("Start a focus session or capture a thought.")
        .supportedFamilies([.systemSmall])
    }
}
