import SwiftUI

/// 512pt station artwork with the monogram placeholder used in the mockups.
struct ArtworkView: View {
    let url: URL?
    let side: CGFloat
    let corner: CGFloat

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                ZStack {
                    Brand.artworkFill
                    Text("RM")
                        .font(.system(size: side * 0.15, weight: .heavy))
                        .foregroundStyle(Brand.tertiaryText)
                }
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}

/// Circular secondary control. Always at least 44×44 pt.
struct CircleButton<Label: View>: View {
    let size: CGFloat
    var tinted: Bool = false
    let action: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(tinted ? Brand.accent.opacity(0.18) : Brand.glass)
                label
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(tinted ? Brand.accent : Brand.primaryText)
            }
            .frame(width: max(44, size), height: max(44, size))
        }
        .buttonStyle(.plain)
    }
}

struct PulsingDot: View {
    @State private var on = false

    var body: some View {
        Circle()
            .frame(width: 6, height: 6)
            .opacity(on ? 0.35 : 1)
            .animation(
                .easeInOut(duration: 0.95).repeatForever(autoreverses: true),
                value: on
            )
            .onAppear { on = true }
            .accessibilityHidden(true)
    }
}
