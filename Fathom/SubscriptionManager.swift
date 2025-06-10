//
//  SubscriptionManager.swift
//  Fathom
//
//  Created by Paul Thomas on 6/10/25.
//

import Foundation
import StoreKit
import Combine
import SwiftUI
import FirebaseAnalytics

// MARK: - Subscription Products
enum SubscriptionTier: String, CaseIterable {
    case monthly = "com.fathom.subscription.monthly"
    case yearly = "com.fathom.subscription.yearly"
    
    var displayName: String {
        switch self {
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
    
    var description: String {
        switch self {
        case .monthly: return "Full access to all Fathom features"
        case .yearly: return "Full access to all Fathom features at a discounted rate"
        }
    }
}

@MainActor
class SubscriptionManager: ObservableObject {
    // MARK: - Published Properties
    @Published var isProUser = false
    @Published var availableProducts: [Product] = []
    @Published var isPurchasing = false
    @Published var purchaseError: String? = nil
    
    // MARK: - Developer Bypass
    @AppStorage("developerBypassEnabled") private var developerBypassEnabled = false
    private let developerBypassCode = "fathom2025"
    private var subscriptionUpdateTask: Task<Void, Never>?
    private var transactionListener: Task<Void, Error>?
    
    // MARK: - Initialization
    init() {
        // Start listening for transactions
        transactionListener = listenForTransactions()
        
        // Check current subscription status
        Task {
            await updateSubscriptionStatus()
            await loadProducts()
        }
    }
    
    deinit {
        subscriptionUpdateTask?.cancel()
        transactionListener?.cancel()
    }
    
    // MARK: - Public Methods
    func loadProducts() async {
        do {
            // Request products from the App Store
            let productIDs = SubscriptionTier.allCases.map { $0.rawValue }
            let storeProducts = try await Product.products(for: productIDs)
            
            // Sort products by price (lowest first)
            availableProducts = storeProducts.sorted { $0.price < $1.price }
        } catch {
            print("Failed to load products: \(error)")
        }
    }
    
    func purchase(_ product: Product) async {
        do {
            isPurchasing = true
            purchaseError = nil
            
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // Check if the transaction is verified
                switch verification {
                case .verified(let transaction):
                    // Log successful purchase event
                    Analytics.logEvent(AnalyticsEventPurchase, parameters: [
                        AnalyticsParameterTransactionID: transaction.id,
                        AnalyticsParameterAffiliation: "App Store",
                        AnalyticsParameterCurrency: product.priceFormatStyle.currencyCode,
                        AnalyticsParameterValue: product.price,
                        AnalyticsParameterItems: [
                            [
                                AnalyticsParameterItemID: product.id,
                                AnalyticsParameterItemName: product.displayName,
                                AnalyticsParameterPrice: product.price
                            ]
                        ]
                    ])
                    // Handle successful purchase
                    await transaction.finish()
                    await updateSubscriptionStatus()
                case .unverified(_, let error):
                    let errorMessage = "Transaction verification failed: \(error.localizedDescription)"
                    purchaseError = errorMessage
                    // Log failed purchase event
                    Analytics.logEvent("subscription_failed", parameters: [
                        "error_message": errorMessage,
                        "product_id": product.id,
                        "reason": "unverified_transaction"
                    ])
                }
            case .userCancelled:
                purchaseError = "Purchase was cancelled"
                // Log cancelled purchase event
                Analytics.logEvent("subscription_cancelled", parameters: [
                    "product_id": product.id
                ])
            case .pending:
                purchaseError = "Purchase is pending approval"
            @unknown default:
                purchaseError = "Unknown purchase result"
            }
        } catch {
            let errorMessage = "Error: \(error.localizedDescription)"
            purchaseError = errorMessage
            // Log failed purchase event (general error)
            Analytics.logEvent("subscription_failed", parameters: [
                "error_message": errorMessage,
                "product_id": product.id, // product might not be in scope here if error is before product assignment, consider if this is always available
                "reason": "purchase_exception"
            ])
        }
        
        isPurchasing = false
    }
    
    func restorePurchases() async {
        do {
            isPurchasing = true
            purchaseError = nil
            
            try await AppStore.sync()
            await updateSubscriptionStatus()
        } catch {
            purchaseError = "Failed to restore purchases: \(error.localizedDescription)"
        }
        
        isPurchasing = false
    }
    
    func attemptDeveloperBypass(with code: String) {
        if code == developerBypassCode {
            developerBypassEnabled = true
            isProUser = true
        }
    }
    
    func disableDeveloperBypass() {
        developerBypassEnabled = false
        Task {
            await updateSubscriptionStatus()
        }
    }
    
    // MARK: - Private Methods
    private func updateSubscriptionStatus() async {
        // If developer bypass is enabled, user is always Pro
        if developerBypassEnabled {
            isProUser = true
            return
        }
        
        // Otherwise check for valid subscriptions
        do {
            var hasActiveSubscription = false
            
            // Get all transaction entries
            for await result in Transaction.currentEntitlements {
                // Check if the transaction is verified
                if case .verified(let transaction) = result {
                    // Check if this is a subscription and if it's still active
                    // Note: StoreKit 2 Transaction doesn't have isRevoked property directly
                    // Instead we check if it's not expired and not revoked via its state
                    if transaction.productType == .autoRenewable && 
                       !transaction.isUpgraded && 
                       transaction.revocationDate == nil {
                        hasActiveSubscription = true
                        break
                    }
                }
            }
            
            isProUser = hasActiveSubscription
        } catch {
            print("Failed to update subscription status: \(error)")
            isProUser = false
        }
    }
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // Listen for transactions from the App Store
            for await result in Transaction.updates {
                // Check if the transaction is verified
                if case .verified(let transaction) = result {
                    // Always finish a transaction
                    await transaction.finish()
                    
                    // Update the user's subscription status
                    await self.updateSubscriptionStatus()
                }
            }
        }
    }
}
