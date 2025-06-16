//
//  WorkplaceJournalComposeView.swift
//  Fathom
//
//  Created for workplace journal entry composition
//

import SwiftUI

@available(iOS 16.0, *)
struct WorkplaceJournalComposeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var journalStore: WorkplaceJournalStore
    
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var stressLevel: Double = 0.5
    @State private var focusScore: Double = 0.5
    @State private var workProjects: String = ""
    @State private var isSaving: Bool = false
    
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
                            Text(isSaving ? "Saving..." : "Save Entry")
                        }
                    }
                    .disabled(title.isEmpty || content.isEmpty || isSaving)
                }
            }
            .navigationTitle("New Journal Entry")
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
        
        // Add to store
        journalStore.addEntry(newEntry)
        
        // Simulate save delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSaving = false
            dismiss()
        }
    }
}

#Preview {
    WorkplaceJournalComposeView()
        .environmentObject(WorkplaceJournalStore())
}
