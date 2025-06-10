//
//  OnDeviceInsightGenerator.swift
//  Fathom
//
//  Created by Paul Thomas on 6/10/25.
//


import Foundation
import NaturalLanguage

/// Provides on-device text analysis tailored for a workplace context.
@available(iOS 16.0, *)
class OnDeviceInsightGenerator_Workplace {

    /// Estimates a stress level based on the presence of anxiety-related keywords.
    func getStressLevel(for text: String) -> Double {
        let lowercasedText = text.lowercased()
        let stressKeywords = ["overwhelmed", "deadline", "pressure", "anxious", "stressed", "behind"]
        let stressMentions = stressKeywords.filter { lowercasedText.contains($0) }.count
        
        // Normalize to a 0.0 to 1.0 scale (this is a simplified model)
        return min(1.0, Double(stressMentions) / 3.0)
    }

    /// Suggests targeted prompts for users struggling with anxiety or focus.
    func suggestTargetedPrompts(for text: String) -> [String] {
        var suggestions: [String] = []
        let lowercasedText = text.lowercased()

        if lowercasedText.contains("overwhelmed") || lowercasedText.contains("anxious") {
            suggestions.append("What is one part of this situation you can control right now?")
            suggestions.append("What's the absolute smallest first step you could take?")
        }
        
        if lowercasedText.contains("distracted") || lowercasedText.contains("procrastinating") {
            suggestions.append("Is this task clear enough? Try breaking it down into 3 smaller steps.")
            suggestions.append("What is one distraction you can eliminate for the next 25 minutes?")
        }
        
        return suggestions
    }
}
