import SwiftUI
import CoreData

/// A view that displays a list of all saved workplaces.
struct WorkplaceListView: View {
    // MARK: - Environment & State
    @StateObject private var workplaceManager = WorkplaceManager.shared
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    
    @State private var isShowingEntryView = false
    @State private var workplaceToEdit: Workplace? = nil
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) { // Added spacing: 0 if needed, or adjust as preferred
            StreaksDisplayView()
                .padding(.horizontal)
                .padding(.top)

            if workplaceManager.workplaces.isEmpty {
                emptyStateView
            } else {
                listView
            }
        }
        .navigationTitle("Workplaces")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    workplaceToEdit = nil
                    isShowingEntryView = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            }
        }
        .sheet(isPresented: $isShowingEntryView) {
            WorkplaceEntryView(workplaceToEdit: workplaceToEdit)
                .environmentObject(subscriptionManager)
        }
        .sheet(item: $workplaceManager.presentingReflectionSheetForCheckIn) { (checkInToReflectOn: Fathom.WorkplaceCheckIn) in
            WorkSessionReflectionView(checkIn: checkInToReflectOn)
                .environment(\.managedObjectContext, workplaceManager.viewContextForSheet())
        }
        .onAppear {
            // Ensure the list is fresh when the view appears
            Task {
                await workplaceManager.loadWorkplaces()
            }
        }
    }
    
    // MARK: - Component Views
    
    /// The main list of workplaces.
    private var listView: some View {
        List {
            ForEach(workplaceManager.workplaces) { workplace in
                WorkplaceRow(workplace: workplace)
                    .contentShape(Rectangle()) // Make the whole row tappable
                    .onTapGesture {
                        workplaceToEdit = workplace
                        isShowingEntryView = true
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        checkInButton(for: workplace)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        deleteButton(for: workplace)
                    }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    /// View to display when no workplaces have been added yet.
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "building.2.crop.circle")
                .font(.system(size: 80))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No Workplaces Yet")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Tap the + button to add your first workplace and start tracking your time.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            Spacer()
        }
        .padding()
        .frame(maxWidth: 500)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Helper for Sheet Context
    // This is a bit of a workaround if WorkplaceManager's viewContext isn't directly accessible
    // or if you want to ensure the sheet uses the same context instance.
    // If WorkplaceManager.viewContext is public, you can use it directly.
    // For now, let's assume we need a way to pass it. We'll add a helper in WorkplaceManager.

    // MARK: - Swipe Actions
    
    /// Swipe action button for checking in or out.
    private func checkInButton(for workplace: Workplace) -> some View {
        Button {
            Task {
                if let activeCheckIn = workplaceManager.activeCheckIn,
                   activeCheckIn.workplace?.objectID == workplace.objectID {
                    await workplaceManager.checkOut()
                } else {
                    await workplaceManager.checkIn(to: workplace)
                }
            }
        } label: {
            if let activeCheckIn = workplaceManager.activeCheckIn, activeCheckIn.workplace?.objectID == workplace.objectID {
                Label("Check Out", systemImage: "arrow.right.square.fill")
            } else {
                Label("Check In", systemImage: "arrow.left.square.fill")
            }
        }
        .tint(workplaceManager.activeCheckIn?.workplace?.objectID == workplace.objectID ? .orange : .green)
    }
    
    /// Swipe action button for deleting a workplace.
    private func deleteButton(for workplace: Workplace) -> some View {
        Button(role: .destructive) {
            Task {
                await workplaceManager.deleteWorkplace(workplace)
            }
        } label: {
            Label("Delete", systemImage: "trash.fill")
        }
    }
}

// MARK: - Workplace Row View

/// A view for a single row in the workplace list.
struct WorkplaceRow: View {
    @ObservedObject var workplace: Workplace
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "building.fill")
                .font(.title)
                .foregroundColor(.white)
                .padding(12)
                .background(
                    Circle().fill(Color.accentColor)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(workplace.nameOrDefault)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text(workplace.addressOrDefault)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text("\(workplace.formattedWorkingHours) / day")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

struct WorkplaceListView_Previews: PreviewProvider {
    static var previews: some View {
        let subManager = SubscriptionManager()
        // Simulate pro user for full feature preview
        subManager.isProUser = true
        
        return WorkplaceListView()
            .environmentObject(subManager)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
