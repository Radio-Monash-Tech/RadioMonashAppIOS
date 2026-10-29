import SwiftUI

/// Sits above a list that's showing its saved copy because the download failed.
struct OfflineNote: View {
    let savedAt: Date

    var body: some View {
        Label {
            Text("Offline · Updated \(savedAt, format: .relative(presentation: .named))")
        } icon: {
            Image(systemName: "wifi.slash")
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .accessibilityLabel(Text("Offline. Showing what was saved \(savedAt, format: .relative(presentation: .named))"))
    }
}

#Preview {
    OfflineNote(savedAt: .now.addingTimeInterval(-3 * 3600))
}
