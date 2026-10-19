import SwiftUI

struct ConnectionQualityBadge: View {
    let connectivity: Connectivity
    @Environment(\.accentChoice) private var accent
    @State private var pulse = false

    private var color: Color {
        switch connectivity {
        case .good: return accent.color
        case .weak: return PlayerPalette.warn
        case .offline: return PlayerPalette.error
        }
    }

    private var text: String {
        switch connectivity {
        case .good: return "LIVE"
        case .weak: return "BUFFERING"
        case .offline: return "OFFLINE"
        }
    }

    private var isLive: Bool { connectivity == .good }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .opacity(isLive ? (pulse ? 1 : 0.5) : 1)
                .frame(width: 8, height: 8)
                .animation(isLive ? .easeInOut(duration: 0.75).repeatForever(autoreverses: true) : .default, value: pulse)
                .onAppear { pulse = true }
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .kerning(0.5)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(color, lineWidth: 1))
        .animation(.easeInOut(duration: 0.3), value: connectivity)
    }
}
