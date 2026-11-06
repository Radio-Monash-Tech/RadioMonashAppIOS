import SwiftUI

// about radio monash: intro, features, contact and acknowledgement
struct AboutView: View {
    // MARK: - State and content

    // @Environment property wrapper, reads a value SwiftUI passes down
    @Environment(\.openURL) private var openURL
    // the accent colour picked in settings
    @Environment(\.accentChoice) private var accent

    // each tab and what it does
    private let whatWeDo: [(String, String)] = [
        ("Live", "Stream Radio Monash with live captions for lyrics and hosts"),
        ("Schedule", "See what is on and get a reminder before shows you follow"),
        ("Journalism", "Reviews, features and opinion from student writers"),
        ("Library", "Your liked songs, recently played and listening stats")
    ]

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                VStack(alignment: .leading, spacing: 0) {
                    intro
                    sectionHeader("What's in Radapp")
                    whatWeDoList
                    sectionHeader("Contact")
                    contactCard
                    acknowledgement.padding(.top, 26)
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .ignoresSafeArea(edges: .top)
        // follows light or dark mode
        .background(Color(.systemGroupedBackground))
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: - Sections

    // the station logo fading into the background
    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Image("StationLogo")
                .resizable()
                .scaledToFill()
                .frame(height: 330)
                .frame(maxWidth: .infinity)
                .clipped()
                .background(Color(.tertiarySystemFill))
                .accessibilityHidden(true)
            LinearGradient(stops: [
                .init(color: .black.opacity(0.35), location: 0),
                .init(color: .clear, location: 0.3),
                .init(color: Color(.systemGroupedBackground).opacity(0.6), location: 0.7),
                .init(color: Color(.systemGroupedBackground), location: 1)
            ], startPoint: .top, endPoint: .bottom)
        }
        .frame(height: 330)
    }

    // the badge, title, description and website button
    private var intro: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SINCE 1972")
                .font(.caption2.weight(.bold))
                .kerning(1)
                .foregroundStyle(accent.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(accent.color.opacity(0.18), in: Capsule())
                .overlay(Capsule().stroke(accent.color.opacity(0.5), lineWidth: 1))

            Text("About Radapp")
                .font(.largeTitle.bold())
                .padding(.top, 10)

            Text("The official app of Radio Monash, independent student radio from the Clayton campus of Monash University.")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            Text("Radapp puts the station in your pocket. Listen live, follow the shows you love and read the latest from our Journalism Director, wherever you are. Radio Monash has been on air in various guises since 1972, championing the Melbourne music scene and the students who make it.")
                .font(.callout)
                .foregroundStyle(.primary.opacity(0.85))
                .lineSpacing(3)
                .padding(.top, 20)

            Link(destination: URL(string: "https://www.radiomonash.online")!) {
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                    Text("Visit radiomonash.online")
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
            .padding(.top, 18)
            .accessibilityHint("Opens in Safari")
        }
        // pulled up over the hero's fade
        .padding(.top, -98)
    }

    // a pink dot, the tab name and what it does; not tappable
    private var whatWeDoList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(whatWeDo, id: \.0) { title, detail in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Circle()
                        .fill(accent.color)
                        .frame(width: 6, height: 6)
                        // sits level with the text
                        .alignmentGuide(.firstTextBaseline) { dimensions in
                            dimensions[.bottom] + 4
                        }
                    (Text(title).fontWeight(.semibold).foregroundStyle(.primary)
                     + Text(" : " + detail).foregroundStyle(.primary.opacity(0.85)))
                        .font(.callout)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, 2)
    }

    private var contactCard: some View {
        VStack(spacing: 0) {
            contactRow("Email", "info@radiomonash.online", "mailto:info@radiomonash.online")
            Divider().padding(.leading, 14)
            contactRow("Phone", "9905 8257", "tel:0399058257")
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // tapping opens mail or the phone app
    private func contactRow(_ label: String, _ value: String, _ link: String) -> some View {
        Button {
            openURL(URL(string: link)!)
        } label: {
            HStack {
                Text(label).foregroundStyle(.primary)
                Spacer()
                Text(value).foregroundStyle(accent.color)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
        }
    }

    private var acknowledgement: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Acknowledgement of Country").font(.subheadline.weight(.semibold))
            Text("Radio Monash recognises the stolen land of the peoples of the Kulin Nation, where our studios are located and we conduct our activities. We pay our respects to Elders past, present and emerging. Sovereignty was never ceded.")
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.8))
                .lineSpacing(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var footer: some View {
        Text("Radapp \(appVersion) · Made by Radio Monash\nRadio Monash Inc. · ABN 86 692 750 357")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 22)
    }

    // MARK: - Helpers

    // e.g. "1.0", from the app's info.plist
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 26)
            .padding(.bottom, 8)
            .padding(.leading, 2)
    }
}

// MARK: - Previews

// #Preview macro, shows this view in Xcode's canvas
#Preview("Dark") {
    NavigationStack {
        AboutView()
    }
    .preferredColorScheme(.dark)
}

#Preview("Light") {
    NavigationStack {
        AboutView()
    }
    .preferredColorScheme(.light)
}
