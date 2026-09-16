import SwiftUI

struct PlatformSheet: View {
    let track: NowPlaying
    @Environment(\.dismiss) private var dismiss

    private let platforms: [(String, String)] = [
        ("Spotify", "Opens app"),
        ("Apple Music", "Opens app"),
        ("YouTube Music", "Opens app"),
        ("Bandcamp", "Opens Safari"),
        ("Deezer", "Opens Safari")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(platforms, id: \.0) { name, mode in
                        Button {
                            dismiss()
                        } label: {
                            HStack {
                                Text(name)
                                Spacer()
                                Text(mode)
                                    .font(.footnote)
                                    .foregroundStyle(Brand.tertiaryText)
                            }
                        }
                        .tint(Brand.primaryText)
                    }
                } header: {
                    Text("\(track.title) · \(track.artist) — matched via Song.link (AU)")
                }
            }
            .navigationTitle("Open this track")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}
