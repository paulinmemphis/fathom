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
    static let shared = SubscriptionManager()
    
    // MARK: - Published Properties
    @Published var isProUser = false
    @Published var availableProducts: [Product] = []
    @Published var isPurchasing = false
    @Published var purchaseError: String? = nil
    @Published var restoredProduct: Product? = nil
    
    // MARK: - Developer Bypass
    @AppStorage("developerBypassEnabled") private var developerBypassEnabled = false
    private let developerBypassCode = "fathom2025"
    private var subscriptionUpdateTask: Task<Void, Never>?
    private var transactionListener: Task<Void, Error>?
    
    // MARK: - Analytics
    private let analytics = AnalyticsService.shared
    
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
        guard !isPurchasing else { return }
        
        isPurchasing = true
        purchaseError = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    // Transaction verified successfully
                    await transaction.finish()
                    await updateSubscriptionStatus()
                    
                    analytics.trackPurchaseCompleted(
                        transactionID: transaction.id,
                        productID: product.id,
                        productName: product.displayName,
                        productPrice: product.price,
                        currency: product.priceFormatStyle.currencyCode
                    )
                    
                case .unverified(_, let error):
                    purchaseError = "Purchase verification failed. Please try again or contact support."
                    print("Purchase verification failed: \(error)")
                    analytics.trackPurchaseFailed(
                        productID: product.id,
                        productName: product.displayName,
                        productPrice: product.price,
                        currency: product.priceFormatStyle.currencyCode,
                        error: error.localizedDescription
                    )
                }
                
            case .userCancelled:
                purchaseError = nil // Don't show error for user cancellation
                analytics.trackPurchaseFailed(
                    productID: product.id,
                    productName: product.displayName,
                    productPrice: product.price,
                    currency: product.priceFormatStyle.currencyCode,
                    error: "User cancelled"
                )
                
            case .pending:
                purchaseError = "Your purchase is pending approval. You'll receive access once approved."
                analytics.trackPurchaseFailed(
                    productID: product.id,
                    productName: product.displayName,
                    productPrice: product.price,
                    currency: product.priceFormatStyle.currencyCode,
                    error: "Purchase pending"
                )
                
            @unknown default:
                purchaseError = "An unexpected error occurred. Please try again."
                analytics.trackPurchaseFailed(
                    productID: product.id,
                    productName: product.displayName,
                    productPrice: product.price,
                    currency: product.priceFormatStyle.currencyCode,
                    error: "Unknown error"
                )
            }
            
        } catch StoreKitError.notAvailableInStorefront {
            purchaseError = "This subscription is not available in your region. Please contact support."
            analytics.trackPurchaseFailed(
                productID: product.id,
                productName: product.displayName,
                productPrice: product.price,
                currency: product.priceFormatStyle.currencyCode,
                error: "Not available in storefront"
            )
            
        } catch StoreKitError.networkError(let underlyingError) {
            purchaseError = "Network connection failed. Please check your internet connection and try again."
            analytics.trackPurchaseFailed(
                productID: product.id,
                productName: product.displayName,
                productPrice: product.price,
                currency: product.priceFormatStyle.currencyCode,
                error: "Network error: \(underlyingError.localizedDescription)"
            )
            
        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
            print("Purchase error: \(error)")
            analytics.trackPurchaseFailed(
                productID: product.id,
                productName: product.displayName,
                productPrice: product.price,
                currency: product.priceFormatStyle.currencyCode,
                error: error.localizedDescription
            )
        }
        
        isPurchasing = false
    }
    
    func restorePurchases() async {
        guard !isPurchasing else { return }
        
        isPurchasing = true
        purchaseError = nil
        
        do {
            // Attempt to sync with App Store
            try await AppStore.sync()
            
            // Update subscription status
            await updateSubscriptionStatus()
            
            // Check if user has any active subscriptions after restore
            if !isProUser {
                purchaseError = "No active subscriptions found. If you believe this is an error, please contact support."
            }
            
            analytics.trackPurchaseRestored(
                productID: restoredProduct?.id,
                productName: restoredProduct?.displayName,
                productPrice: restoredProduct?.price,
                currency: restoredProduct?.priceFormatStyle.currencyCode
            )
            
        } catch StoreKitError.networkError(let underlyingError) {
            purchaseError = "Network connection failed. Please check your internet connection and try again."
            analytics.trackRestoreFailed(
                error: "Network error: \(underlyingError.localizedDescription)"
            )
            
        } catch {
            purchaseError = "Failed to restore purchases. Please try again or contact support if the problem persists."
            print("Restore purchases error: \(error)")
            analytics.trackRestoreFailed(
                error: error.localizedDescription
            )
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
