import SwiftUI
import SwiftData


// MARK: - Tabs

// hashable lets swiftui compare values and see which tab is selected
enum AppTab: Hashable {
    case live, schedule, journalism, library, search
}

// MARK: - Main screen

// the main screen: tab bar, the five tabs and the mini player
struct AppTabView: View {
    // MARK: - Shared stores

    // shared stores injected by RadappApp
    @EnvironmentObject private var player: RadioPlayerModel
    @EnvironmentObject private var schedule: ScheduleStore
    @EnvironmentObject private var journalism: JournalismStore
    
    // MARK: - Saved settings

    // read and write UserDefaults
    @AppStorage(AppearancePreference.storageKey) private var appearance: AppearancePreference = .system
    @AppStorage(ContrastPreference.storageKey) private var increaseContrast = false
    @AppStorage(AccentChoice.storageKey, store: AccentChoice.store) private var accent: AccentChoice = .blue
    @AppStorage(ColourVision.storageKey, store: ColourVision.store) private var colourVision: ColourVision = .standard
    @AppStorage(StoredIDs.followedShowsKey) private var followed = StoredIDs()
    @AppStorage(ShowReminderScheduler.enabledKey) private var showReminders = true
    @AppStorage(TextSizePreference.storageKey) private var textSizeOffset = 0

    // MARK: - View state

    // which tab is open, always starts on live
    @State private var selection: AppTab = .live

    // true when a phone is turned sideways
    @Environment(\.isLandscapePhone) private var isLandscape
    
    // MARK: - Body

    // increase or adjust system-wide
    var body: some View {
        TabView(selection: $selection) {
            Tab("Live", systemImage: "dot.radiowaves.left.and.right", value: .live) {
                LiveRadioView().modifier(tabContent)
            }
            Tab("Schedule", systemImage: "calendar", value: .schedule) {
                ScheduleView().modifier(tabContent)
            }
            Tab("Journalism", systemImage: "newspaper", value: .journalism) {
                JournalismView().modifier(tabContent)
            }
            Tab("Library", systemImage: "books.vertical", value: .library) {
                LibraryView().modifier(tabContent)
            }
            
            // In landscape, iOS pins the other tabs left and a search-role tab right
            if isLandscape {
                Tab("Search", systemImage: "magnifyingglass", value: .search) {
                    SearchView().modifier(tabContent)
                }
            } else {
                Tab(value: .search, role: .search) {
                    SearchView().modifier(tabContent)
                }
            }
        }
        // mini player above the tab bar, hidden on the live tab
        .modifier(MiniPlayerAccessory(isEnabled: selection != .live) {
            selection = .live
        })
        
        // dark or light mode
        .preferredColorScheme(appearance.colorScheme)
        
        // contrast
        .increasedContrast(increaseContrast)
        .textSizeOffset(textSizeOffset)
        
        // set the color theme
        .tint(accent.color)
        .environment(\.accentChoice, accent)
        
        // applies color filter to the whole app
        .colourVisionFilter(colourVision)
        
        // run async code when the view appears, cancel if the view disappears
        .task {
            player.prepareSession()
            async let scheduleLoad: Void = schedule.loadIfNeeded()
            async let articlesLoad: Void = journalism.loadIfNeeded()
            _ = await (scheduleLoad, articlesLoad)
        }
        
        // runs when the id has been chanaged
        .task(id: ReminderInputs(shows:
                                    schedule.shows,
                                 followed:
                                    followed.rawValue,
                                 isEnabled:
                                    showReminders)
        ) {
            await ShowReminderScheduler.sync(shows: schedule.shows, followed: followed, isEnabled: showReminders)
            // The widget lists upcoming shows and which are followed.
            player.refreshSystemPlayers()
        }
    }

    // MARK: - Helpers

    // the same styling for every tab
    private var tabContent: TabContent {
        TabContent(accent: accent.color, showsMiniPlayer: selection != .live) {
            selection = .live
        }
    }
}

// MARK: - Tab tint

// On iOS 26 the TabView's tint only colours the tab bar, so each tab is tinted again here.
private struct TabContent: ViewModifier {
    let accent: Color
    let showsMiniPlayer: Bool
    let onOpenPlayer: () -> Void

    func body(content: Content) -> some View {
        content
            .modifier(LegacyMiniPlayerInset(isEnabled: showsMiniPlayer, onOpen: onOpenPlayer))
            .tint(accent)
    }
}

// MARK: - Reminder inputs

// everything the reminder schedule depends on; a change to any of them reschedules.
// equatable being used to compare the old and the new value of the id
private struct ReminderInputs: Equatable {
    let shows: [ScheduledShow]
    let followed: String
    let isEnabled: Bool
}

// MARK: - Mini player, iOS 26

// mini player for ios 26 and later
private struct MiniPlayerAccessory: ViewModifier {
    let isEnabled: Bool
    let onOpen: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 26.1, *) {
            // 26.1 can hide the accessory
            content.tabViewBottomAccessory(isEnabled: isEnabled) {
                MiniPlayer(onOpen: onOpen)
            }
        } else if #available(iOS 26, *) {
            // 26.0 always shows it
            content.tabViewBottomAccessory {
                MiniPlayer(onOpen: onOpen)
            }
        } else {
            content
        }
    }
}

// MARK: - Mini player, before iOS 26

// before iOS 26 there's no tab bar accessory, so each tab pins the mini player just above the tab bar.
private struct LegacyMiniPlayerInset: ViewModifier {
    let isEnabled: Bool
    let onOpen: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
        } else {
            // pins to the bottom and shrinks the scroll area so nothing hides behind it
            content.safeAreaInset(edge: .bottom, spacing: 0) {
                if isEnabled {
                    MiniPlayer(onOpen: onOpen)
                        .frame(height: 56)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 6)
                }
            }
        }
    }
}

// MARK: - Preview

// xcode canvas only, uses an in-memory database
#Preview {
    AppTabView()
        .environmentObject(RadioPlayerModel())
        .environmentObject(ScheduleStore())
        .environmentObject(JournalismStore())
        .modelContainer(for: [FavouriteTrack.self, SavedArticle.self], inMemory: true)
}
