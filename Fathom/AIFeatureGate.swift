//
//  AIFeatureGate.swift
//  Fathom
//
//  Centralized user opt-in + Remote Config gating for AI features.
//

import Foundation
import Combine

// Remote Config and persistence keys should not be actor-isolated.
private enum AIFeatureGateKeys {
    static let userOptIn = "ai.userOptIn"
    static let kAIEnabled = "ai_enabled"
    static let kAISummarizeEnabled = "ai_summarize_enabled"
    static let kAIRewriteEnabled = "ai_rewrite_enabled"
    static let kAIVertexEnabled = "ai_vertex_enabled"
}

@MainActor
final class AIFeatureGate: ObservableObject {
    static let shared = AIFeatureGate()

    // MARK: - User Opt-in (persisted)
    @Published var userOptIn: Bool {
        didSet { UserDefaults.standard.set(userOptIn, forKey: AIFeatureGateKeys.userOptIn) }
    }

    // MARK: - Remote Config-backed flags
    @Published private(set) var rcEnabled: Bool = true
    @Published private(set) var rcSummarizeEnabled: Bool = true
    @Published private(set) var rcRewriteEnabled: Bool = true
    @Published private(set) var rcVertexEnabled: Bool = true

    private init() {
        userOptIn = UserDefaults.standard.bool(forKey: AIFeatureGateKeys.userOptIn)
        // Register sensible defaults so the app works without RC
        #if canImport(FirebaseRemoteConfig)
        registerRemoteConfigDefaults()
        #endif
    }

    // MARK: - Effective Permissions

    var allowsAI: Bool { userOptIn && rcEnabled }
    var allowsCloudAI: Bool { allowsAI && rcVertexEnabled }
    var allowsCloudSummarization: Bool { allowsCloudAI && rcSummarizeEnabled }
    var allowsCloudRewrite: Bool { allowsCloudAI && rcRewriteEnabled }

    // MARK: - Remote Config

    func refreshRemoteConfig() {
        #if canImport(FirebaseRemoteConfig)
        importFirebaseRemoteConfigIfNeeded()
        #else
        // No-op when RC isn't available; keep defaults
        #endif
    }
}

#if canImport(FirebaseRemoteConfig)
import FirebaseRemoteConfig

extension AIFeatureGate {
    nonisolated private func registerRemoteConfigDefaults() {
        let defaults: [String: NSObject] = [
            "ai_enabled": true as NSObject,
            "ai_summarize_enabled": true as NSObject,
            "ai_rewrite_enabled": true as NSObject,
            "ai_vertex_enabled": true as NSObject
        ]
        RemoteConfig.remoteConfig().setDefaults(defaults)
    }

    nonisolated fileprivate func importFirebaseRemoteConfigIfNeeded() {
        let rc = RemoteConfig.remoteConfig()
        // Use a short cache during development
        rc.fetch(withExpirationDuration: 0) { [weak self] status, error in
            guard let self = self else { return }
            rc.activate { _, _ in
                let enabled = rc["ai_enabled"].boolValue
                let summarize = rc["ai_summarize_enabled"].boolValue
                let rewrite = rc["ai_rewrite_enabled"].boolValue
                let vertex = rc["ai_vertex_enabled"].boolValue
                Task { @MainActor in
                    self.rcEnabled = enabled
                    self.rcSummarizeEnabled = summarize
                    self.rcRewriteEnabled = rewrite
                    self.rcVertexEnabled = vertex
                }
            }
        }
    }
}
#endif
