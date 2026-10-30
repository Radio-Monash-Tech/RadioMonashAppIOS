//
//  AppTabView.swift
//  radapp
//
//  Created by Studio on 16/9/2026.
//

import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case live, schedule, journalism, library, search
}

struct AppTabView: View {
    @EnvironmentObject private var player: RadioPlayerModel
    @EnvironmentObject private var schedule: ScheduleStore
    @EnvironmentObject private var journalism: JournalismStore
    @AppStorage(AppearancePreference.storageKey) private var appearance: AppearancePreference = .system
    @AppStorage(ContrastPreference.storageKey) private var increaseContrast = false
    @AppStorage(AccentChoice.storageKey, store: AccentChoice.store) private var accent: AccentChoice = .blue
    @AppStorage(ColourVision.storageKey, store: ColourVision.store) private var colourVision: ColourVision = .standard
    @AppStorage(StoredIDs.followedShowsKey) private var followed = StoredIDs()
    @AppStorage(ShowReminderScheduler.enabledKey) private var showReminders = true
    @AppStorage(TextSizePreference.storageKey) private var textSizeOffset = 0
    @State private var selection: AppTab = .live
    @Environment(\.isLandscapePhone) private var isLandscape
    
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
            // In landscape, iOS pins the other tabs left and a search-role tab
            // right; as an ordinary tab, Search joins one centred bar instead.
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
        .modifier(MiniPlayerAccessory(isEnabled: selection != .live) { selection = .live })
        .preferredColorScheme(appearance.colorScheme)
        .increasedContrast(increaseContrast)
        .textSizeOffset(textSizeOffset)
        .tint(accent.color)
        .environment(\.accentChoice, accent)
        .colourVisionFilter(colourVision)
        .task {
            player.prepareSession()
            async let scheduleLoad: Void = schedule.loadIfNeeded()
            async let articlesLoad: Void = journalism.loadIfNeeded()
            _ = await (scheduleLoad, articlesLoad)
        }
        .task(id: ReminderInputs(shows: schedule.shows, followed: followed.rawValue, isEnabled: showReminders)) {
            await ShowReminderScheduler.sync(shows: schedule.shows, followed: followed, isEnabled: showReminders)
            // The widget lists upcoming shows and which are followed.
            player.refreshSystemPlayers()
        }
    }

    private var tabContent: TabContent {
        TabContent(accent: accent.color, showsMiniPlayer: selection != .live) { selection = .live }
    }
}

// What every tab's screen needs. On iOS 26 the TabView's tint only colours
// the tab bar, not the screens inside it, so each tab is tinted again here.
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

// Everything the reminder schedule depends on; a change to any of them reschedules.
private struct ReminderInputs: Equatable {
    let shows: [ScheduledShow]
    let followed: String
    let isEnabled: Bool
}

private struct MiniPlayerAccessory: ViewModifier {
    let isEnabled: Bool
    let onOpen: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 26.1, *) {
            content.tabViewBottomAccessory(isEnabled: isEnabled) {
                MiniPlayer(onOpen: onOpen)
            }
        } else if #available(iOS 26, *) {
            content.tabViewBottomAccessory {
                MiniPlayer(onOpen: onOpen)
            }
        } else {
            content
        }
    }
}

// Before iOS 26 there's no tab bar accessory, so each tab pins the mini player just above the tab bar.
private struct LegacyMiniPlayerInset: ViewModifier {
    let isEnabled: Bool
    let onOpen: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
        } else {
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

#Preview {
    AppTabView()
        .environmentObject(RadioPlayerModel())
        .environmentObject(ScheduleStore())
        .environmentObject(JournalismStore())
        .modelContainer(for: [FavouriteTrack.self, SavedArticle.self], inMemory: true)
}
