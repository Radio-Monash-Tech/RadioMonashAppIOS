import SwiftUI
import UIKit

struct SettingsView: View {
    @AppStorage(AppearancePreference.storageKey) private var appearance: AppearancePreference = .system
    @AppStorage(RadioPlayerModel.resumeOnLaunchKey) private var resumeOnLaunch = false
    @AppStorage(ShowReminderScheduler.enabledKey) private var showReminders = true
    @AppStorage("newArticleAlerts") private var newArticleAlerts = false
    @AppStorage(AccentChoice.storageKey, store: AccentChoice.store) private var accent: AccentChoice = .blue
    @AppStorage(ContrastPreference.storageKey) private var increaseContrast = false
    @AppStorage(ColourVision.storageKey, store: ColourVision.store) private var colourVision: ColourVision = .standard
    @AppStorage(TextSizePreference.storageKey) private var textSizeOffset = 0

    @EnvironmentObject private var player: RadioPlayerModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var cacheBytes = URLCache.shared.currentDiskUsage

    private var captionStatus: String {
        switch player.captions.availability {
        case .checking: "Checking…"
        case .unsupported: "Not Available"
        case .needsDownload: "Not Set Up"
        case .downloading: "Downloading…"
        case .ready: player.captions.isEnabled ? "On" : "Off"
        }
    }

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
                // The Home Screen widget follows this setting too.
                .onChange(of: appearance) { player.refreshSystemPlayers() }
            } header: {
                Text("Appearance")
            } footer: {
                if appearance == .system {
                    Text("Following iOS appearance,  currently \(colorScheme == .dark ? "dark" : "light").")
                }
            }

            Section("Customization") {
                MenuRow("Colour", subtitle: "Accent used across the app") {
                    Picker("Colour", selection: $accent) {
                        ForEach(AccentChoice.allCases) { choice in
                            Label {
                                Text(choice.label)
                            } icon: {
                                Swatch(color: choice.uiColor)
                            }
                            .tag(choice)
                        }
                    }
                }
                .onChange(of: accent) { player.refreshSystemPlayers() }
            }

            Section {
                // inreament and decreament button
                Stepper(value: $textSizeOffset, in: TextSizePreference.range) {
                    Text("Text Size")
                    Text(TextSizePreference.label(for: textSizeOffset))
                }
                Toggle(isOn: $increaseContrast) {
                    Text("Increase Contrast")
                    Text("Darker text, stronger colours and solid backgrounds")
                }
                MenuRow("Colour Vision", subtitle: "Colour filter over the whole app") {
                    Picker(selection: $colourVision) {
                        ForEach(ColourVisionGroup.allCases) { group in
                            Section(group.title) {
                                ForEach(group.types) { type in
                                    // Menus show the second line as a subtitle.
                                    VStack {
                                        Text(type.label)
                                        Text(type.summary)
                                    }
                                    .tag(type)
                                }
                            }
                        }
                    } label: {
                        Text("Colour Vision")
                    } currentValueLabel: {
                        Text(colourVision.label)
                    }
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
            }

            Section {
                LabeledContent("Live Captions", value: captionStatus)
            } header: {
                Text("Live Captions")
            } footer: {
                if case .unsupported(let reason) = player.captions.availability {
                    Text(reason + " The rest of the app works as normal.")
                } else {
                    Text("Turn captions on or off with the CC button on the Live tab. Captions are made on this iPhone")
                }
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
                NavigationLink("About Radio Monash") { AboutView() }
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

/// A setting with a dropdown, laid out like the toggle and stepper rows. A
/// plain menu picker moves its value below the label at larger text sizes.
private struct MenuRow<Menu: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let menu: Menu
    @Environment(\.dynamicTypeSize) private var typeSize

    init(_ title: String, subtitle: String, @ViewBuilder menu: () -> Menu) {
        self.title = title
        self.subtitle = subtitle
        self.menu = menu()
    }

    var body: some View {
        // At accessibility sizes the value would squeeze the title, so it goes underneath.
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout())
        layout {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
            menu
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
        }
    }
}

/// Sections of the Colour Vision picker, by which colours each type confuses.
private enum ColourVisionGroup: CaseIterable, Identifiable {
    case standard, redGreen, blueYellow, noColour

    var id: Self { self }

    var title: String {
        switch self {
        case .standard: ""
        case .redGreen: "Red–green"
        case .blueYellow: "Blue–yellow"
        case .noColour: "No colour"
        }
    }

    var types: [ColourVision] {
        switch self {
        case .standard: [.standard]
        case .redGreen: [.protanomaly, .protanopia, .deuteranomaly, .deuteranopia]
        case .blueYellow: [.tritanomaly, .tritanopia]
        case .noColour: [.monochromacy]
        }
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
