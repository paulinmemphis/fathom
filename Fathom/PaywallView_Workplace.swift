import SwiftUI
import StoreKit
import FirebaseAnalytics

struct PaywallView_Workplace: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProductIndex: Int? = nil
    @State private var showingDeveloperBypass = false
    @State private var developerCode = ""
    @State private var showingBypassSuccess = false
    
    var onPurchaseComplete: (() -> Void)? = nil
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Text("Upgrade to Fathom Pro")
                            .font(.system(.largeTitle, design: .rounded))
                            .fontWeight(.bold)
                        
                        Text("Unlock all premium features")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Feature list
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(icon: "infinity", title: "Unlimited Focus Sessions", description: "No daily limits on focus time")
                        FeatureRow(icon: "chart.bar.fill", title: "Advanced Analytics", description: "Track your progress with detailed insights")
                        FeatureRow(icon: "waveform.path.ecg", title: "Breathing Exercises", description: "Access to all guided breathing techniques")
                        FeatureRow(icon: "bell.badge.fill", title: "Priority Support", description: "Get help when you need it most")
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 10)
                    )
                    .padding(.horizontal)
                    
                    // Subscription options
                    if subscriptionManager.availableProducts.isEmpty {
                        ProgressView("Loading subscription options...")
                            .padding()
                    } else {
                        VStack(spacing: 16) {
                            ForEach(0..<subscriptionManager.availableProducts.count, id: \.self) { index in
                                let product = subscriptionManager.availableProducts[index]
                                SubscriptionOptionView(
                                    product: product,
                                    isSelected: selectedProductIndex == index,
                                    isBestValue: index == 1 // Assuming yearly is at index 1 and is best value
                                ) {
                                    selectedProductIndex = index
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Purchase button
                    Button {
                        if let index = selectedProductIndex {
                            let productToPurchase = subscriptionManager.availableProducts[index]
                            // Log subscription initiated event
                            Analytics.logEvent(AnalyticsEventBeginCheckout, parameters: [
                                AnalyticsParameterItems: [
                                    [
                                        AnalyticsParameterItemID: productToPurchase.id,
                                        AnalyticsParameterItemName: productToPurchase.displayName,
                                        AnalyticsParameterPrice: productToPurchase.price,
                                        AnalyticsParameterCurrency: productToPurchase.priceFormatStyle.currencyCode
                                    ]
                                ],
                                AnalyticsParameterCurrency: productToPurchase.priceFormatStyle.currencyCode,
                                AnalyticsParameterValue: productToPurchase.price
                            ])
                            let product = subscriptionManager.availableProducts[index]
                            Task {
                                await subscriptionManager.purchase(product)
                                if subscriptionManager.isProUser {
                                    onPurchaseComplete?() 
                                    dismiss()
                                }
                            }
                        }
                    } label: {
                        Text(subscriptionManager.isPurchasing ? "Processing..." : "Continue")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedProductIndex != nil ? Color.blue : Color.gray)
                            )
                            .padding(.horizontal)
                    }
                    .disabled(selectedProductIndex == nil || subscriptionManager.isPurchasing)
                    
                    // Error message
                    if let error = subscriptionManager.purchaseError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.callout)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Restore purchases button
                    Button {
                        Task {
                            await subscriptionManager.restorePurchases()
                            if subscriptionManager.isProUser {
                                onPurchaseComplete?()
                                dismiss()
                            }
                        }
                    } label: {
                        Text("Restore Purchases")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 8)
                    .disabled(subscriptionManager.isPurchasing)
                    
                    // Terms and privacy
                    VStack(spacing: 4) {
                        Text("By continuing, you agree to our")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 4) {
                            Button("Terms of Service") {
                                // Open terms URL
                            }
                            .font(.caption)
                            
                            Text("and")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("Privacy Policy") {
                                // Open privacy URL
                            }
                            .font(.caption)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        // Log paywall dismissed event
                        Analytics.logEvent("paywall_dismissed_explicitly", parameters: [
                            AnalyticsParameterScreenName: "PaywallView_Workplace"
                        ])
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Hidden developer bypass button (triple tap)
                    Button {
                        showingDeveloperBypass = true
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.clear)
                    }
                    .opacity(0.001) // Practically invisible but still tappable
                    .simultaneousGesture(
                        TapGesture(count: 3).onEnded {
                            showingDeveloperBypass = true
                        }
                    )
                }
            }
            .alert("Developer Bypass", isPresented: $showingDeveloperBypass) {
                TextField("Enter developer code", text: $developerCode)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Button("Cancel", role: .cancel) {
                    developerCode = ""
                }
                
                Button("Unlock") {
                    subscriptionManager.attemptDeveloperBypass(with: developerCode)
                    showingBypassSuccess = subscriptionManager.isProUser
                    developerCode = ""
                }
            }
            .alert("Developer Mode Activated", isPresented: $showingBypassSuccess) {
                Button("OK") {
                    onPurchaseComplete?()
                    dismiss()
                }
            } message: {
                Text("You now have access to all premium features.")
            }
            .onAppear {
                // Load products when view appears
                if subscriptionManager.availableProducts.isEmpty {
                    Task {
                        await subscriptionManager.loadProducts()
                    }
                }
                
                // Auto-select first product if available
                if selectedProductIndex == nil && !subscriptionManager.availableProducts.isEmpty {
                    selectedProductIndex = 0
                }
                // Log paywall viewed event
                Analytics.logEvent(AnalyticsEventViewItem, parameters: [
                    AnalyticsParameterScreenName: "PaywallView_Workplace",
                    AnalyticsParameterScreenClass: "PaywallView_Workplace"
                ])
            }
        }
    }
}

// MARK: - Supporting Views
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct SubscriptionOptionView: View {
    let product: Product
    let isSelected: Bool
    let isBestValue: Bool
    let action: () -> Void
    
    // Helper function to format subscription period
    private func formatSubscriptionPeriod(_ period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .day: return period.value == 1 ? "day" : "\(period.value) days"
        case .week: return period.value == 1 ? "week" : "\(period.value) weeks"
        case .month: return period.value == 1 ? "month" : "\(period.value) months"
        case .year: return period.value == 1 ? "year" : "\(period.value) years"
        @unknown default: return "\(period.value) \(period.unit)"
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatProductDisplayName(product))
                        .font(.headline)
                    
                    if let subscription = product.subscription {
                        // Format the subscription period manually
                        let periodText = formatSubscriptionPeriod(subscription.subscriptionPeriod)
                        Text("\(formatProductPrice(product)) / \(periodText)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text(formatProductPrice(product))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
                    )
            )
            .overlay(alignment: .topTrailing) {
                if isBestValue {
                    Text("Best Value")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.green)
                        )
                        .offset(x: 10, y: -10)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Helper Functions
// Instead of extending Product, use helper functions to format product information
func formatProductDisplayName(_ product: Product) -> String {
    let periodText: String
    if let subscription = product.subscription {
        if subscription.subscriptionPeriod.unit == .month && subscription.subscriptionPeriod.value == 1 {
            periodText = "monthly"
        } else if subscription.subscriptionPeriod.unit == .year && subscription.subscriptionPeriod.value == 1 {
            periodText = "yearly"
        } else {
            periodText = ""
        }
    } else {
        periodText = ""
    }
    
    return "\(formatProductPrice(product)) \(periodText)"
}

func formatProductPrice(_ product: Product) -> String {
    // Use the built-in displayPrice which handles formatting
    return product.displayPrice
}

func formatSubscriptionPeriod(_ period: Product.SubscriptionPeriod) -> String {
    switch period.unit {
    case .day: return period.value == 1 ? "day" : "\(period.value) days"
    case .week: return period.value == 1 ? "week" : "\(period.value) weeks"
    case .month: return period.value == 1 ? "month" : "\(period.value) months"
    case .year: return period.value == 1 ? "year" : "\(period.value) years"
    @unknown default: return "\(period.value) \(period.unit)"
    }
}

// Extension removed - using formatSubscriptionPeriod helper function instead

// No need for custom NumberFormatter extension - removed to fix initialization cycle
