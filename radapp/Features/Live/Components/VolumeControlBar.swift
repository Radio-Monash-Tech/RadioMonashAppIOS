import SwiftUI
import AVFoundation
import MediaPlayer

// MARK: - Volume bar

// the mute button and volume slider
struct VolumeControlBar: View {
    // @State property wrapper, the view owns this value and redraws when it changes
    @State private var isMuted: Bool
    @State private var systemVolume = AVAudioSession.sharedInstance().outputVolume
    private let onMuteChange: (Bool) -> Void

    // @escaping means the closure is kept and called later, init sets up a new instance
    init(isMuted: Bool, onMuteChange: @escaping (Bool) -> Void) {
        _isMuted = State(initialValue: isMuted)
        self.onMuteChange = onMuteChange
    }

    // muted, or the phone's volume is at zero
    private var isSilent: Bool {
        isMuted || systemVolume == 0
    }

    var body: some View {
        HStack(spacing: 16) {
            Button {
                isMuted.toggle()
            } label: {
                // fixed size so it never outgrows its 48pt circle
                Image(systemName: isSilent ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(.primary)
                    .frame(width: 48, height: 48)
                    .background(.fill.tertiary, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isMuted ? "Unmute" : "Mute")

            // moves the phone's own volume, in sync with the side buttons
            SystemVolumeSlider()
                .frame(height: 34)
                .opacity(isMuted ? 0.4 : 1)
                .accessibilityLabel("Volume")
        }
        .onChange(of: isMuted) { _, newValue in
            onMuteChange(newValue)
        }
        // follows the side buttons
        .onReceive(AVAudioSession.sharedInstance().publisher(for: \.outputVolume)) { volume in
            systemVolume = volume
        }
    }
}

// MARK: - Volume slider

// #if only compiles this part when the condition is true
#if targetEnvironment(simulator)
// the simulator has no phone volume, so it gets a plain slider for the stream
private struct SystemVolumeSlider: View {
    // @EnvironmentObject property wrapper, reads a shared object passed down from a parent view
    @EnvironmentObject private var player: RadioPlayerModel
    @State private var volume: Float = 1

    var body: some View {
        Slider(value: $volume, in: 0...1)
            .tint(.primary)
            .onAppear {
                volume = player.volume
            }
            .onChange(of: volume) { _, newValue in
                player.volume = newValue
            }
    }
}
#else
// apple's volume slider for the phone's own volume
private struct SystemVolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView()
        view.tintColor = .label
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
#endif
