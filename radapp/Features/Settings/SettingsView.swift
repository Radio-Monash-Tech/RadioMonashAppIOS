import SwiftUI
import UIKit

struct SettingsView: View {
    @AppStorage(AppearancePreference.storageKey) private var appearance: AppearancePreference = .system
    @AppStorage(RadioPlayerModel.resumeOnLaunchKey) private var resumeOnLaunch = false
    @AppStorage(LiveActivityController.enabledKey) private var liveActivityEnabled = true
    @AppStorage(ShowReminderScheduler.enabledKey) private var showReminders = true
    @AppStorage("newArticleAlerts") private var newArticleAlerts = false
    @AppStorage(AccentChoice.storageKey, store: AccentChoice.store) private var accent: AccentChoice = .blue
    @AppStorage(ContrastPreference.storageKey) private var increaseContrast = false
    @AppStorage(TextSizePreference.storageKey) private var textSizeOffset = 0

    @EnvironmentObject private var player: RadioPlayerModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
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

            Section("Customization") {
                Picker(selection: $accent) {
                    ForEach(AccentChoice.allCases) { choice in
                        Label {
                            Text(choice.label)
                        } icon: {
                            Swatch(color: choice.uiColor)
                        }
                        .tag(choice)
                    }
                } label: {
                    Text("Colour")
                    Text("Accent used across the app")
                }
                .pickerStyle(.menu)
                .onChange(of: accent) { player.refreshLiveActivity() }
            }

            Section {
                
                // inreament and decreament button
                Stepper(value: $textSizeOffset, in: TextSizePreference.range) {
                    Text("Text Size")
                    Text(TTextSizePreference.label(for: textSizeOffset))
                }
                Toggle(isOn: $increaseContrast) {
                    Text("Increase Contrast")
                    Text("Darker text, stronger colours and solid backgrounds")
                }
            } header: {
                Text("Accessibility")
            } footer: {
                if !increaseContrast && contrast == .increased {
                    Text("Already on because Increase Contrast is turned on in iOS Settings.")
                }
            }

            Section("Playback") {
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

/// Menus draw SF Symbols as templates, so the colour is baked into the image.
private struct Swatch: View {
    let color: UIColor

    var body: some View {
        if let image = UIImage(systemName: "circle.fill")?.withTintColor(color, renderingMode: .alwaysOriginal) {
            Image(uiImage: image)
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .environmentObject(RadioPlayerModel())
}
