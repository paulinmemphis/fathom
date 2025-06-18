//
//  CorporateDashboardView.swift
//  Fathom
//
//  Created by Paul Thomas on 6/10/25.
//


import SwiftUI
import Charts

// MARK: - Chart Card View

struct ChartCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
                .padding([.top, .leading])
            
            content
                .padding([.horizontal, .bottom])
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

/// A conceptual view demonstrating what an HR or team lead might see.
/// IMPORTANT: This data is fully anonymized and aggregated. No individual data is ever shared.
struct CorporateDashboardView: View {
    // This data would be securely aggregated from the team's devices
    // using technologies like Differential Privacy to ensure anonymity.
    let anonymizedData = AnonymizedTeamData.sample
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Team Wellness Overview")
                        .font(.largeTitle.weight(.bold))
                        .padding(.horizontal)
                    
                    ChartCard(title: "Team Stress Level (Weekly Average)") {
                        Chart(anonymizedData.stressTrend) { data in
                            LineMark(
                                x: .value("Week", data.week),
                                y: .value("Stress Level", data.averageStress)
                            )
                            .foregroundStyle(Color.red.gradient)
                        }
                        .chartYScale(domain: 0...1)
                        .frame(height: 200)
                    }
                    
                    ChartCard(title: "Top Workplace Challenges") {
                        Chart(anonymizedData.topChallenges) { challenge in
                            BarMark(
                                x: .value("Mentions", challenge.mentions),
                                y: .value("Challenge", challenge.topic)
                            )
                            .foregroundStyle(by: .value("Topic", challenge.topic))
                        }
                        .chartLegend(.hidden)
                    }
                    
                    // A list of proactive, anonymized insights for leadership
                    Section(header: Text("Actionable Insights").font(.title2).padding()) {
                        ForEach(anonymizedData.actionableInsights, id: \.self) { insight in
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.yellow)
                                Text(insight)
                            }
                            .padding()
                            .background(.background)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Corporate Dashboard")
            .background(Color(.systemGroupedBackground))
        }
    }
}

// MARK: - Sample Data for B2B Demo
struct AnonymizedTeamData {
    struct StressPoint: Identifiable {
        let id = UUID()
        let week: String
        let averageStress: Double
    }
    struct Challenge: Identifiable {
        let id = UUID()
        let topic: String
        let mentions: Int
    }
    
    let stressTrend: [StressPoint]
    let topChallenges: [Challenge]
    let actionableInsights: [String]
    
    static let sample = AnonymizedTeamData(
        stressTrend: [
            .init(week: "Week 1", averageStress: 0.4),
            .init(week: "Week 2", averageStress: 0.6),
            .init(week: "Week 3", averageStress: 0.7),
            .init(week: "Week 4", averageStress: 0.5)
        ],
        topChallenges: [
            .init(topic: "Deadlines", mentions: 45),
            .init(topic: "Meeting Load", mentions: 32),
            .init(topic: "Cross-team Sync", mentions: 18)
        ],
        actionableInsights: [
            "Stress related to deadlines peaked in Week 3. Consider reviewing project timelines.",
            "A high number of entries mention 'meetings'. Exploring a 'no-meeting day' could improve focus."
        ]
    )
}
