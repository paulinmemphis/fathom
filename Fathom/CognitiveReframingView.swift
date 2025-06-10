//
//  CognitiveReframingView.swift
//  Fathom
//
//  Created by Paul Thomas on 6/10/25.
//


import SwiftUI

/// A guided tool based on Cognitive Behavioral Therapy to help users reframe anxious thoughts.
struct CognitiveReframingView: View {
    @State private var anxiousThought = ""
    @State private var reframedThought = ""
    @State private var currentStep = 0

    let steps = [
        "What is the anxious thought on your mind?",
        "What evidence supports this thought? What evidence contradicts it?",
        "What is a more balanced or realistic way to look at this situation?"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Cognitive Reframing")
                .font(.largeTitle.weight(.bold))
            
            Text(steps[currentStep])
                .font(.headline)
            
            if currentStep == 0 {
                TextField("e.g., I'm going to fail my presentation.", text: $anxiousThought, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
            } else if currentStep == 2 {
                TextField("e.g., I'm well-prepared and I will do my best.", text: $reframedThought, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
            } else {
                TextEditor(text: .constant("")) // Placeholder for evidence gathering
                    .frame(height: 150)
                    .border(Color(.separator), width: 1)
                    .cornerRadius(8)
            }

            HStack {
                if currentStep > 0 {
                    Button("Back") { currentStep -= 1 }
                }
                Spacer()
                Button(currentStep == 2 ? "Finish" : "Next") {
                    if currentStep < 2 {
                        currentStep += 1
                    } else {
                        // TODO: Save reframed thought to a journal entry
                    }
                }
                .disabled(anxiousThought.isEmpty && currentStep == 0)
            }
            .buttonStyle(.bordered)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Reframing Tool")
        .navigationBarTitleDisplayMode(.inline)
    }
}
