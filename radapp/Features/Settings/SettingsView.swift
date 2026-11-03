import SwiftUI
import UIKit

// MARK: - Settings view

// every setting, grouped into sections
struct SettingsView: View {
    // MARK: - Saved settings

    // @AppStorage property wrapper, saved in UserDefaults and redraws when it changes
    @AppStorage(AppearancePreference.storageKey) private var appearance: AppearancePreference = .system
    @AppStorage(RadioPlayerModel.resumeOnLaunchKey) private var resumeOnLaunch = false
    @AppStorage(ShowReminderScheduler.enabledKey) private var showReminders = true
    @AppStorage("newArticleAlerts") private var newArticleAlerts = false
    @AppStorage(AccentChoice.storageKey, store: AccentChoice.store) private var accent: AccentChoice = .blue
    @AppStorage(ContrastPreference.storageKey) private var increaseContrast = false
    @AppStorage(ColourVision.storageKey, store: ColourVision.store) private var colourVision: ColourVision = .standard
    @AppStorage(TextSizePreference.storageKey) private var textSizeOffset = 0

    // MARK: - State

    // @EnvironmentObject property wrapper, reads a shared object passed down from a parent view
    @EnvironmentObject private var player: RadioPlayerModel
    // @Environment property wrapper, reads a value SwiftUI passes down
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    // @State property wrapper, the view owns this value and redraws when it changes
    @State private var cacheBytes = URLCache.shared.currentDiskUsage

    // MARK: - Status text

    // what the live captions row says
    private var captionStatus: String {
        switch player.captions.availability {
        case .checking:
            return "Checking…"
        case .unsupported:
            return "Not Available"
        case .needsDownload:
            return "Not Set Up"
        case .downloading:
            return "Downloading…"
        case .ready:
            if player.captions.isEnabled {
                return "On"
            }
            return "Off"
        }
    }

    // "dark" or "light", for the appearance footer
    private var currentAppearance: String {
        if colorScheme == .dark {
            return "dark"
        }
        return "light"
    }

    // e.g. "1.0 (12)"
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    // MARK: - Body

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppearancePreference.allCases) { preference in
                        Text(preference.label).tag(preference)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                // the widget follows this too
                .onChange(of: appearance) {
                    player.refreshSystemPlayers()
                }
            } header: {
                Text("Appearance")
            } footer: {
                if appearance == .system {
                    Text("Following iOS appearance,  currently \(currentAppearance).")
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
                // the widget uses the accent too
                .onChange(of: accent) {
                    player.refreshSystemPlayers()
                }
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
                                    // menus show the second line as a subtitle
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
                // ios settings already turned it on
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
                NavigationLink("About Radapp") {
                    AboutView()
                }
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

// MARK: - Menu row

// a title, subtitle and dropdown, laid out like the toggle rows
private struct MenuRow<Menu: View>: View {
    let title: String
    let subtitle: String
    // @ViewBuilder lets each branch return a different view
    @ViewBuilder let menu: Menu
    @Environment(\.dynamicTypeSize) private var typeSize

    // init sets up a new instance
    init(_ title: String, subtitle: String, @ViewBuilder menu: () -> Menu) {
        self.title = title
        self.subtitle = subtitle
        self.menu = menu()
    }

    // at the largest text sizes the dropdown goes underneath
    private var layout: AnyLayout {
        if typeSize.isAccessibilitySize {
            return AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
        }
        return AnyLayout(HStackLayout())
    }

    var body: some View {
        layout {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if !typeSize.isAccessibilitySize {
                Spacer(minLength: 8)
            }
            menu
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
        }
    }
}

// MARK: - Colour vision groups

// colour vision picker sections, by which colours get confused
private enum ColourVisionGroup: CaseIterable, Identifiable {
    case standard, redGreen, blueYellow, noColour

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .standard:
            ""
        case .redGreen:
            "Red–green"
        case .blueYellow:
            "Blue–yellow"
        case .noColour:
            "No colour"
        }
    }

    var types: [ColourVision] {
        switch self {
        case .standard:
            [.standard]
        case .redGreen:
            [.protanomaly, .protanopia, .deuteranomaly, .deuteranopia]
        case .blueYellow:
            [.tritanomaly, .tritanopia]
        case .noColour:
            [.monochromacy]
        }
    }
}

// MARK: - Swatch

// a coloured dot; menus tint symbols, so the colour is baked into the image
private struct Swatch: View {
    let color: UIColor

    var body: some View {
        if let image = UIImage(systemName: "circle.fill")?.withTintColor(color, renderingMode: .alwaysOriginal) {
            Image(uiImage: image)
        }
    }
}

// MARK: - Preview

// #Preview macro, shows this view in Xcode's canvas
#Preview {
    NavigationStack {
        SettingsView()
    }
    .environmentObject(RadioPlayerModel())
}
