//
//  OnboardingView.swift
//  Fathom
//
//  Created by Paul Thomas on 6/15/25.
//

import SwiftUI
import Combine

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @StateObject private var personalizationEngine = PersonalizationEngine.shared
    
    @State private var selection = 0
    @State private var selectedRole: WorkRole = .developer
    @State private var selectedIndustry: WorkIndustry = .technology

    var body: some View {
        TabView(selection: $selection) {
            WelcomeStep(selection: $selection)
                .tag(0)
            
            PersonalizationStep(selectedRole: $selectedRole, selectedIndustry: $selectedIndustry, selection: $selection)
                .tag(1)
            
            CompletionStep(isPresented: $isPresented, selectedRole: selectedRole, selectedIndustry: selectedIndustry)
                .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .animation(.easeInOut, value: selection)
    }
}

// MARK: - Carousel Feature Item Structure

struct OnboardingFeatureItem: Identifiable {
    let id = UUID()
    let iconName: String
    let title: String
    let description: String
}

// MARK: - Onboarding Steps

struct WelcomeStep: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Binding var selection: Int
    
    // Feature carousel data
    private let features: [OnboardingFeatureItem] = [
        OnboardingFeatureItem(iconName: "brain.head.profile", title: "AI-Powered Insights", description: "Get insights tailored to your work patterns and goals."),
        OnboardingFeatureItem(iconName: "figure.mind.and.body", title: "Wellness Toolkit", description: "Access breathing exercises, focus timers, and more."),
        OnboardingFeatureItem(iconName: "book.closed.fill", title: "Reflective Journaling", description: "Track your progress, thoughts, and feelings."),
        OnboardingFeatureItem(iconName: "target", title: "Achieve Your Goals", description: "Set and track personal and professional objectives.")
    ]
    
    @State private var carouselSelection = 0
    private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            // Inner content VStack
            VStack(spacing: 20) {
                Text("Welcome to Fathom")
                    .font(.largeTitle).bold()
                Text("Your AI-powered workplace wellness companion.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Feature Carousel
                TabView(selection: $carouselSelection) {
                    ForEach(features) { feature in
                        FeatureCarouselSlideView(item: feature)
                            .tag(features.firstIndex(where: { $0.id == feature.id }) ?? 0)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: 280) // Adjust height as needed for content
                .onReceive(timer) { _ in
                    withAnimation {
                        carouselSelection = (carouselSelection + 1) % features.count
                    }
                }
                
                Spacer()
                Button("Continue") { selection = 1 }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .frame(maxWidth: horizontalSizeClass == .compact ? .infinity : 500) // Constrain width on wider screens
            Spacer()
        }
        .padding()
    }
}

struct PersonalizationStep: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Binding var selectedRole: WorkRole
    @Binding var selectedIndustry: WorkIndustry
    @Binding var selection: Int

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            VStack(spacing: 20) {
                Text("Tell Us About Your Work")
                    .font(.largeTitle).bold()
                    .multilineTextAlignment(.center)
                Text("This helps us personalize your insights.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                WorkProfileSection(selectedRole: $selectedRole, selectedIndustry: $selectedIndustry)
                
                Spacer()
                VStack(spacing: 12) {
                    Button("Continue") { selection = 2 }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity) // Make button full width
                    
                    Button("Skip for Now") { selection = 2 } // Also proceeds to next step
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .controlSize(.regular)
                }
            }
            .frame(maxWidth: horizontalSizeClass == .compact ? .infinity : 500)
            Spacer()
        }
        .padding()
    }
}

struct CompletionStep: View {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Binding var isPresented: Bool
    let selectedRole: WorkRole
    let selectedIndustry: WorkIndustry
    @StateObject private var personalizationEngine = PersonalizationEngine.shared

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                Text("You're All Set!")
                    .font(.largeTitle).bold()
                Text("Fathom is now personalized for you.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text("Explore your **Insights** or try a **Breathing Exercise** from the Tools tab to get started.")
                    .font(.callout)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.top, 5)
                    .padding(.horizontal, 30)
                
                Spacer()
                Button("Get Started") {
                    Task {
                        await personalizationEngine.setUserProfile(role: selectedRole, industry: selectedIndustry)
                        await personalizationEngine.savePreferences()
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                        isPresented = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .frame(maxWidth: horizontalSizeClass == .compact ? .infinity : 500)
            Spacer()
        }
        .padding()
    }
}



// MARK: - Feature Carousel Slide View

struct FeatureCarouselSlideView: View {
    let item: OnboardingFeatureItem
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: item.iconName)
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .padding(.bottom, 10)
            
            Text(item.title)
                .font(.title2).bold()
                .multilineTextAlignment(.center)
            
            Text(item.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.horizontal, 20) // Add some horizontal padding to the slide content
    }
}

// MARK: - Preview
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(isPresented: .constant(true))
    }
}
