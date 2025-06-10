//
//  ToolsView.swift
//  Fathom
//
//  Created by Paul Thomas on 6/10/25.
//


import SwiftUI

struct ToolsView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var isShowingPaywall = false

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Anxiety & Stress")) {
                    ToolNavigationLink(
                        destination: BreathingExerciseView(),
                        iconName: "wind",
                        title: "Guided Breathing",
                        subtitle: "Calm your mind in moments of high stress.",
                        isPro: true,
                        proStatus: subscriptionManager.isProUser,
                        showPaywall: $isShowingPaywall
                    )
                }
                
                Section(header: Text("Focus & Productivity")) {
                     ToolNavigationLink(
                        destination: FocusTimerView(),
                        iconName: "timer",
                        title: "Focus Timer",
                        subtitle: "Work in timed intervals to improve concentration.",
                        isPro: true,
                        proStatus: subscriptionManager.isProUser,
                        showPaywall: $isShowingPaywall
                    )
                    ToolNavigationLink(
                        destination: TaskBreakerView(),
                        iconName: "hammer.fill",
                        title: "Task Breaker",
                        subtitle: "Break down overwhelming tasks into small steps.",
                        isPro: true,
                        proStatus: subscriptionManager.isProUser,
                        showPaywall: $isShowingPaywall
                    )
                }
            }
            .navigationTitle("Wellness Toolkit")
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView_Workplace() // A new paywall for these specific features
            }
        }
    }
}

// A reusable navigation link for the tools list
struct ToolNavigationLink<Destination: View>: View {
    let destination: Destination
    let iconName: String
    let title: String
    let subtitle: String
    let isPro: Bool
    let proStatus: Bool
    @Binding var showPaywall: Bool

    var body: some View {
        if !isPro || proStatus {
            NavigationLink(destination: destination) {
                ToolRow(iconName: iconName, title: title, subtitle: subtitle)
            }
        } else {
            Button(action: { showPaywall = true }) {
                HStack {
                    ToolRow(iconName: iconName, title: title, subtitle: subtitle)
                    Spacer()
                    Image(systemName: "lock.fill")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

struct ToolRow: View {
     let iconName: String
     let title: String
     let subtitle: String

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}
