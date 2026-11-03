import SwiftUI

// one number with a label under it
struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .foregroundStyle(.secondary)
        }
        .statsCard()
        .accessibilityElement(children: .combine)
    }
}
