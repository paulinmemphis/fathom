//
//  FathomActivityAttributes.swift
//  Fathom
//
//  Created by Paul Thomas on 6/10/25.
//


import Foundation
import ActivityKit

import ActivityKit

// A clean, simple structure for the ActivityAttributes.

public enum SessionState: String, Codable, Hashable {
    case focused
    case paused
}

// Explicitly marked as nonisolated to prevent actor isolation warnings
nonisolated public struct FathomActivityContentState: Codable, Hashable {
    public var timeRemaining: String
    public var sessionState: SessionState
}

// Explicitly marked as nonisolated to prevent actor isolation warnings
nonisolated public struct FathomActivityAttributes: ActivityAttributes {
    public typealias ContentState = FathomActivityContentState
    public var sessionName: String
}

// MARK: - Actor Isolation & Sendable Conformance

// IMPORTANT: These types are explicitly marked as nonisolated and @unchecked Sendable
// to work around a persistent Swift compiler bug with ActivityKit and SwiftUI.
// 
// The bug causes the compiler to incorrectly infer @MainActor isolation for these types
// when they're used in SwiftUI views, leading to warnings about:
// 1. "Circular reference" (which is a false positive)
// 2. "Conformance crosses into main actor-isolated code and can cause data races"
//
// These are value types that are inherently thread-safe, so @unchecked Sendable
// tells the compiler to trust our manual verification of thread safety.

extension SessionState: @unchecked Sendable {}
extension FathomActivityContentState: @unchecked Sendable {}
extension FathomActivityAttributes: @unchecked Sendable {}
