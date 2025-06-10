//
//  SettingsView.swift
//  Fathom
//
//  Created by Paul Thomas on 6/10/25.
//


import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Appearance")) {
                    Text("Theme Options")
                }
                Section(header: Text("Security")) {
                    Text("App Lock Settings")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
