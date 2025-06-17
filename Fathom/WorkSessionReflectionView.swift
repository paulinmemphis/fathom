import SwiftUI
import CoreData
import UIKit

// Import the main module to access WorkplaceCheckIn


struct WorkSessionReflectionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    // The WorkplaceCheckIn object to update
    @ObservedObject var checkIn: WorkplaceCheckIn

    // Reflection data
    @State private var focusRating: Int = 0
    @State private var stressRating: Int = 0
    @State private var sessionNote: String = ""

    private let ratingRange = 1...5

    init(checkIn: WorkplaceCheckIn) {
        self.checkIn = checkIn
        // Initialize state with defaults until Core Data model is updated
        // TODO: Uncomment when attributes are added to WorkplaceCheckIn entity
        // _focusRating = State(initialValue: Int(checkIn.focusRating))
        // _stressRating = State(initialValue: Int(checkIn.stressRating))
        // _sessionNote = State(initialValue: checkIn.sessionNote ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Rate Your Session")) {
                    Picker("Focus Level (1=Low, 5=High)", selection: $focusRating) {
                        ForEach(ratingRange, id: \.self) { rating in
                            Text("\(rating)").tag(rating)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    Picker("Stress Level (1=Low, 5=High)", selection: $stressRating) {
                        ForEach(ratingRange, id: \.self) { rating in
                            Text("\(rating)").tag(rating)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section(header: Text("Optional Note")) {
                    TextEditor(text: $sessionNote)
                        .frame(height: 100)
                        .border(Color(UIColor.systemGray5), width: 1)
                        .cornerRadius(5)
                }

                Button(action: saveReflection) {
                    Text("Save Reflection")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: skipReflection) {
                    Text("Skip for Now")
                        .frame(maxWidth: .infinity)
                }
                .tint(.gray)
            }
            .navigationTitle("Session Reflection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveReflection()
                    }
                }
            }
        }
    }

    private func saveReflection() {
        // Save the reflection data to the checkIn object
        checkIn.focusRating = Int16(focusRating)
        checkIn.stressRating = Int16(stressRating)
        checkIn.sessionNote = sessionNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : sessionNote

        do {
            try viewContext.save()
            Task { @MainActor in
                UserStatsManager.shared.logReflectionAdded()
            }
            print("Reflection saved successfully for check-in: \(checkIn.objectID)")
        } catch {
            let nsError = error as NSError
            print("Unresolved error saving reflection \(nsError), \(nsError.userInfo)")
            // Handle error appropriately
        }
        dismiss()
    }

    private func skipReflection() {
        // Simply dismiss without saving new reflection data
        // Existing data (if any) on checkIn remains unchanged unless user interacted with controls
        dismiss()
    }
}

// Preview requires a mock WorkplaceCheckIn and managed object context
struct WorkSessionReflectionView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock context
        let context = PersistenceController.preview.container.viewContext
        
        // Create a mock WorkplaceCheckIn
        let mockCheckIn = WorkplaceCheckIn(context: context)
        mockCheckIn.checkInTime = Date()
        mockCheckIn.focusRating = 3
        mockCheckIn.stressRating = 2
        
        // Save the context
        try? context.save()
        
        return WorkSessionReflectionView(checkIn: mockCheckIn)
            .environment(\.managedObjectContext, context)
    }
    
    // Create a test container
    static let testContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Fathom")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Failed to load test store: \(error)")
            }
        }
        return container
    }()
}
