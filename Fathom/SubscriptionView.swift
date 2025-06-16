import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @State private var showingPaywall = false
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        
                        Text("Fathom Pro")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Unlock your full workplace wellness potential")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(icon: "location.fill", title: "Auto Check-In", description: "Automatically track your workplace presence with geofencing")
                        FeatureRow(icon: "brain.head.profile", title: "Advanced Insights", description: "Get personalized wellness recommendations and analytics")
                        FeatureRow(icon: "bell.fill", title: "Smart Notifications", description: "Contextual reminders for breathing and reflection")
                        FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Progress Tracking", description: "Detailed analytics and goal progress visualization")
                        FeatureRow(icon: "person.2.fill", title: "Team Features", description: "Collaborate on workplace wellness initiatives")
                    }
                    .padding(.horizontal)
                    
                    // Subscription Status
                    VStack(spacing: 16) {
                        if subscriptionManager.isProUser {
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.green)
                                
                                Text("You're subscribed to Fathom Pro!")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                Text("Enjoying all premium features")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                        } else {
                            Button(action: {
                                showingPaywall = true
                            }) {
                                Text("Upgrade to Pro")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        LinearGradient(
                                            colors: [.orange, .red],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingPaywall) {
            // Placeholder for paywall view
            VStack {
                Text("Subscription Purchase")
                    .font(.title)
                    .padding()
                
                Text("In-app purchase functionality will be implemented here.")
                    .multilineTextAlignment(.center)
                    .padding()
                
                Button("Close") {
                    showingPaywall = false
                }
                .padding()
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.orange)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    SubscriptionView()
}
