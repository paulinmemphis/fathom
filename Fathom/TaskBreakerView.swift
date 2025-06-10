//
//  TaskBreakerView.swift
//  Fathom
//
//  Created by Paul Thomas on 6/10/25.
//


import SwiftUI

/// A tool to help users break down overwhelming tasks into smaller, manageable steps.
struct TaskBreakerView: View {
    @State private var mainTask = ""
    @State private var steps: [String] = ["", "", ""]

    var body: some View {
        Form {
            Section(header: Text("Overwhelming Task")) {
                TextField("e.g., Prepare quarterly report", text: $mainTask)
            }
            
            Section(header: Text("Break it Down: What are the first 3 steps?")) {
                ForEach($steps, id: \.self) { $step in
                    TextField("e.g., Open the template document", text: $step)
                }
            }
            
            Section {
                Button("Add to Today's Focus") {
                    // TODO: Logic to add these steps to a task list or a journal entry
                }
                .disabled(mainTask.isEmpty || steps.allSatisfy { $0.isEmpty })
            }
        }
        .navigationTitle("Task Breaker")
    }
}
