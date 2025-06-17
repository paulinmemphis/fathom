import SwiftUI
import StoreKit

struct PaywallView_Workplace: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProductIndex: Int? = nil
    @State private var showingDeveloperBypass = false
    @State private var developerCode = ""
    @State private var showingBypassSuccess = false
    @State private var animateFeatures = false
    @State private var showingPurchaseSuccess = false
    @State private var paywallDidAppearTimestamp: Int = 0
    
    private let analytics = AnalyticsService.shared
    
    var onPurchaseComplete: (() -> Void)? = nil
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Enhanced Header with gradient background
                    headerSection
                    
                    // Premium features showcase
                    featuresSection
                    
                    // Subscription options with pricing
                    subscriptionOptionsSection
                    
                    // CTA and restore button
                    actionButtonsSection
                    
                    // Developer bypass (hidden by default)
                    if showingDeveloperBypass {
                        developerBypassSection
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color(.systemBackground).opacity(0.8)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Developer") {
                        showingDeveloperBypass.toggle()
                    }
                    .opacity(0.1)
                }
            }
        }
        .onAppear {
            paywallDidAppearTimestamp = Int(Date().timeIntervalSince1970)
            Task {
                await subscriptionManager.loadProducts()
            }
            
            // Animate features on appear
            withAnimation(.easeInOut(duration: 0.8).delay(0.3)) {
                animateFeatures = true
            }
            
            // Track paywall impression with detailed context
            analytics.trackPaywallImpression(
                source: "workplace",
                isProUser: subscriptionManager.isProUser,
                productsCount: subscriptionManager.availableProducts.count
            )
        }
        .onDisappear {
            // Track paywall dismissal
            analytics.trackPaywallDismissal(
                source: "workplace",
                selectedProductIndex: selectedProductIndex,
                timeSpentSeconds: Int(Date().timeIntervalSince1970) - paywallDidAppearTimestamp
            )
        }
        .alert("Purchase Successful!", isPresented: $showingPurchaseSuccess) {
            Button("Continue") {
                onPurchaseComplete?()
                dismiss()
            }
        } message: {
            Text("Welcome to Fathom Pro! You now have access to all premium features.")
        }
        .alert("Developer Access Granted", isPresented: $showingBypassSuccess) {
            Button("Continue") {
                onPurchaseComplete?()
                dismiss()
            }
        } message: {
            Text("You now have access to all Fathom Pro features.")
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // App icon or logo placeholder
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue, .purple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                )
                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 8) {
                Text("Upgrade to Fathom Pro")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)
                
                Text("Unlock your full potential with advanced insights and unlimited access")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Features Section  
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What's Included")
                .font(.title2.bold())
                .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                PremiumFeatureCard(
                    icon: "infinity",
                    title: "Unlimited Sessions",
                    description: "No daily limits on focus time",
                    accentColor: .blue,
                    animated: animateFeatures,
                    delay: 0.1,
                    analytics: analytics
                )
                
                PremiumFeatureCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Advanced Analytics",
                    description: "AI-powered insights & predictions",
                    accentColor: .green,
                    animated: animateFeatures,
                    delay: 0.2,
                    analytics: analytics
                )
                
                PremiumFeatureCard(
                    icon: "waveform.path.ecg",
                    title: "Breathing Exercises",
                    description: "Guided wellness techniques",
                    accentColor: .orange,
                    animated: animateFeatures,
                    delay: 0.3,
                    analytics: analytics
                )
                
                PremiumFeatureCard(
                    icon: "location.fill",
                    title: "Auto Check-in",
                    description: "Smart geofencing features",
                    accentColor: .purple,
                    animated: animateFeatures,
                    delay: 0.4,
                    analytics: analytics
                )
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Subscription Options Section
    private var subscriptionOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose Your Plan")
                .font(.title2.bold())
                .padding(.horizontal)
            
            if subscriptionManager.availableProducts.isEmpty {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading subscription options...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                VStack(spacing: 12) {
                    ForEach(0..<subscriptionManager.availableProducts.count, id: \.self) { index in
                        let product = subscriptionManager.availableProducts[index]
                        let isYearly = product.subscription?.subscriptionPeriod.unit == .year
                        
                        EnhancedSubscriptionOptionView(
                            product: product,
                            isSelected: selectedProductIndex == index,
                            isBestValue: isYearly,
                            savingsText: isYearly ? savingsText : nil
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedProductIndex = index
                            }
                            analytics.trackSubscriptionOptionSelected(
                                productID: product.id,
                                productName: product.displayName,
                                productPrice: product.price,
                                currency: product.priceFormatStyle.currencyCode
                            )
                        }
                    }
                }
                .padding(.horizontal)
                
                // Pricing disclaimer
                VStack(spacing: 8) {
                    Text("Cancel anytime. No commitments.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Button("Terms of Service") {
                            // Open terms URL
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("Privacy Policy") {
                            // Open privacy URL
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Helper Methods
    private var savingsText: String {
        guard subscriptionManager.availableProducts.count >= 2 else { return "" }
        
        let monthlyProduct = subscriptionManager.availableProducts[0]
        let yearlyProduct = subscriptionManager.availableProducts[1]
        
        let monthlyYearlyPrice = monthlyProduct.price * 12
        let yearlyPrice = yearlyProduct.price
        let savings = monthlyYearlyPrice - yearlyPrice
        let savingsPercentage = (savings / monthlyYearlyPrice) * 100
        
        return "Save \(Int(truncating: savingsPercentage as NSDecimalNumber))%"
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            Button {
                if let index = selectedProductIndex {
                    let productToPurchase = subscriptionManager.availableProducts[index]
                    analytics.trackBeginCheckout(
                        productID: productToPurchase.id,
                        productName: productToPurchase.displayName,
                        productPrice: productToPurchase.price,
                        currency: productToPurchase.priceFormatStyle.currencyCode
                    )
                    let product = subscriptionManager.availableProducts[index]
                    Task {
                        await subscriptionManager.purchase(product)
                        if subscriptionManager.isProUser {
                            onPurchaseComplete?() 
                            dismiss()
                            showingPurchaseSuccess = true
                            analytics.trackPurchaseCompleted(
                                productID: product.id,
                                productName: product.displayName,
                                productPrice: product.price,
                                currency: product.priceFormatStyle.currencyCode
                            )
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
            
            Button {
                Task {
                    await subscriptionManager.restorePurchases()
                    if subscriptionManager.isProUser {
                        onPurchaseComplete?()
                        dismiss()
                        analytics.trackPurchaseRestored(
                            productID: subscriptionManager.restoredProduct?.id ?? "",
                            productName: subscriptionManager.restoredProduct?.displayName ?? "",
                            productPrice: subscriptionManager.restoredProduct?.price ?? 0,
                            currency: subscriptionManager.restoredProduct?.priceFormatStyle.currencyCode ?? ""
                        )
                    }
                }
            } label: {
                Text("Restore Purchases")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .padding(.top, 8)
            .disabled(subscriptionManager.isPurchasing)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Developer Bypass Section
    private var developerBypassSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Developer Bypass")
                .font(.title2.bold())
                .padding(.horizontal)
            
            TextField("Enter developer code", text: $developerCode)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding()
            
            Button {
                subscriptionManager.attemptDeveloperBypass(with: developerCode)
                showingBypassSuccess = subscriptionManager.isProUser
                developerCode = ""
                analytics.trackDeveloperBypassGranted(
                    developerCode: developerCode
                )
            } label: {
                Text("Unlock")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                    )
                    .padding(.horizontal)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Supporting Views
struct PremiumFeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let accentColor: Color
    let animated: Bool
    let delay: Double
    let analytics: AnalyticsService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(accentColor)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accentColor.opacity(0.2))
                )
            
            Text(title)
                .font(.headline)
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .opacity(animated ? 1 : 0)
        .offset(x: 0, y: animated ? 0 : 20)
        .animation(.easeInOut(duration: 0.5).delay(delay), value: animated)
        .onTapGesture {
            analytics.trackFeatureTapped(
                featureName: title
            )
        }
    }
}

struct EnhancedSubscriptionOptionView: View {
    let product: Product
    let isSelected: Bool
    let isBestValue: Bool
    let savingsText: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.headline)
                    
                    if let subscription = product.subscription {
                        Text("\(product.displayPrice) / \(subscription.subscriptionPeriod.value) \(subscription.subscriptionPeriod.unit)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text(product.displayPrice)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let savings = savingsText {
                        Text(savings)
                            .font(.footnote)
                            .foregroundColor(.green)
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
