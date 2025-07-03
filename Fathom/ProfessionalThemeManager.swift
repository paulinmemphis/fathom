//
//  for.swift
//  Fathom
//
//  Created by Paul Thomas on 6/10/25.
//


import SwiftUI
import Combine

/// Manages the visual appearance and theme of the Fathom app.
@MainActor
class ProfessionalThemeManager: ObservableObject {

    /// The key used to store the selected theme name in UserDefaults.
    private let themeKey = "FathomSelectedTheme"
    
    /// The currently selected theme. Changes are published to the UI and saved to UserDefaults.
    @Published var selectedTheme: String {
        didSet {
            UserDefaults.standard.set(selectedTheme, forKey: themeKey)
        }
    }

    /// A list of available themes for the user to choose from.
    let availableThemes = ["Default", "Midnight", "Graphite"]
    
    init() {
        // Load the saved theme on initialization, defaulting to "Default".
        self.selectedTheme = UserDefaults.standard.string(forKey: themeKey) ?? "Default"
    }

    /// Provides the primary accent color for the currently selected theme.
    var accentColor: Color {
        switch selectedTheme {
        case "Midnight":
            return .cyan
        case "Graphite":
            return .indigo
        default:
            return .blue // Default professional blue
        }
    }
    
    /// Provides the primary background color for views within the app.
    var backgroundColor: Color {
        return Color(.systemGroupedBackground)
    }
}

