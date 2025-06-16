import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @StateObject private var notificationManager = ContextualNotificationManager.shared
    @StateObject private var personalizationEngine = PersonalizationEngine.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingPermissionAlert = false
    @State private var enableContextualNotifications = true
    @State private var enableSmartNotifications = true
    @State private var enableReflectionReminders = true
    @State private var enableBreathingReminders = true
    @State private var enableDailyInsights = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "bell.badge")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)
                        
                        Text("Smart Notifications")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Get personalized notifications that adapt to your work patterns and preferences")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top)
                    
                    // Permission Status
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: notificationManager.notificationPermissionGranted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                                .foregroundColor(notificationManager.notificationPermissionGranted ? .green : .orange)
                            Text("Notification Permission")
                                .font(.headline)
                        }
                        
                        if notificationManager.notificationPermissionGranted {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Notifications are enabled")
                                    .font(.subheadline)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "bell.slash")
                                        .foregroundColor(.orange)
                                    Text("Notifications are disabled")
                                        .font(.subheadline)
                                }
                                
                                Button("Enable Notifications") {
                                    Task {
                                        let granted = await notificationManager.requestNotificationPermission()
                                        if !granted {
                                            showingPermissionAlert = true
                                        }
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    
                    // Contextual Notifications
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "brain")
                                .foregroundColor(.purple)
                            Text("Contextual Notifications")
                                .font(.headline)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Smart Stress Alerts", isOn: $enableContextualNotifications)
                                .disabled(!notificationManager.notificationPermissionGranted)
                            
                            Text("Get notified when patterns indicate high stress or low focus, with personalized suggestions based on your role as a \(personalizationEngine.userRole.rawValue)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Active triggers display
                        if !personalizationEngine.contextualTriggers.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Active Triggers")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                LazyVStack(spacing: 8) {
                                    ForEach(Array(personalizationEngine.contextualTriggers.prefix(3)), id: \.id) { trigger in
                                        TriggerRow(trigger: trigger)
                                    }
                                    
                                    if personalizationEngine.contextualTriggers.count > 3 {
                                        Text("+ \(personalizationEngine.contextualTriggers.count - 3) more triggers")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    
                    // Scheduled Notifications
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "clock.badge")
                                .foregroundColor(.blue)
                            Text("Scheduled Reminders")
                                .font(.headline)
                        }
                        
                        VStack(spacing: 16) {
                            Toggle("Daily Reflection Reminders", isOn: $enableReflectionReminders)
                                .disabled(!notificationManager.notificationPermissionGranted)
                            
                            Toggle("Breathing Break Reminders", isOn: $enableBreathingReminders)
                                .disabled(!notificationManager.notificationPermissionGranted)
                            
                            Toggle("Daily Insights Summary", isOn: $enableDailyInsights)
                                .disabled(!notificationManager.notificationPermissionGranted)
                        }
                        
                        if enableBreathingReminders {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Optimal Times for \(personalizationEngine.userRole.rawValue)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                let breathingTimes = getOptimalBreathingTimesDisplay(for: personalizationEngine.userRole)
                                HStack(spacing: 12) {
                                    ForEach(breathingTimes, id: \.self) { time in
                                        Text(time)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.1))
                                            .foregroundColor(.blue)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    
                    // Active Notifications
                    if !notificationManager.activeNotifications.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "list.bullet")
                                    .foregroundColor(.orange)
                                Text("Active Notifications")
                                    .font(.headline)
                            }
                            
                            Text("\(notificationManager.activeNotifications.count) notifications scheduled")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Button("Clear All Notifications") {
                                notificationManager.cancelAllPersonalizedNotifications()
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    }
                    
                    // Tips Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                            Text("Notification Tips")
                                .font(.headline)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            TipRow(icon: "clock", text: "Notifications adapt to your work schedule and role")
                            TipRow(icon: "brain", text: "Contextual alerts learn from your patterns")
                            TipRow(icon: "bell.slash", text: "Dismiss notifications to reduce similar ones")
                            TipRow(icon: "gear", text: "Timing automatically optimizes based on your usage")
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
                .padding()
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadNotificationSettings()
            }
            .onChange(of: enableSmartNotifications) { _, newValue in
                if newValue && notificationManager.notificationPermissionGranted {
                    notificationManager.scheduleSmartNotifications()
                } else {
                    notificationManager.cancelNotifications(withPrefix: "smart_")
                }
                saveNotificationSettings()
            }
            .onChange(of: enableContextualNotifications) { _, _ in
                saveNotificationSettings()
            }
            .onChange(of: enableReflectionReminders) { _, _ in
                saveNotificationSettings()
            }
            .onChange(of: enableBreathingReminders) { _, _ in
                saveNotificationSettings()
            }
            .onChange(of: enableDailyInsights) { _, _ in
                saveNotificationSettings()
            }
        }
        .alert("Notification Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("To receive personalized notifications, please enable notifications in Settings.")
        }
    }
    
    private func getOptimalBreathingTimesDisplay(for role: WorkRole) -> [String] {
        switch role {
        case .developer:
            return ["10:30 AM", "2:00 PM", "4:30 PM"]
        case .manager:
            return ["9:45 AM", "1:15 PM", "3:45 PM"]
        case .designer:
            return ["11:00 AM", "2:30 PM", "5:00 PM"]
        default:
            return ["10:15 AM", "2:15 PM", "4:15 PM"]
        }
    }
    
    private func loadNotificationSettings() {
        let defaults = UserDefaults.standard
        enableContextualNotifications = defaults.bool(forKey: "enableContextualNotifications")
        enableSmartNotifications = defaults.bool(forKey: "enableSmartNotifications")
        enableReflectionReminders = defaults.bool(forKey: "enableReflectionReminders")
        enableBreathingReminders = defaults.bool(forKey: "enableBreathingReminders")
        enableDailyInsights = defaults.bool(forKey: "enableDailyInsights")
        
        // Default to true if never set
        if !defaults.object(forKey: "enableContextualNotifications") != nil {
            enableContextualNotifications = true
            enableSmartNotifications = true
            enableReflectionReminders = true
            enableBreathingReminders = true
            enableDailyInsights = true
        }
    }
    
    private func saveNotificationSettings() {
        let defaults = UserDefaults.standard
        defaults.set(enableContextualNotifications, forKey: "enableContextualNotifications")
        defaults.set(enableSmartNotifications, forKey: "enableSmartNotifications")
        defaults.set(enableReflectionReminders, forKey: "enableReflectionReminders")
        defaults.set(enableBreathingReminders, forKey: "enableBreathingReminders")
        defaults.set(enableDailyInsights, forKey: "enableDailyInsights")
    }
}

struct TriggerRow: View {
    let trigger: ContextualTrigger
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color.blue)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(trigger.name)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("Priority: \(trigger.priority), Cooldown: \(trigger.cooldownHours)h")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NotificationSettingsView()
}
