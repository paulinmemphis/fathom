import SwiftUI
import CoreLocation
import CoreData

/// A modern, intuitive entry view for workplace check-ins
struct WorkplaceEntryView: View {
    // MARK: - Environment & State
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @StateObject private var workplaceManager = WorkplaceManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var locationManager = LocationManager()

    // The workplace to edit, if any
    var workplaceToEdit: Workplace?
    
    // State for form inputs
    @State private var workplaceName = ""
    @State private var workplaceAddress = ""
    @State private var workplaceNotes = ""
    @State private var workingHours = 8.0
    @State private var selectedDays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
    @State private var notificationsEnabled = true
    
    // State for location
    @State private var detectedLocation: CLLocationCoordinate2D?
    @State private var locationError: String?
    
    // State for UI
    @State private var isShowingAdvancedOptions = false
    @State private var isShowingPaywall = false
    @State private var isSaving = false
    @State private var showingSaveSuccess = false
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with illustration
                    headerView
                    
                    // Main form
                    formView
                    
                    // Advanced options (expandable)
                    advancedOptionsView
                    
                    // Save button
                    saveButton
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: setupForEditing)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text(workplaceToEdit == nil ? "New Workplace" : "Edit Workplace")
                        .font(.headline)
                }
            }
            .sheet(isPresented: $isShowingPaywall) {
                PaywallView_Workplace()
                    .environmentObject(subscriptionManager)
            }
            .alert("Workplace Saved", isPresented: $showingSaveSuccess) {
                Button("OK", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("Your workplace has been successfully saved.")
            }
        }
    }
    
    // MARK: - Computed Properties
    private var isProUser: Bool {
        // Allow developer bypass for testing Pro features
        #if DEBUG
        if ProcessInfo.processInfo.environment["BYPASS_PAYWALL"] == "1" { return true }
        #endif
        return subscriptionManager.isProUser
    }

    // MARK: - Component Views
    
    /// Header with illustration
    private var headerView: some View {
        VStack(spacing: 16) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
                .padding()
                .background(
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 120, height: 120)
                )
            
            Text("Add Your Workplace")
                .font(.system(.title, design: .rounded))
                .fontWeight(.bold)
            
            Text("Track your work hours and get insights about your work-life balance")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    /// Main form
    private var formView: some View {
        VStack(spacing: 20) {
            // Workplace name
            FormField(
                icon: "building.fill",
                title: "Workplace Name",
                placeholder: "e.g. Main Office",
                text: $workplaceName
            )
            
            // Workplace address with location detection
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Address", systemImage: "mappin.circle.fill")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button {
                        detectCurrentLocation()
                    } label: {
                        HStack(spacing: 4) {
                            if locationManager.isLoading {
                                UserProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                            }
                            Text("Detect")
                                .font(.caption)
                        }
                        .foregroundColor(.accentColor)
                    }
                    .disabled(locationManager.isLoading)
                }
                
                TextEditor(text: $workplaceAddress)
                    .frame(height: 80)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                
                if let error = locationError ?? locationManager.error?.localizedDescription {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            // Working hours slider
            VStack(alignment: .leading, spacing: 8) {
                Label("Working Hours", systemImage: "clock.fill")
                    .font(.headline)
                
                HStack {
                    Text("4")
                    Slider(value: $workingHours, in: 4...12, step: 0.5)
                    Text("12")
                }
                
                Text("\(workingHours, specifier: "%.1f") hours per day")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Working days selection
            VStack(alignment: .leading, spacing: 8) {
                Label("Working Days", systemImage: "calendar")
                    .font(.headline)
                
                WeekdaySelector(selectedDays: $selectedDays)
            }
            
            // Notes
            VStack(alignment: .leading, spacing: 8) {
                Label("Notes", systemImage: "note.text")
                    .font(.headline)
                
                TextEditor(text: $workplaceNotes)
                    .frame(height: 100)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .padding(.vertical)
    }
    
    /// Advanced options section (expandable)
    private var advancedOptionsView: some View {
        VStack(spacing: 16) {
            Button {
                withAnimation {
                    isShowingAdvancedOptions.toggle()
                }
            } label: {
                HStack {
                    Text("Advanced Options")
                        .font(.headline)
                    
                    Spacer()
                    
                    Image(systemName: isShowingAdvancedOptions ? "chevron.up" : "chevron.down")
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
            
            if isShowingAdvancedOptions {
                Section(header: Text("Automation").font(.title3).fontWeight(.semibold)) {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("Enable Auto Check-in/out", systemImage: "location.fill.viewfinder")
                    }
                    .disabled(!isProUser)
                    
                    if !isProUser {
                        HStack {
                            Spacer()
                            Text("This is a Pro feature.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button("Upgrade") {
                                isShowingPaywall = true
                            }
                            .font(.caption)
                            Spacer()
                        }
                    }
                    Text("Automatically checks you in when you arrive and out when you leave this workplace using geofencing.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 2)
                }
                .padding(.vertical)
                
                // Premium features (with lock icon if not pro)
                Button {
                    if !subscriptionManager.isProUser {
                        isShowingPaywall = true
                    }
                } label: {
                    HStack {
                        Label("Auto Check-in with Geofencing", systemImage: "location.circle.fill")
                            .font(.headline)
                        
                        Spacer()
                        
                        if !subscriptionManager.isProUser {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                
                // Another premium feature
                Button {
                    if !subscriptionManager.isProUser {
                        isShowingPaywall = true
                    }
                } label: {
                    HStack {
                        Label("Work-Life Balance Analytics", systemImage: "chart.bar.fill")
                            .font(.headline)
                        
                        Spacer()
                        
                        if !subscriptionManager.isProUser {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    /// Save button
    private var saveButton: some View {
        Button {
            saveWorkplace()
        } label: {
            HStack {
                if isSaving {
                    UserProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(0.8)
                } else {
                    Text(workplaceToEdit == nil ? "Save Workplace" : "Update Workplace")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.accentColor)
            )
            .foregroundColor(.white)
        }
        .disabled(workplaceName.isEmpty || workplaceAddress.isEmpty || detectedLocation == nil || isSaving)
        .opacity((workplaceName.isEmpty || workplaceAddress.isEmpty || detectedLocation == nil) ? 0.6 : 1.0)
        .padding(.vertical)
    }
    
    // MARK: - Helper Methods
    
    /// Populate form when editing an existing workplace
    private func setupForEditing() {
        if let workplace = workplaceToEdit {
            workplaceName = workplace.nameOrDefault
            workplaceAddress = workplace.addressOrDefault
            workplaceNotes = workplace.notesOrDefault
            workingHours = workplace.workingHoursPerDay
            selectedDays = Set(workplace.workingDaysArray.compactMap { Weekday(rawValue: $0) })
            // Only enable notifications if user is Pro, otherwise default to false
            notificationsEnabled = isProUser && workplace.notificationsEnabled
            
            // Set detectedLocation if workplace has valid coordinates
            if workplace.latitude != 0 && workplace.longitude != 0 {
                detectedLocation = CLLocationCoordinate2D(latitude: workplace.latitude, longitude: workplace.longitude)
            }
        } else {
            // If creating a new workplace and user is not Pro, ensure notificationsEnabled is false
            if !isProUser {
                notificationsEnabled = false
            }
            // For new workplaces, notificationsEnabled defaults to true if user is Pro, or false if not (as set above)
            // No specific else needed here as @State notificationsEnabled = true is the initial default for Pro users.
        }
    }


    
    /// Detect current location using the LocationManager
    private func detectCurrentLocation() {
        Task {
            locationError = nil
            do {
                let location = try await locationManager.requestLocation()
                self.detectedLocation = location.coordinate
                
                // Perform reverse geocoding to get a user-friendly address
                let geocoder = CLGeocoder()
                if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
                    var addressString = ""
                    if let street = placemark.thoroughfare {
                        addressString += street
                    }
                    if let city = placemark.locality {
                        if !addressString.isEmpty { addressString += ", " }
                        addressString += city
                    }
                    if let state = placemark.administrativeArea {
                        if !addressString.isEmpty { addressString += ", " }
                        addressString += state
                    }
                    if let zip = placemark.postalCode {
                        if !addressString.isEmpty { addressString += " " }
                        addressString += zip
                    }
                    self.workplaceAddress = addressString.trimmingCharacters(in: [",", " "])
                } else {
                    self.workplaceAddress = "Lat: \(location.coordinate.latitude), Lon: \(location.coordinate.longitude)"
                }
                
            } catch {
                if let clError = error as? CLError {
                    switch clError.code {
                    case .denied:
                        locationError = "Location access denied. Please enable it in Settings."
                    case .locationUnknown:
                        locationError = "Unable to determine location. Please try again."
                    default:
                        locationError = "An unknown location error occurred."
                    }
                } else {
                    locationError = error.localizedDescription
                }
            }
        }
    }
    
    /// Save workplace
    private func saveWorkplace() {
        guard let location = detectedLocation else {
            locationError = "Please detect a location for the workplace."
            return
        }
        
        isSaving = true
        
        Task {
            let success: Bool
            let workingDaysRawValues = Array(selectedDays.map { $0.rawValue })
            
            if let workplace = workplaceToEdit {
                // Update existing workplace
                success = await workplaceManager.updateWorkplace(
                    workplace: workplace,
                    name: workplaceName,
                    address: workplaceAddress,
                    coordinate: location,
                    workingHours: workingHours,
                    workingDays: workingDaysRawValues,
                    notes: workplaceNotes,
                    notificationsEnabled: self.notificationsEnabled // Explicit self for clarity
                )
            } else {
                // Create new workplace
                let newWorkplace = await workplaceManager.createWorkplace(
                    name: workplaceName,
                    address: workplaceAddress,
                    coordinate: location,
                    workingHours: workingHours,
                    workingDays: workingDaysRawValues,
                    notes: workplaceNotes,
                    notificationsEnabled: self.notificationsEnabled // Explicit self for clarity
                )
                success = newWorkplace != nil
            }
            
            isSaving = false
            if success {
                showingSaveSuccess = true
            } else {
                // Optionally show an error alert from workplaceManager.errorMessage
            }
        }
    }
}

// MARK: - Supporting Views and Models

/// Custom form field with icon
struct FormField: View {
    let icon: String
    let title: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
            
            TextField(placeholder, text: $text)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

/// Weekday selector
struct WeekdaySelector: View {
    @Binding var selectedDays: Set<Weekday>
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(Weekday.allCases) { day in
                WeekdayButton(
                    day: day,
                    isSelected: selectedDays.contains(day),
                    action: {
                        if selectedDays.contains(day) {
                            selectedDays.remove(day)
                        } else {
                            selectedDays.insert(day)
                        }
                    }
                )
            }
        }
    }
}

/// Individual weekday button
struct WeekdayButton: View {
    let day: Weekday
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(day.shortName)
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

/// Weekday enum
enum Weekday: Int, CaseIterable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
    
    var id: Int { self.rawValue }
    
    var shortName: String {
        switch self {
        case .sunday: return "S"
        case .monday: return "M"
        case .tuesday: return "T"
        case .wednesday: return "W"
        case .thursday: return "T"
        case .friday: return "F"
        case .saturday: return "S"
        }
    }
}

// MARK: - Preview
struct WorkplaceEntryView_Previews: PreviewProvider {
    static var previews: some View {
        // Preview for creating a new workplace
        WorkplaceEntryView()
            .environmentObject(SubscriptionManager())

        // Preview for editing an existing workplace
        WorkplaceEntryView(workplaceToEdit: {
            let context = PersistenceController.preview.container.viewContext
            let workplace = Workplace(context: context)
            workplace.id = UUID()
            workplace.name = "Existing Office"
            workplace.address = "456 Tech Avenue, Cupertino, CA"
            workplace.workingHoursPerDay = 7.5
            workplace.workingDaysArray = [1, 2, 3] // Sun, Mon, Tue
            workplace.latitude = 37.334_900
            workplace.longitude = -122.009_020
            return workplace
        }())
        .environmentObject(SubscriptionManager())
    }
}
