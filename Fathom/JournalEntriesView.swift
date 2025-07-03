//
//  JournalEntriesView.swift
//  Fathom
//
//  Created by Paul Thomas on 6/10/25.
//


import SwiftUI
import CoreData

// This view is similar in structure to the previous JournalEntriesView,
// but it is now tailored for 'WorkplaceJournalEntry' and has a more
// professional aesthetic.
struct JournalEntriesView_Workplace: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [], // Temporarily remove the sort descriptor to avoid the timestamp error
        animation: .default)
    private var journalEntries: FetchedResults<JournalEntry>
    @State private var isShowingNewEntryView = false
    @State private var searchText = ""
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var selectedMoodFilter: Int16 = 0 // 0 for All Moods, 1-5 for specific ratings
    @State private var startDate: Date? = nil
    @State private var endDate: Date? = nil

    enum JournalSortOption: String, CaseIterable, Identifiable {
        case dateDescending = "Newest First"
        case dateAscending = "Oldest First"
        case moodDescending = "Highest Mood First"
        case moodAscending = "Lowest Mood First"
        var id: String { self.rawValue }
    }
    @State private var selectedSortOption: JournalSortOption = .dateDescending

    var body: some View {
        NavigationView {
            Group {
                if filteredEntries.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(filteredEntries) { entry in
                            WorkplaceJournalRow(entry: entry)
                        }
                        .onDelete(perform: deleteEntry)
                    }
                }
            }
            .navigationTitle("Workplace Journal")
            .navigationBarTitleDisplayMode(.automatic) // Added for iPadOS consistency
            .searchable(text: $searchText)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Menu {
                        Picker("Filter by Mood", selection: $selectedMoodFilter) {
                            Text("All Moods").tag(Int16(0))
                            ForEach(1...5, id: \.self) { mood in
                                HStack {
                                    Text("Mood Rating: \(mood)")
                                    ForEach(1...mood, id: \.self) { _ in
                                        Image(systemName: "star.fill").foregroundColor(.yellow)
                                    }
                                }.tag(Int16(mood))
                            }
                        }
                        .pickerStyle(.inline)
                        
                        Divider()
                        
                        Text("Filter by Date Range").font(.caption).foregroundColor(.secondary)
                        
                                                DatePicker(
                            "Start Date",
                            selection: Binding(get: { startDate ?? Date() }, set: { startDate = $0 }),
                            displayedComponents: .date
                        )
                        
                                                DatePicker(
                            "End Date",
                            selection: Binding(get: { endDate ?? Date() }, set: { endDate = $0 }),
                            in: (startDate ?? .distantPast)...Date(), // End date cannot be before start date or in the future
                            displayedComponents: .date
                        )
                        
                        if startDate != nil || endDate != nil {
                            Button("Clear Date Filters", role: .destructive) {
                                startDate = nil
                                endDate = nil
                            }
                        }
                        
                        Divider()
                        Text("Sort By").font(.caption).foregroundColor(.secondary)
                        Picker("Sort By", selection: $selectedSortOption) {
                            ForEach(JournalSortOption.allCases) {
                                option in Text(option.rawValue).tag(option)
                            }
                        }
                        
                    } label: {
                        Image(systemName: selectedMoodFilter == 0 ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }

                    Button(action: { isShowingNewEntryView = true }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $isShowingNewEntryView) {
                WorkplaceJournalComposeView()
                    
            }
        }
    }
    
    private func deleteEntry(at offsets: IndexSet) {
        offsets.map { filteredEntries[$0] }.forEach(viewContext.delete)

        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }

    var filteredEntries: [JournalEntry] {
        // Return all entries without filtering to avoid accessing properties that cause crashes
        // This is a temporary workaround until the Core Data model/codegen sync issue is resolved
        return Array(journalEntries)
        
        /* Original filtering code commented out to prevent crashes
        var entries = Array(journalEntries)

        // Apply search text filter
        if !searchText.isEmpty {
            entries = entries.filter {
                ($0.text?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // Apply mood filter
        if selectedMoodFilter != 0 { // 0 means 'All Moods'
            entries = entries.filter { $0.moodRating == selectedMoodFilter }
        }
        
        // Apply date range filter and sorting code also removed to prevent crashes
        
        return entries
        */
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            // Content VStack
            VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("Your Journal is Empty")
                .font(.headline)
            Text("Tap the compose button to add your first workplace reflection. Track projects, feelings, and accomplishments.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button(action: { isShowingNewEntryView = true }) {
                Text("Create First Entry")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .frame(maxWidth: horizontalSizeClass == .compact ? .infinity : 500) // Constrain width on wider screens
        }
        .padding()
    }
}

// A view for a single row in the journal list
struct WorkplaceJournalRow: View {
    let entry: JournalEntry
    
    var body: some View {
        NavigationLink(destination: WorkplaceJournalComposeView(entryToEdit: entry)) {
            VStack(alignment: .leading, spacing: 6) {
                // Using static placeholder content to avoid accessing JournalEntry properties
                // that are causing unrecognized selector crashes
                Text("Journal Entry")
                    .font(.headline)
                    .lineLimit(2)
                
                Text(Date(), style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Static placeholder for mood rating
                HStack {
                    Text("Mood:")
                        .font(.caption2)
                    ForEach(1...3, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption2)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}
}
