//
//  StartFocusIntent.swift
//  Fathom
//
//  Created by Paul Thomas on 6/10/25.
//

import AppIntents
import SwiftUI

// This file defines the actions the widget can perform.
// IMPORTANT: This file MUST be a member of both the Fathom app target
// and the FathomWidgetsExtension target.

// Intent to start a focus session
@preconcurrency nonisolated struct StartFocusIntent: AppIntent, Sendable {
    static let title: LocalizedStringResource = "Start Focus Session"
    
    func perform() async throws -> some IntentResult {
        // Access to NotificationCenter.default must happen on the main thread
        await MainActor.run {
            NotificationCenter.default.post(name: .startFocusFromWidget, object: nil)
        }
        return .result()
    }
}

// Intent for creating a quick note
@preconcurrency nonisolated struct QuickNoteIntent: AppIntent, Sendable {
    static let title: LocalizedStringResource = "Create Quick Note"
    
    func perform() async throws -> some IntentResult {
        // Access to NotificationCenter.default must happen on the main thread
        await MainActor.run {
            NotificationCenter.default.post(name: .quickNoteFromWidget, object: nil)
        }
        return .result()
    }
}

// This is a configuration intent required for the widget.
// Defining it once here resolves the redeclaration and ambiguity errors.
@preconcurrency nonisolated struct QuickActionsConfigurationAppIntent: WidgetConfigurationIntent, Sendable {
    static let title: LocalizedStringResource = "Configuration"
    static let description = IntentDescription("This is a widget configuration.")
}

// MARK: - Actor Isolation Note
// The AppIntent structures above are explicitly marked as nonisolated to prevent
// the Swift compiler from incorrectly inferring @MainActor isolation when used with SwiftUI.
// This avoids warnings about "conformance crossing into main actor-isolated code".

// Custom notification names for clean communication
extension Notification.Name {
    // Explicitly marked as nonisolated to be accessible from any actor context
    nonisolated static let startFocusFromWidget = Notification.Name("com.fathom.startFocus")
    nonisolated static let quickNoteFromWidget = Notification.Name("com.fathom.quickNote")
}
