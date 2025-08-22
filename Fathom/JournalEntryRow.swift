import SwiftUI

// A view for a single row in the journal list
struct JournalEntryRow: View {
    let entry: JournalEntry
    
    var body: some View {
        NavigationLink(destination: JournalEntryComposeView(entryToEdit: entry)) {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.text?.split(separator: "\n").first?.trimmingCharacters(in: .whitespaces) ?? "No Title")
                    .font(.headline)
                    .lineLimit(2)
                
                Text(entry.timestamp ?? Date(), style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
            }
            .padding(.vertical, 4)
        }
    }
}
