import SwiftUI

struct ProfileProFeatureRow: View {
    let icon: String
    let text: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(isActive ? .green : .gray)
                .frame(width: 20, height: 20)
            Text(text)
                .font(.subheadline)
                .foregroundColor(isActive ? .primary : .secondary)
            Spacer()
        }
    }
}
