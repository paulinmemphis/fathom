import Foundation
import CoreData
import CoreLocation
import Combine

/// Manager class for handling workplace-related operations
@MainActor
class WorkplaceManager: ObservableObject {
    // MARK: - Properties
    
    /// Shared instance for app-wide access. 
    /// IMPORTANT: This will need to be configured with dependencies after app launch.
    static let shared = WorkplaceManager()
    
    private var viewContext: NSManagedObjectContext // Made var to allow configureShared to set it
    private var locationManager: LocationManager
    private var subscriptionManager: SubscriptionManager
    private var cancellables = Set<AnyCancellable>()
    
    /// Default radius for geofences in meters.
    private let geofenceRadius: CLLocationDistance = 150.0 // Approx 500 feet
    
    /// Published properties for UI updates
    @Published var workplaces: [Workplace] = []
    @Published var activeCheckIn: Fathom.WorkplaceCheckIn?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var presentingReflectionSheetForCheckIn: Fathom.WorkplaceCheckIn? = nil
    
    // MARK: - Initialization
    
    /// Initializes the WorkplaceManager.
    /// - Parameters:
    ///   - viewContext: The Core Data managed object context.
    ///   - locationManager: The manager for location services and geofencing.
    ///   - subscriptionManager: The manager for handling user subscription status.
    init(viewContext: NSManagedObjectContext = PersistenceController.shared.container.viewContext,
         locationManager: LocationManager = LocationManager(), // Default for shared, but should be injected
         subscriptionManager: SubscriptionManager = SubscriptionManager()) { // Default for shared, but should be injected
        self.viewContext = viewContext
        self.locationManager = locationManager
        self.subscriptionManager = subscriptionManager
        
        Task {
            await loadWorkplaces()
            await checkForActiveCheckIn()
            // After loading workplaces, set up geofences for those with auto check-in enabled
            await setupInitialGeofences()
        }
        
        subscribeToRegionEvents()
    }
    
    /// Configures the shared instance with necessary dependencies. Call this early in app lifecycle.
    static func configureShared(viewContext: NSManagedObjectContext, locationManager: LocationManager, subscriptionManager: SubscriptionManager) {
        shared.viewContext = viewContext
        shared.locationManager = locationManager
        shared.subscriptionManager = subscriptionManager
        // Re-initialize tasks and subscriptions if shared was already used with defaults
        Task {
            await shared.loadWorkplaces()
            await shared.checkForActiveCheckIn()
            await shared.setupInitialGeofences()
        }
        shared.cancellables.removeAll() // Clear old subscriptions if any
        shared.subscribeToRegionEvents()
    }

    private func subscribeToRegionEvents() {
        locationManager.regionEventSubject
            .sink { [weak self] (regionIdentifier, eventType) in
                guard let self = self else { return }
                Task {
                    await self.handleRegionEvent(identifier: regionIdentifier, eventType: eventType)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Geofence Management

    private func setupInitialGeofences() async {
        guard subscriptionManager.isProUser else { 
            print("Geofencing setup skipped: User is not Pro.")
            // Optionally, clear any existing geofences if user is no longer Pro
            for region in locationManager.monitoredRegions {
                locationManager.stopMonitoring(workplaceID: region.identifier)
            }
            return
        }
        for workplace in workplaces where workplace.notificationsEnabled {
            guard let id = workplace.id?.uuidString else { continue }
            // Ensure coordinate is valid before monitoring
            if CLLocationCoordinate2DIsValid(workplace.coordinate) {
                 locationManager.startMonitoring(workplaceID: id, 
                                          center: workplace.coordinate, 
                                          radius: geofenceRadius)
            } else {
                print("Skipping geofence for \(workplace.name ?? "Unknown") due to invalid coordinate.")
            }
        }
    }

    private func handleRegionEvent(identifier: String, eventType: RegionEventType) async {
        guard let workplace = await fetchWorkplace(byID: identifier) else {
            print("Geofence event for unknown workplace ID: \(identifier)")
            return
        }

        guard subscriptionManager.isProUser else {
            print("Geofence event for \(workplace.name ?? "Unknown") ignored: User is not Pro.")
            return
        }
        
        guard workplace.notificationsEnabled else {
            print("Geofence event for \(workplace.name ?? "Unknown") ignored: Auto check-in disabled for this workplace.")
            return
        }

        switch eventType {
        case .entry:
            // Only auto-check-in if not already checked in to this workplace or another one
            if activeCheckIn == nil {
                print("Automatic check-in for: \(workplace.name ?? "Unknown")")
                _ = await checkIn(to: workplace, isAuto: true)
            } else if (activeCheckIn?.workplace as? Workplace) != workplace {
                print("Already checked in to \((activeCheckIn?.workplace as? Workplace)?.name ?? "another workplace"). Skipping auto check-in for \(workplace.name ?? "Unknown").")
            } else {
                print("Already checked in to \(workplace.name ?? "Unknown"). Skipping duplicate auto check-in.")
            }
        case .exit:
            // Only auto-checkout if the current active check-in is for THIS workplace and was an auto check-in
            if let currentActive = activeCheckIn, currentActive.workplace == workplace, currentActive.isAutoCheckIn {
                print("Automatic check-out for: \(workplace.name ?? "Unknown")")
                _ = await checkOut(isAuto: true)
            } else if activeCheckIn?.workplace == workplace {
                print("Manual check-in detected for \(workplace.name ?? "Unknown"). Skipping auto check-out upon region exit.")
            } else {
                 print("No active auto check-in for \(workplace.name ?? "Unknown") upon region exit or already checked out.")
            }
        }
    }

    private func manageGeofence(for workplace: Workplace) {
        guard let id = workplace.id?.uuidString else { return }

        // Ensure coordinate is valid before attempting to monitor
        guard CLLocationCoordinate2DIsValid(workplace.coordinate) else {
            print("Cannot manage geofence for \(workplace.name ?? "Unknown"): Invalid coordinate.")
            locationManager.stopMonitoring(workplaceID: id) // Stop if it was somehow active with invalid coord
            return
        }

        if workplace.notificationsEnabled && subscriptionManager.isProUser {
            locationManager.startMonitoring(workplaceID: id, center: workplace.coordinate, radius: geofenceRadius)
        } else {
            locationManager.stopMonitoring(workplaceID: id)
        }
    }

    private func fetchWorkplace(byID uuidString: String) async -> Workplace? {
        guard let uuid = UUID(uuidString: uuidString) else { return nil }
        let fetchRequest: NSFetchRequest<Workplace> = Workplace.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            return results.first
        } catch {
            print("Error fetching workplace by ID \(uuidString): \(error)")
            return nil
        }
    }
    
    // MARK: - Data Operations
    
    /// Load all workplaces from Core Data
    func loadWorkplaces() async {
        isLoading = true
        defer { isLoading = false }
        
        let fetchRequest: NSFetchRequest<Workplace> = Workplace.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Workplace.name, ascending: true)]
        
        do {
            workplaces = try viewContext.fetch(fetchRequest)
        } catch {
            errorMessage = "Failed to load workplaces: \(error.localizedDescription)"
            print("Error loading workplaces: \(error)")
        }
    }
    
    /// Create a new workplace
    func createWorkplace(
        name: String,
        address: String,
        coordinate: CLLocationCoordinate2D,
        workingHours: Double,
        workingDays: [Int],
        notes: String,
        notificationsEnabled: Bool
    ) async -> Workplace? {
        let workplace = Workplace(context: viewContext)
        workplace.id = UUID()
        workplace.name = name
        workplace.address = address
        workplace.coordinate = coordinate
        workplace.workingHoursPerDay = workingHours
        workplace.workingDaysArray = workingDays
        workplace.notes = notes
        workplace.notificationsEnabled = notificationsEnabled
        workplace.createdAt = Date()
        workplace.updatedAt = Date()
        
        do {
            try viewContext.save()
            await loadWorkplaces() // Reloads the workplaces array
            manageGeofence(for: workplace) // Manage geofence after saving
            return workplace
        } catch {
            errorMessage = "Failed to save workplace: \(error.localizedDescription)"
            print("Error saving workplace: \(error)")
            viewContext.rollback()
            return nil
        }
    }
    
    /// Update an existing workplace
    func updateWorkplace(
        workplace: Workplace,
        name: String,
        address: String,
        coordinate: CLLocationCoordinate2D,
        workingHours: Double,
        workingDays: [Int],
        notes: String,
        notificationsEnabled: Bool
    ) async -> Bool {
        workplace.name = name
        workplace.address = address
        workplace.coordinate = coordinate
        workplace.workingHoursPerDay = workingHours
        workplace.workingDaysArray = workingDays
        workplace.notes = notes
        workplace.notificationsEnabled = notificationsEnabled
        workplace.updatedAt = Date()
        
        do {
            try viewContext.save()
            await loadWorkplaces() // Reloads the workplaces array
            manageGeofence(for: workplace) // Manage geofence after saving changes
            return true
        } catch {
            errorMessage = "Failed to update workplace: \(error.localizedDescription)"
            print("Error updating workplace: \(error)")
            viewContext.rollback()
            return false
        }
    }
    
    /// Delete a workplace
    func deleteWorkplace(_ workplace: Workplace) async -> Bool {
        // Stop geofencing before deleting
        if let id = workplace.id?.uuidString {
            locationManager.stopMonitoring(workplaceID: id)
        }

        viewContext.delete(workplace)
        
        do {
            try viewContext.save()
            await loadWorkplaces()
            return true
        } catch {
            errorMessage = "Failed to delete workplace: \(error.localizedDescription)"
            print("Error deleting workplace: \(error)")
            viewContext.rollback()
            return false
        }
    }
    
    // MARK: - Check-in Operations
    
    /// Check for any active check-in
    func checkForActiveCheckIn() async {
        let fetchRequest: NSFetchRequest<WorkplaceCheckIn> = WorkplaceCheckIn.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "checkInTime != nil AND checkOutTime == nil")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \WorkplaceCheckIn.checkInTime, ascending: false)]
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            activeCheckIn = results.first
        } catch {
            print("Error checking for active check-in: \(error)")
            activeCheckIn = nil
        }
    }
    
    /// Check in to a workplace
    func checkIn(to workplace: Workplace, notes: String = "", isAuto: Bool = false) async -> Bool {
        await checkForActiveCheckIn() // Ensure activeCheckIn property is up-to-date

        if activeCheckIn != nil {
            errorMessage = "You are already checked in. Please check out first."
            print("Attempted to check in while already checked in to \((activeCheckIn?.workplace as? Workplace)?.name ?? "a workplace").")
            return false
        }

        let newCheckIn = WorkplaceCheckIn(context: viewContext)
        newCheckIn.id = UUID()
        newCheckIn.workplace = workplace
        newCheckIn.checkInTime = Date()
        newCheckIn.notes = notes
        newCheckIn.isAutoCheckIn = isAuto
        newCheckIn.checkOutTime = nil // Explicitly nil for new check-ins
        newCheckIn.isAutoCheckOut = false // Default, will be set on checkout

        do {
            try viewContext.save()
            self.activeCheckIn = newCheckIn
            print("Successfully checked in to \(workplace.name ?? "Unknown") at \(newCheckIn.checkInTime!)")
            // Do NOT log work session completion here, only on check-out.
            return true
        } catch {
            errorMessage = "Failed to save new check-in: \(error.localizedDescription)"
            print("Error saving new check-in: \(error)")
            viewContext.rollback()
            return false
        }
    }

    /// Check out from the active workplace
    func checkOut(notes: String = "", isAuto: Bool = false) async -> Bool {
        await checkForActiveCheckIn() // Ensure activeCheckIn property is up-to-date

        guard let currentActiveCheckIn = activeCheckIn else {
            errorMessage = "No active check-in found to check out from."
            print("Attempted to check out when no active check-in exists.")
            return false
        }

        currentActiveCheckIn.checkOutTime = Date()
        if !notes.isEmpty {
            currentActiveCheckIn.notes = (currentActiveCheckIn.notes ?? "") + "\n" + notes // Append notes if any exist
        }
        currentActiveCheckIn.isAutoCheckOut = isAuto

        let checkedOutSession = currentActiveCheckIn // Capture for reflection sheet and logging

        do {
            try viewContext.save()
            self.activeCheckIn = nil // Clear the active check-in
            print("Successfully checked out from \((checkedOutSession.workplace as? Workplace)?.name ?? "Unknown") at \(checkedOutSession.checkOutTime!)")
            
            // Log work session completion for streaks/achievements
            Task { @MainActor in
                UserStatsManager.shared.logWorkSessionCompleted(on: checkedOutSession.checkOutTime ?? Date())
            }

            // Present reflection sheet if it was a manual checkout
            if !isAuto {
                self.presentingReflectionSheetForCheckIn = checkedOutSession
            }
            return true
        } catch {
            errorMessage = "Failed to save check-out: \(error.localizedDescription)"
            print("Error saving check-out: \(error)")
            viewContext.rollback()
            return false
        }
    }
    
    /// Get check-in history for a workplace
    func getCheckInHistory(for workplace: Workplace, limit: Int = 50) async -> [WorkplaceCheckIn] {
        let fetchRequest: NSFetchRequest<WorkplaceCheckIn> = WorkplaceCheckIn.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "workplace == %@", workplace)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \WorkplaceCheckIn.checkInTime, ascending: false)]
        fetchRequest.fetchLimit = limit
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching check-in history: \(error)")
            return []
        }
    }
    
    /// Get all check-ins within a date range
    func getCheckIns(from startDate: Date, to endDate: Date) async -> [WorkplaceCheckIn] {
        let fetchRequest: NSFetchRequest<WorkplaceCheckIn> = WorkplaceCheckIn.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "checkInTime >= %@ AND checkInTime <= %@", startDate as NSDate, endDate as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \WorkplaceCheckIn.checkInTime, ascending: false)]
        
        do {
            return try viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching check-ins in date range: \(error)")
            return []
        }
    }
    
    // MARK: - Public Accessors for Context (e.g., for Sheets)

    func viewContextForSheet() -> NSManagedObjectContext {
        return self.viewContext
    }
    
    // MARK: - Helper Methods
    
    /// Find the nearest workplace to a given location
    func findNearestWorkplace(to location: CLLocation, maxDistance: CLLocationDistance = 500) -> Workplace? {
        var nearestWorkplace: Workplace?
        var shortestDistance = CLLocationDistance.greatestFiniteMagnitude
        
        for workplace in workplaces {
            let workplaceLocation = CLLocation(latitude: workplace.latitude, longitude: workplace.longitude)
            let distance = location.distance(from: workplaceLocation)
            
            if distance < shortestDistance && distance <= maxDistance {
                shortestDistance = distance
                nearestWorkplace = workplace
            }
        }
        
        return nearestWorkplace
    }
    
    /// Clear any error message
    func clearError() {
        errorMessage = nil
    }
}
