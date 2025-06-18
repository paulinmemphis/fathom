//
//  WorkplaceJournalComposeView.swift
//  Fathom
//
//  Created for workplace journal entry composition
//

import SwiftUI
import CoreData

@available(iOS 16.0, *)
struct WorkplaceJournalComposeView: View {
    var entryToEdit: JournalEntry?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    // State variables for form fields
    @State private var title: String
    @State private var content: String
    @State private var stressLevel: Double
    // These fields are not in JournalEntry, but kept for UI consistency for now
    // They won't be saved to or loaded from Core Data in this version.
    @State private var focusScore: Double = 0.5
    @State private var workProjects: String = ""
    @State private var isSaving: Bool = false
    
    // Custom initializer to set up state based on whether we're editing or creating
    init(entryToEdit: JournalEntry? = nil) {
        self.entryToEdit = entryToEdit
        
        if let entry = entryToEdit {
            // Editing an existing entry: parse text into title and content
            let lines = entry.text?.components(separatedBy: .newlines) ?? []
            _title = State(initialValue: lines.first ?? "")
            _content = State(initialValue: lines.dropFirst().joined(separator: "\n"))
            
            // Convert moodRating (1-5) back to stressLevel (0.0-1.0)
            // moodRating = Int16(round(stressLevel * 4) + 1)
            // stressLevel = (Double(moodRating) - 1.0) / 4.0
            _stressLevel = State(initialValue: max(0.0, min(1.0, (Double(entry.moodRating) - 1.0) / 4.0)))
            
            // workProjects and focusScore are not in JournalEntry, so they keep default values
            // or could be initialized if they were part of the model
        } else {
            // Creating a new entry: use default empty/initial values
            _title = State(initialValue: "")
            _content = State(initialValue: "")
            _stressLevel = State(initialValue: 0.5) // Default for new entry
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
                
                Section("Work Context") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Stress Level: \(Int(stressLevel * 10))/10")
                            .font(.subheadline)
                        Slider(value: $stressLevel, in: 0...1)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Focus Score: \(Int(focusScore * 10))/10")
                            .font(.subheadline)
                        Slider(value: $focusScore, in: 0...1)
                    }
                    
                    TextField("Work Projects (optional)", text: $workProjects)
                        .textInputAutocapitalization(.words)
                }
                
                Section {
                    Button(action: saveEntry) {
                        HStack {
                            if isSaving {
                                ProgressView()
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
            }
        }
    }
    
    private func saveEntry() {
        guard !title.isEmpty && !content.isEmpty else { return }
        
        isSaving = true
        
        let entryToSave: JournalEntry
        if let existingEntry = entryToEdit {
            entryToSave = existingEntry // Update existing entry
        } else {
            entryToSave = JournalEntry(context: viewContext) // Create new entry
            entryToSave.id = UUID()
        }
        
        entryToSave.timestamp = Date() // Update timestamp for both new and edited entries
        entryToSave.text = "\(title)\n\n\(content)" // Combine title and content
        entryToSave.moodRating = Int16(round(stressLevel * 4) + 1) // Convert stressLevel to moodRating
        entryToSave.isDraft = false
        
        // workProjects and focusScore are not part of the JournalEntry model in this version.

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
        let newEntry = WorkplaceJournalEntry(
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
        newCoreDataEntry.id = UUID()
        newCoreDataEntry.timestamp = Date()
        newCoreDataEntry.text = "\(title)\n\n\(content)" // Combine title and content
        
        // Convert stressLevel (0.0-1.0) to moodRating (1-5 Int16)
        newCoreDataEntry.moodRating = Int16(round(stressLevel * 4) + 1)
        newCoreDataEntry.isDraft = false // Mark as not a draft
        
        // workProjects and focusScore are not saved in this version as JournalEntry doesn't have these fields.
        // To include them, the Core Data model (Fathom.xcdatamodeld) would need to be updated.
        */

}

#Preview("New Entry") {
    WorkplaceJournalComposeView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

#Preview("Edit Entry") {
    let context = PersistenceController.preview.container.viewContext
    let sampleEntry = JournalEntry(context: context)
    sampleEntry.id = UUID()
    sampleEntry.timestamp = Date()
    sampleEntry.text = "Sample Title\n\nThis is sample content for editing."
    sampleEntry.moodRating = 3 // Corresponds to stressLevel = 0.5
    sampleEntry.isDraft = false
    
    return WorkplaceJournalComposeView(entryToEdit: sampleEntry)
        .environment(\.managedObjectContext, context)
}
