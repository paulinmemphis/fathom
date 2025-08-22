//
//  AnalyticsService.swift
//  Fathom
//
//  Created by Paul Thomas on 6/16/25.
//

import Foundation
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

/// Centralized analytics service for consistent event tracking across the app
@MainActor
class AnalyticsService {
    
    static let shared = AnalyticsService()
    
    private init() {}
    
    // MARK: - General Event Logging
    
    func logEvent(_ eventName: String, parameters: [String: Any]? = nil) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(eventName, parameters: parameters)
        #else
        // Fallback logging when Firebase is not available
        print("Analytics Event: \(eventName)")
        if let params = parameters {
            print("Parameters: \(params)")
        }
        #endif
    }
    
    // MARK: - Paywall Events
    
    func trackPaywallImpression(source: String, version: String = "enhanced_v2", isProUser: Bool, productsCount: Int) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent("paywall_impression", parameters: [
            "source": source,
            "paywall_version": version,
            "user_is_pro": isProUser,
            "products_count": productsCount,
            "session_timestamp": Int(Date().timeIntervalSince1970)
        ])
        #endif
    }
    
    func trackPaywallDismissal(source: String, version: String = "enhanced_v2", selectedProductIndex: Int?, timeSpentSeconds: Int) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent("paywall_dismissed", parameters: [
            "source": source,
            "paywall_version": version,
            "selected_product_index": selectedProductIndex ?? -1,
            "time_spent_seconds": timeSpentSeconds
        ])
        #endif
    }
    
    func trackSubscriptionOptionSelected(productID: String, productName: String, productPrice: Decimal, currency: String) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent("subscription_option_selected", parameters: [
            "product_id": productID,
            "product_name": productName,
            "product_price": NSDecimalNumber(decimal: productPrice).doubleValue,
            "product_currency": currency
        ])
        #endif
    }
    
    func trackFeatureTapped(featureName: String) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent("feature_tapped", parameters: [
            "feature_name": featureName
        ])
        #endif
    }
    
    // MARK: - Purchase Events
    
    func trackPurchaseInitiated(productID: String, productName: String, productPrice: Decimal, currency: String) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(AnalyticsEventBeginCheckout, parameters: [
            AnalyticsParameterItems: [
                [
                    AnalyticsParameterItemID: productID,
                    AnalyticsParameterItemName: productName,
                    AnalyticsParameterPrice: NSDecimalNumber(decimal: productPrice).doubleValue,
                    AnalyticsParameterCurrency: currency
                ]
            ],
            AnalyticsParameterCurrency: currency,
            AnalyticsParameterValue: NSDecimalNumber(decimal: productPrice).doubleValue
        ])
        #endif
    }
    
    func trackBeginCheckout(productID: String, productName: String, productPrice: Decimal, currency: String) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(AnalyticsEventBeginCheckout, parameters: [
            AnalyticsParameterItems: [
                [
                    AnalyticsParameterItemID: productID,
                    AnalyticsParameterItemName: productName,
                    AnalyticsParameterPrice: NSDecimalNumber(decimal: productPrice).doubleValue,
                    AnalyticsParameterCurrency: currency
                ]
            ],
            AnalyticsParameterCurrency: currency,
            AnalyticsParameterValue: NSDecimalNumber(decimal: productPrice).doubleValue
        ])
        #endif
    }
    
    func trackPurchaseCompleted(transactionID: UInt64, productID: String, productName: String, productPrice: Decimal, currency: String) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(AnalyticsEventPurchase, parameters: [
            AnalyticsParameterTransactionID: transactionID,
            AnalyticsParameterItemID: productID,
            AnalyticsParameterItemName: productName,
            AnalyticsParameterCurrency: currency,
            AnalyticsParameterValue: NSDecimalNumber(decimal: productPrice).doubleValue
        ])
        #endif
    }
    
    func trackPurchaseCompleted(productID: String, productName: String, productPrice: Decimal, currency: String) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(AnalyticsEventPurchase, parameters: [
            AnalyticsParameterItemID: productID,
            AnalyticsParameterItemName: productName,
            AnalyticsParameterCurrency: currency,
            AnalyticsParameterValue: NSDecimalNumber(decimal: productPrice).doubleValue
        ])
        #endif
    }
    
    func trackPurchaseFailed(productID: String, productName: String, productPrice: Decimal, currency: String, error: String) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent("purchase_failed", parameters: [
            AnalyticsParameterItemID: productID,
            AnalyticsParameterItemName: productName,
            AnalyticsParameterCurrency: currency,
            AnalyticsParameterValue: NSDecimalNumber(decimal: productPrice).doubleValue,
            "error_reason": error
        ])
        #endif
    }
    
    func trackPurchaseRestored(productID: String?, productName: String?, productPrice: Decimal?, currency: String?) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent("purchase_restored", parameters: [
            AnalyticsParameterItemID: productID ?? "",
            AnalyticsParameterItemName: productName ?? "",
            AnalyticsParameterCurrency: currency ?? "",
            AnalyticsParameterValue: NSDecimalNumber(decimal: productPrice ?? 0).doubleValue
        ])
        #endif
    }
    
    func trackRestoreFailed(error: String) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent("restore_failed", parameters: [
            "error_reason": error
        ])
        #endif
    }
    
    // MARK: - Developer Events
    
    func trackDeveloperBypassGranted(developerCode: String) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent("developer_bypass_granted", parameters: [
            "timestamp": Int(Date().timeIntervalSince1970),
            "developer_code": developerCode
        ])
        #endif
    }
    
    // MARK: - User Journey Events
    
    func trackScreenView(screenName: String, screenClass: String) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenClass
        ])
        #endif
    }
    
    func trackUserAction(action: String, category: String, value: Int? = nil) {
        #if canImport(FirebaseAnalytics)
        var parameters: [String: Any] = [
            "action": action,
            "category": category
        ]
        
        if let value = value {
            parameters["value"] = value
        }
        
        Analytics.logEvent("user_action", parameters: parameters)
        #endif
    }
}

// MARK: - Convenience Extensions

extension AnalyticsService {
    
    /// Track a generic app event with custom parameters
    func trackEvent(_ eventName: String, parameters: [String: Any] = [:]) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(eventName, parameters: parameters)
        #endif
    }
    
    /// Set user properties for analytics
    func setUserProperty(_ value: String?, forName name: String) {
        #if canImport(FirebaseAnalytics)
        Analytics.setUserProperty(value, forName: name)
        #endif
    }
}
