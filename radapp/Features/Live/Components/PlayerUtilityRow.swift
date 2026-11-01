import AVKit
import SwiftUI

// captions, airplay and recently played, under the play button
struct PlayerUtilityRow: View {
    let captionsOn: Bool
    // false where captions can't run; the button stays and explains why
    let captionsAvailable: Bool
    let showingRecent: Bool
    let onCaptions: () -> Void
    let onRecent: () -> Void

    var body: some View {
        HStack {
            Button(action: onCaptions) {
                icon(captionsOn ? "quote.bubble.fill" : "quote.bubble", isOn: captionsOn)
            }
            .opacity(captionsAvailable ? 1 : 0.4)
            .accessibilityLabel("Live Captions")
            .accessibilityValue(captionsOn ? "On" : "Off")
            .sensoryFeedback(.selection, trigger: captionsOn)

            Spacer()

            AirPlayButton()
                .frame(width: 44, height: 44)
                .accessibilityLabel("AirPlay")

            Spacer()

            Button(action: onRecent) {
                icon("list.bullet", isOn: showingRecent)
            }
            .accessibilityLabel("Recently Played")
        }
        .padding(.horizontal, 26)
        .buttonStyle(.plain)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private func icon(_ name: String, isOn: Bool) -> some View {
        UtilityIcon(name: name, isOn: isOn)
    }
}

// a round icon, filled with the accent colour when on
private struct UtilityIcon: View {
    let name: String
    let isOn: Bool
    @Environment(\.accentChoice) private var accent

    var body: some View {
        Image(systemName: name)
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(isOn ? accent.onColor : Color.secondary)
            .frame(width: 44, height: 44)
            .background(isOn ? accent.color : .clear, in: Circle())
            .contentShape(Circle())
    }
}

// the system airplay picker, for speakers, cars and tvs
struct AirPlayButton: UIViewRepresentable {
    @Environment(\.accentChoice) private var accent

    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.prioritizesVideoDevices = false
        return picker
    }

    func updateUIView(_ picker: AVRoutePickerView, context: Context) {
        picker.tintColor = .secondaryLabel
        picker.activeTintColor = UIColor(accent.color)
    }
}
