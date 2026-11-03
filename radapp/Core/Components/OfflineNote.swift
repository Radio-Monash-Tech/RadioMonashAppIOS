import SwiftUI

struct OfflineNote: View {
    // when the saved copy was made
    let savedAt: Date

    var body: some View {
        Label {
            // e.g. "Offline · Updated 3 hours ago"
            Text("Offline · Updated \(savedAt, format: .relative(presentation: .named))")
        } icon: {
            Image(systemName: "wifi.slash")
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(.secondary)
        // full width, content on the left
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        // a clearer sentence for voiceover
        .accessibilityLabel(Text("Offline. Showing what was saved \(savedAt, format: .relative(presentation: .named))"))
    }
}

// saved 3 hours ago
#Preview {
    OfflineNote(savedAt: .now.addingTimeInterval(-3 * 3600))
}
