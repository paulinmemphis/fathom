//
//  for.swift
//  Fathom
//
//  Created by Paul Thomas on 6/10/25.
//


import SwiftUI
import Combine // Required for @Published and ObservableObject
import LocalAuthentication

/// Manages app security, including Face ID/Touch ID authentication.
@MainActor
class AppLockManager: ObservableObject { // Conform to ObservableObject
    private let appLockKey = "isAppLockEnabled"
    
    @Published var isAppLockEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isAppLockEnabled, forKey: appLockKey)
        }
    }
    
    @Published var isUnlocked = false
    
    init() {
        self.isAppLockEnabled = UserDefaults.standard.bool(forKey: appLockKey)
        // The app is considered unlocked by default if the feature is not enabled.
        if !isAppLockEnabled {
            isUnlocked = true
        }
    }

    /// Authenticates the user using Face ID or Touch ID.
    func authenticate() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Please authenticate to unlock Fathom."

            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        self.isUnlocked = true
                    } else {
                        // Handle error or user cancellation
                    }
                }
            }
        } else {
            // Biometrics not available
        }
    }
}
