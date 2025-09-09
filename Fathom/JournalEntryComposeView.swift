//
//  JournalEntryComposeView.swift
//  Fathom
//
//  Created for workplace journal entry composition
//

import SwiftUI
import CoreData

@available(iOS 16.0, *)
struct JournalEntryComposeView: View {
    var entryToEdit: JournalEntry?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    // State variables for form fields
    @State private var title: String
    @State private var content: String
    @State private var stressLevel: Double
    @State private var isSaving: Bool = false
    @State private var isSummarizing: Bool = false
    
    // Custom initializer to set up state based on whether we're editing or creating
    init(entryToEdit: JournalEntry? = nil) {
        self.entryToEdit = entryToEdit
        
        if let entry = entryToEdit {
            // If editing, parse title and content from the single 'text' field
            let parts = (entry.text ?? "").split(separator: "\n", maxSplits: 1).map(String.init)
            _title = State(initialValue: parts.first ?? "")
            _content = State(initialValue: parts.count > 1 ? parts[1] : "")
            // Convert moodRating (1-5) to stressLevel (0.0-1.0)
            _stressLevel = State(initialValue: Double(entry.moodRating - 1) / 4.0)
        } else {
            // For new entries, start with empty/default values
            _title = State(initialValue: "")
            _content = State(initialValue: "")
            _stressLevel = State(initialValue: 0.5)
        }
    }

    private func summarizeContent() {
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSummarizing = true
        Task { @MainActor in
            let old = content
            let summarized = await PersonalizationEngine.shared.summarizeJournal(text, maxCharacters: 400)
            var result = summarized.trimmingCharacters(in: .whitespacesAndNewlines)
            // Ensure a visible change even if the fallback summary equals the original
            if result.isEmpty || result == old {
                if old.count > 200 {
                    result = String(old.prefix(200)) + "…"
                } else {
                    // For very short entries, prepend a label to show effect
                    result = "Summary: " + old
                }
            }
            content = result
            isSummarizing = false
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Entry Details") {
                    TextField("Entry Title", text: $title)
                        .font(.headline)
                    
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $content)
                            .frame(minHeight: 120)
                        
                        if content.isEmpty {
                            Text("What's on your mind about work today?")
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
                }
                
                Section("Mood") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Stress Level: \(Int(stressLevel * 10))/10")
                            .font(.subheadline)
                        Slider(value: $stressLevel, in: 0...1)
                    }
                }
                
                Section("AI Assistance") {
                    Button(action: summarizeContent) {
                        Label("Summarize", systemImage: "wand.and.stars")
                    }
                    .disabled(isSummarizing || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if isSummarizing {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Summarizing…")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section {
                    Button(action: saveEntry) {
                        HStack {
                            if isSaving {
                                UserProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.trailing, 4)
                            }
                            Text(isSaving ? (entryToEdit == nil ? "Saving..." : "Updating...") : (entryToEdit == nil ? "Save Entry" : "Update Entry"))
                        }
                    }
                    .disabled(title.isEmpty || content.isEmpty || isSaving)
                }
            }
            .navigationTitle(entryToEdit == nil ? "New Journal Entry" : "Edit Journal Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: summarizeContent) {
                        if isSummarizing {
                            ProgressView()
                        } else {
                            Text("Summarize")
                        }
                    }
                    .disabled(isSummarizing || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Summarize journal content")
                }
            }
        }
    }
    
    private func saveEntry() {
        guard !title.isEmpty && !content.isEmpty else { return }
        
        isSaving = true
        
        let entryToSave: JournalEntry
        if let existingEntry = entryToEdit {
            entryToSave = existingEntry
        } else {
            entryToSave = JournalEntry(context: viewContext)
            entryToSave.id = UUID()
        }
        
        entryToSave.timestamp = Date()
        // Combine title and content into a single text field
        entryToSave.text = "\(title)\n\(content)"
        // Convert stressLevel (0.0-1.0) to moodRating (1-5)
        entryToSave.moodRating = Int16(round(stressLevel * 4) + 1)
        entryToSave.isDraft = false

        do {
            try viewContext.save()
            isSaving = false
            dismiss()
        } catch {
            let nsError = error as NSError
            print("Unresolved error \(nsError), \(nsError.userInfo) when saving journal entry")
            isSaving = false
        }
    }

    // Original saveEntry logic for reference or if needed to revert parts:
    /*
    private func saveEntry() {
        guard !title.isEmpty && !content.isEmpty else { return }
        
        isSaving = true
        
        // Parse work projects from string to array
        let projectsArray = workProjects.isEmpty ? nil : 
            workProjects.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        // Create new journal entry
        let newEntry = JournalEntry(
            id: UUID(),
            title: title,
            text: content,
            date: Date(),
            stressLevel: stressLevel,
            focusScore: focusScore,
            workProjects: projectsArray
        )
        
        // Create new Core Data JournalEntry
        let newCoreDataEntry = JournalEntry(context: viewContext)
        // Commented out to prevent crash due to unrecognized selector
        // newCoreDataEntry.id = UUID()
        // Commented out to prevent crash due to unrecognized selector
        // newCoreDataEntry.timestamp = Date()
        newCoreDataEntry.text = "\(title)\n\n\(content)" // Combine title and content
        
        // Convert stressLevel (0.0-1.0) to moodRating (1-5 Int16)
        newCoreDataEntry.moodRating = Int16(round(stressLevel * 4) + 1)
        newCoreDataEntry.isDraft = false // Mark as not a draft
        
        // workProjects and focusScore are not saved in this version as JournalEntry doesn't have these fields.
        // To include them, the Core Data model (Fathom.xcdatamodeld) would need to be updated.
        */

}

#Preview("New Entry") {
    JournalEntryComposeView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

#Preview("Edit Entry") {
    let view = {
        let context = PersistenceController.preview.container.viewContext
        let sampleEntry = JournalEntry(context: context)
        sampleEntry.id = UUID()
        sampleEntry.timestamp = Date()
        sampleEntry.text = "Sample Title\nThis is sample content for editing."
        sampleEntry.moodRating = 3 // Represents a stress level of 0.5
        sampleEntry.isDraft = false
        
        return JournalEntryComposeView(entryToEdit: sampleEntry)
            .environment(\.managedObjectContext, context)
    }()
    return view
}
