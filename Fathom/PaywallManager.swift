import SwiftUI

/// A utility struct for managing paywall access throughout the app
struct PaywallManager {
    /// Checks if a feature is accessible based on subscription status
    /// - Parameters:
    ///   - subscriptionManager: The app's subscription manager
    ///   - isPremiumFeature: Whether the feature requires premium access
    ///   - onContinue: Closure to execute if the user has access or gains access
    /// - Returns: A view that either shows the paywall or continues to the feature
    @ViewBuilder
    static func checkAccess(
        subscriptionManager: SubscriptionManager,
        isPremiumFeature: Bool,
        onContinue: @escaping () -> Void
    ) -> some View {
        if isPremiumFeature && !subscriptionManager.isProUser {
            // Feature requires premium and user doesn't have access
            PaywallView_Workplace(onPurchaseComplete: onContinue)
                .environmentObject(subscriptionManager)
        } else {
            // User has access to this feature
            EmptyView().onAppear(perform: onContinue)
        }
    }
}

// MARK: - View Extension
extension View {
    /// Adds a paywall check to a view, showing the paywall if the user doesn't have access
    /// - Parameters:
    ///   - subscriptionManager: The app's subscription manager
    ///   - isPremiumFeature: Whether this view requires premium access
    /// - Returns: A view that either shows the original content or the paywall
    func paywallProtected(
        subscriptionManager: SubscriptionManager,
        isPremiumFeature: Bool = true
    ) -> some View {
        Group {
            if isPremiumFeature && !subscriptionManager.isProUser {
                PaywallView_Workplace()
                    .environmentObject(subscriptionManager)
            } else {
                self
            }
        }
    }
}
