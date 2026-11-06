import SwiftUI

// the privacy policy: what's kept, where it lives and who the app talks to
struct PrivacyView: View {
    var body: some View {
        List {
            Section {
                Text("Radapp has no accounts, ads, analytics or tracking. Nothing you do in the app is sent to Radio Monash or anyone else.")
            }

            Section {
                Label("Liked songs and recently played", systemImage: "heart")
                Label("Saved and downloaded articles", systemImage: "bookmark")
                Label("Listening statistics", systemImage: "chart.bar")
                Label("Followed shows and your settings", systemImage: "gearshape")
                Label("Cached cover art", systemImage: "photo")
            } header: {
                Text("Stored on this device")
            } footer: {
                Text("This stays on your iPhone and is removed when you delete the app. Cached artwork can be cleared in Settings.")
            }

            Section {
                Text("Live captions are made on this iPhone from the stream's audio. The app doesn't use the microphone.")
                Text("Show reminders are local notifications, scheduled on this iPhone.")
            } header: {
                Text("On-device features")
            }

            Section {
                LabeledContent("Radiocult", value: "Stream, now playing and schedule")
                LabeledContent("radiomonash.online", value: "Journalism articles")
                LabeledContent("Apple iTunes Search", value: "Finding a song to share or play elsewhere")
                LabeledContent("Songlink", value: "Opened when you share a song or pick a service")
            } header: {
                Text("Services the app connects to")
            } footer: {
                Text("These only receive what's needed to load content, such as a song name. Each has its own privacy policy.")
            }

            Section("Contact") {
                Link("info@radiomonash.online", destination: URL(string: "mailto:info@radiomonash.online")!)
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Previews

// #Preview macro, shows this view in Xcode's canvas
#Preview {
    NavigationStack {
        PrivacyView()
    }
}
