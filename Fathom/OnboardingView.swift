//
//  OnboardingView.swift
//  Fathom
//
//  Created by Paul Thomas on 6/15/25.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack {
            Text("Welcome to Fathom")
                .font(.largeTitle)
                .padding()
            
            Text("Your AI-powered workplace wellness companion")
                .font(.title2)
                .foregroundColor(.secondary)
                .padding()
            
            Spacer()
            
            Button("Get Started") {
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                isPresented = false
            }
            .foregroundColor(.white)
            .fontWeight(.medium)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.blue)
            .cornerRadius(25)
            .padding()
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Preview
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(isPresented: .constant(true))
    }
}
