//
//  JournalEntriesView.swift
//  Fathom
//
//  Created by Paul Thomas on 6/10/25.
//


import SwiftUI
import CoreData

// This view is similar in structure to the previous JournalEntriesView,
// but it is now tailored for 'JournalEntry' and has a more
// professional aesthetic.
struct JournalEntriesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \JournalEntry.timestamp, ascending: false)],
        animation: .default)
    private var journalEntries: FetchedResults<JournalEntry>
    @State private var isShowingNewEntryView = false
    @State private var searchText = ""
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var selectedFocusFilter: Int16 = 0 // 0 for All Focus Scores, 1-5 for specific ratings
    @State private var startDate: Date? = nil
    @State private var endDate: Date? = nil

    enum JournalSortOption: String, CaseIterable, Identifiable {
        case dateDescending = "Newest First"
        case dateAscending = "Oldest First"
        case focusDescending = "Highest Focus First"
        case focusAscending = "Lowest Focus First"
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
                            JournalEntryRow(entry: entry)
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
                        Picker("Filter by Focus", selection: $selectedFocusFilter) {
                            Text("All Focus Scores").tag(Int16(0))
                            ForEach(1...5, id: \.self) { score in
                                HStack {
                                    Text("Focus Score: \(score)")
                                    ForEach(1...score, id: \.self) { _ in
                                        Image(systemName: "star.fill").foregroundColor(.yellow)
                                    }
                                }.tag(Int16(score))
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
                        Image(systemName: selectedFocusFilter == 0 ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }

                    Button(action: { isShowingNewEntryView = true }) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $isShowingNewEntryView) {
                JournalEntryComposeView()
                    .environment(\.managedObjectContext, viewContext)
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
        // Apply search text filter
        var entries = Array(journalEntries)

        if !searchText.isEmpty {
            entries = entries.filter {
                ($0.text?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // Apply focus score filter
        if selectedFocusFilter != 0 { // 0 means 'All Focus Scores'
            entries = entries.filter { $0.moodRating == selectedFocusFilter }
        }

        // Apply date range filter
        if let start = startDate {
            entries = entries.filter { $0.timestamp ?? Date() >= start }
        }
        if let end = endDate {
            entries = entries.filter { $0.timestamp ?? Date() <= end }
        }

        // Apply sorting
        switch selectedSortOption {
        case .dateDescending:
            entries.sort { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }
        case .dateAscending:
            entries.sort { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }
        case .focusDescending:
            entries.sort { $0.moodRating > $1.moodRating }
        case .focusAscending:
            entries.sort { $0.moodRating < $1.moodRating }
        }

        return entries
        
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
}
