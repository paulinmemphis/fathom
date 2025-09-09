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
    @State private var isGenerating = false
    @State private var rewritingStepId: UUID? = nil
    @State private var isRewritingAll = false
    @State private var isImprovingTitle = false
    @State private var selectedStyleHint: String = "productivity"

    private let aiService: AIService = AIServiceFactory.make()
    private let styleHints = ["productivity", "stress", "mindfulness", "connection"]

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

                        Spacer(minLength: 8)
                        Button {
                            rewriteStepAI(stepId: step.id)
                        } label: {
                            if rewritingStepId == step.id {
                                ProgressView().scaleEffect(0.7)
                            } else {
                                Image(systemName: "wand.and.stars")
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Rewrite step with AI")
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

            Section("AI Assistance") {
                Button {
                    generateStepsAI()
                } label: {
                    HStack {
                        if isGenerating { ProgressView() }
                        Label("Generate Steps", systemImage: "sparkles")
                    }
                }
                .disabled(isGenerating || mainTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text("On-device by default; cloud AI may be used if enabled in Settings.")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Picker("Tone", selection: $selectedStyleHint) {
                    ForEach(styleHints, id: \.self) { hint in
                        Text(hint.capitalized).tag(hint)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    rewriteAllStepsAI()
                } label: {
                    HStack {
                        if isRewritingAll { ProgressView() }
                        Label("Rewrite All Steps", systemImage: "wand.and.stars")
                    }
                }
                .disabled(isRewritingAll || steps.allSatisfy { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })

                Button {
                    improveTitleAI()
                } label: {
                    HStack {
                        if isImprovingTitle { ProgressView() }
                        Label("Improve Title", systemImage: "textformat")
                    }
                }
                .disabled(isImprovingTitle || mainTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

    // MARK: - AI Helpers
    private func generateStepsAI() {
        let title = mainTask.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        isGenerating = true
        let ctx = steps
            .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "; ")
        Task { @MainActor in
            let generated = (try? await aiService.breakDownTask(title: title, context: ctx.isEmpty ? nil : ctx, maxSteps: 6)) ?? []
            if !generated.isEmpty {
                // Fill empty slots first, then append
                for g in generated {
                    if let idx = steps.firstIndex(where: { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                        steps[idx].title = g
                        steps[idx].done = false
                    } else {
                        steps.append(TBStep(title: g, done: false))
                    }
                }
            }
            isGenerating = false
        }
    }

    private func rewriteStepAI(stepId: UUID) {
        guard let idx = steps.firstIndex(where: { $0.id == stepId }) else { return }
        let original = steps[idx].title
        guard !original.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        rewritingStepId = stepId
        Task { @MainActor in
            let rewritten = (try? await aiService.rewriteStep(original, styleHint: selectedStyleHint)) ?? original
            if let j = steps.firstIndex(where: { $0.id == stepId }) {
                steps[j].title = rewritten
            }
            rewritingStepId = nil
        }
    }

    private func rewriteAllStepsAI() {
        let indices = steps.indices.filter { !steps[$0].title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !indices.isEmpty else { return }
        isRewritingAll = true
        AnalyticsService.shared.logEvent("tb_rewrite_all_steps", parameters: ["count": indices.count])
        Task { @MainActor in
            for i in indices {
                let original = steps[i].title
                let rewritten = (try? await aiService.rewriteStep(original, styleHint: selectedStyleHint)) ?? original
                steps[i].title = rewritten
            }
            isRewritingAll = false
        }
    }

    private func improveTitleAI() {
        let title = mainTask.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        isImprovingTitle = true
        AnalyticsService.shared.logEvent("tb_improve_title", parameters: ["title_chars": title.count])
        Task { @MainActor in
            let rewritten = (try? await aiService.rewriteStep(title, styleHint: selectedStyleHint)) ?? title
            mainTask = rewritten
            isImprovingTitle = false
        }
    }
}
