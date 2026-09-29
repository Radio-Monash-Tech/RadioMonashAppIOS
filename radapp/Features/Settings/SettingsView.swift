import SwiftUI

struct SettingsView: View {
    @AppStorage(AppearancePreference.storageKey) private var appearance: AppearancePreference = .system
    @AppStorage("sleepTimerMinutes") private var sleepTimerMinutes = 0
    @AppStorage("resumeOnLaunch") private var resumeOnLaunch = true
    @AppStorage(LiveActivityController.enabledKey) private var liveActivityEnabled = true
    @AppStorage(ShowReminderScheduler.enabledKey) private var showReminders = true
    @AppStorage("newArticleAlerts") private var newArticleAlerts = false

    @EnvironmentObject private var player: RadioPlayerModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var cacheBytes = URLCache.shared.currentDiskUsage

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppearancePreference.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            } header: {
                Text("Appearance")
            } footer: {
                if appearance == .system {
                    Text("Following iOS appearance,  currently \(colorScheme == .dark ? "dark" : "light").")
                }
            }

            Section("Playback") {
                Picker("Sleep Timer", selection: $sleepTimerMinutes) {
                    Text("Off").tag(0)
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                    Text("1 hour").tag(60)
                }
                LabeledContent("Stream Quality", value: "128 kbps AAC")
                Toggle(isOn: $resumeOnLaunch) {
                    Text("Resume on Launch")
                    Text("Start the stream when the app opens")
                }
                Toggle(isOn: $liveActivityEnabled) {
                    Text("Live Activity")
                    Text("Show now playing on the Lock Screen")
                }
                .onChange(of: liveActivityEnabled) { player.refreshLiveActivity() }
            }

            Section("Notifications") {
                Toggle(isOn: $showReminders) {
                    Text("Show Reminders")
                    Text("10 minutes before a followed show")
                }
                Toggle("New Articles", isOn: $newArticleAlerts)
            }

            Section("Storage") {
                LabeledContent("Offline Cache",
                               value: cacheBytes.formatted(.byteCount(style: .file)))
                Button("Clear Cached Artwork", role: .destructive) {
                    URLCache.shared.removeAllCachedResponses()
                    ArtworkCache.shared.removeAll()
                    cacheBytes = URLCache.shared.currentDiskUsage
                }
            }

            Section {
            } footer: {
                VStack(spacing: 2) {
                    Text("RADIO MONASH").font(.caption.weight(.semibold)).kerning(1.5)
                    Text("Version \(version) · Radio Monash, Clayton")
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environmentObject(RadioPlayerModel())
}
