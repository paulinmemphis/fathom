//
//  JournalEntriesView.swift
//  Fathom
//
//  Created by Paul Thomas on 6/10/25.
//


import SwiftUI

// This view is similar in structure to the previous JournalEntriesView,
// but it is now tailored for 'WorkplaceJournalEntry' and has a more
// professional aesthetic.
@available(iOS 16.0, *)
struct JournalEntriesView_Workplace: View {
    @EnvironmentObject var journalStore: WorkplaceJournalStore
    @State private var isShowingNewEntryView = false
    @State private var searchText = ""

    var body: some View {
        NavigationView {
            // The list of journal entries
            List {
                ForEach(filteredEntries) { entry in
                    WorkplaceJournalRow(entry: entry)
                }
            }
            .navigationTitle("Workplace Journal")
            .searchable(text: $searchText)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { isShowingNewEntryView = true }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $isShowingNewEntryView) {
                WorkplaceJournalComposeView()
                    .environmentObject(journalStore)
            }
        }
    }
    
    var filteredEntries: [WorkplaceJournalEntry] {
        if searchText.isEmpty {
            return journalStore.entries
        } else {
            return journalStore.entries.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.text.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

// A view for a single row in the journal list
struct WorkplaceJournalRow: View {
    let entry: WorkplaceJournalEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.title)
                .font(.headline)
            
            Text(entry.date, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)

            if let projects = entry.workProjects, !projects.isEmpty {
                HStack {
                    ForEach(projects, id: \.self) { project in
                        Text(project)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
