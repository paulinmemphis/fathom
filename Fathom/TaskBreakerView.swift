//
//  TaskBreakerView.swift
//  Fathom
//
//  Created by Paul Thomas on 6/10/25.
//


import SwiftUI
import CoreData

/// Lightweight step model for Task Breaker
struct TBStep: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var done: Bool
}

/// A tool to help users break down overwhelming tasks into smaller, manageable steps.
struct TaskBreakerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var mainTask = ""
    @State private var steps: [TBStep] = [
        TBStep(title: "", done: false),
        TBStep(title: "", done: false),
        TBStep(title: "", done: false)
    ]
    @State private var editMode: EditMode = .inactive
    @State private var showCompose = false
    @State private var composeEntry: JournalEntry? = nil
    @State private var showingTimer = false

    private let suggestedChips: [String] = [
        "Define scope", "Draft outline", "Gather data", "Create slides", "List blockers", "Ask for feedback"
    ]

    private var nonEmptyStepsCount: Int { steps.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count }
    private var completedCount: Int { steps.filter { $0.done && !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count }
    private var progress: Double { nonEmptyStepsCount == 0 ? 0 : Double(completedCount) / Double(nonEmptyStepsCount) }

    var body: some View {
        List {
            Section("Overwhelming Task") {
                TextField("e.g., Prepare quarterly report", text: $mainTask)
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
            }
            
            Section("Break it Down") {
                ForEach($steps) { $step in
                    HStack(spacing: 10) {
                        Button(action: {
                            step.done.toggle()
                            AnalyticsService.shared.logEvent("tb_toggle_step", parameters: ["done": step.done])
                        }) {
                            Image(systemName: step.done ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(step.done ? .green : .secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(step.done ? "Mark step incomplete" : "Mark step complete")

                        TextField("e.g., Open the template document", text: $step.title)
                            .textInputAutocapitalization(.sentences)
                            .disableAutocorrection(false)
                    }
                }
                .onDelete { indexSet in
                    steps.remove(atOffsets: indexSet)
                    AnalyticsService.shared.logEvent("tb_remove_step", parameters: ["remaining": steps.count])
                }
                .onMove { indices, newOffset in
                    steps.move(fromOffsets: indices, toOffset: newOffset)
                    AnalyticsService.shared.logEvent("tb_reorder_step", parameters: ["count": steps.count])
                }

                Button {
                    steps.append(TBStep(title: "", done: false))
                    AnalyticsService.shared.logEvent("tb_add_step", parameters: ["count": steps.count])
                } label: {
                    Label("Add Step", systemImage: "plus.circle.fill")
                }
            }

            Section("Suggestions") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestedChips, id: \.self) { chip in
                            Button(chip) { addSuggestion(chip) }
                                .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Progress") {
                HStack {
                    Text("Completed")
                    Spacer()
                    Text("\(completedCount)/\(nonEmptyStepsCount)")
                        .foregroundColor(.secondary)
                }
                ProgressView(value: progress)
            }

            Section {
                Button("Add to Today's Focus") { addToToday() }
                    .disabled(mainTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || nonEmptyStepsCount == 0)

                if #available(iOS 16.1, *) {
                    Button("Start 25m Focus Timer") {
                        showingTimer = true
                        AnalyticsService.shared.logEvent("tb_start_focus_from_tb", parameters: ["planned_minutes": 25])
                    }
                }
            }
        }
        .environment(\.editMode, $editMode)
        .navigationTitle("Task Breaker")
        .toolbar { EditButton() }
        .onAppear {
            AnalyticsService.shared.logEvent("tb_open", parameters: ["prefilled_steps": steps.count])
        }
        .sheet(isPresented: $showCompose) {
            JournalEntryComposeView(entryToEdit: composeEntry)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingTimer) {
            if #available(iOS 16.1, *) {
                FocusTimerView()
            } else {
                Text("Focus Timer requires iOS 16.1 or later.")
            }
        }
    }

    private func addSuggestion(_ chip: String) {
        if let idx = steps.firstIndex(where: { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            steps[idx].title = chip
        } else {
            steps.append(TBStep(title: chip, done: false))
        }
    }

    private func addToToday() {
        // Create an unsaved entry and open compose view for review/editing before save
        let entry = JournalEntry(context: viewContext)
        entry.id = UUID()
        let checklist = makeChecklistContent()
        entry.text = makeChecklistTitle() + "\n" + checklist
        entry.timestamp = Date()
        entry.moodRating = 3
        entry.isDraft = true
        composeEntry = entry
        showCompose = true
        AnalyticsService.shared.logEvent("tb_add_to_today_focus", parameters: [
            "steps_count": nonEmptyStepsCount,
            "main_task_length": mainTask.count
        ])
    }

    private func makeChecklistTitle() -> String {
        mainTask.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func makeChecklistContent() -> String {
        let items = steps
            .map { step in (step.title.trimmingCharacters(in: .whitespacesAndNewlines), step.done) }
            .filter { !$0.0.isEmpty }
            .map { title, done in "- [\(done ? "x" : " ")] \(title)" }
        return items.joined(separator: "\n")
    }
}
