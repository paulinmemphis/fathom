import SwiftUI

struct WorkSessionReflectionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    // The WorkplaceCheckIn object to update
    @ObservedObject var checkIn: WorkplaceCheckIn

    @State private var focusRating: Int // Use Int for picker, will convert from Int16
    @State private var stressRating: Int // Use Int for picker, will convert from Int16
    @State private var sessionNote: String

    private let ratingRange = 1...5

    init(checkIn: WorkplaceCheckIn) {
        self.checkIn = checkIn
        // Initialize state from the CheckIn object, providing defaults if nil
        _focusRating = State(initialValue: Int(checkIn.focusRating))
        _stressRating = State(initialValue: Int(checkIn.stressRating))
        _sessionNote = State(initialValue: checkIn.sessionNote ?? "")
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
        checkIn.focusRating = Int16(focusRating)
        checkIn.stressRating = Int16(stressRating)
        checkIn.sessionNote = sessionNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : sessionNote

        do {
            try viewContext.save()
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
        // You might want to create a mock Workplace and assign it too for completeness

        return WorkSessionReflectionView(checkIn: mockCheckIn)
            .environment(\.managedObjectContext, context)
    }
}
