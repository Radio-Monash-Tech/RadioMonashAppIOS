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

/// Root of the app: the system tab bar, one independent `NavigationStack`
/// per tab, and the docked mini player in the tab bar's accessory slot.
struct AppTabView: View {
    @EnvironmentObject private var player: RadioPlayerModel
    @EnvironmentObject private var schedule: ScheduleStore
    @EnvironmentObject private var journalism: JournalismStore
    @AppStorage(AppearancePreference.storageKey) private var appearance: AppearancePreference = .system
    @State private var selection: AppTab = .live

    var body: some View {
        TabView(selection: $selection) {
            Tab("Live", systemImage: "dot.radiowaves.left.and.right", value: .live) {
                LiveRadioView()
            }
            Tab("Schedule", systemImage: "calendar", value: .schedule) {
                ScheduleView()
            }
            Tab("Journalism", systemImage: "newspaper", value: .journalism) {
                JournalismView()
            }
            Tab("Library", systemImage: "books.vertical", value: .library) {
                LibraryView()
            }
            Tab(value: .search, role: .search) {
                SearchView()
            }
        }
        .modifier(MiniPlayerAccessory(isEnabled: selection != .live) { selection = .live })
        .preferredColorScheme(appearance.colorScheme)
        .task {
            player.prepareSession()
            async let scheduleLoad: Void = schedule.loadIfNeeded()
            async let articlesLoad: Void = journalism.loadIfNeeded()
            _ = await (scheduleLoad, articlesLoad)
        }
    }
}

private struct MiniPlayerAccessory: ViewModifier {
    let isEnabled: Bool
    let onOpen: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 26.1, *) {
            content.tabViewBottomAccessory(isEnabled: isEnabled) {
                MiniPlayer(onOpen: onOpen)
            }
        } else {
            content.tabViewBottomAccessory {
                MiniPlayer(onOpen: onOpen)
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
