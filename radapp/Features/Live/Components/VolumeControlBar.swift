import SwiftUI
import AVFoundation
import MediaPlayer

struct VolumeControlBar: View {
    @State private var isMuted: Bool
    @State private var systemVolume = AVAudioSession.sharedInstance().outputVolume
    private let onMuteChange: (Bool) -> Void

    init(isMuted: Bool, onMuteChange: @escaping (Bool) -> Void) {
        _isMuted = State(initialValue: isMuted)
        self.onMuteChange = onMuteChange
    }

    private var isSilent: Bool { isMuted || systemVolume == 0 }

    var body: some View {
        HStack(spacing: 16) {
            Button {
                isMuted.toggle()
            } label: {
                Image(systemName: isSilent ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .foregroundStyle(.primary)
                    .frame(width: 48, height: 48)
                    .background(.fill.tertiary, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isMuted ? "Unmute" : "Mute")

            // Drives the device's system volume, so it stays in sync with the hardware buttons.
            SystemVolumeSlider()
                .frame(height: 34)
                .opacity(isMuted ? 0.4 : 1)
                .accessibilityLabel("Volume")
        }
        .onChange(of: isMuted) { _, newValue in onMuteChange(newValue) }
        .onReceive(AVAudioSession.sharedInstance().publisher(for: \.outputVolume)) { systemVolume = $0 }
    }
}

#if targetEnvironment(simulator)
/// `MPVolumeView` draws nothing in the Simulator, which has no device volume
/// to control, so the Simulator gets a plain slider for the stream's volume.
private struct SystemVolumeSlider: View {
    @EnvironmentObject private var player: RadioPlayerModel
    @State private var volume: Float = 1

    var body: some View {
        Slider(value: $volume, in: 0...1)
            .tint(.primary)
            .onAppear { volume = player.volume }
            .onChange(of: volume) { _, newValue in player.volume = newValue }
    }
}
#else
private struct SystemVolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView()
        view.tintColor = .label
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
#endif
