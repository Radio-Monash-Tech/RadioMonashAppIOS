//
//  AppTabView.swift
//  radapp
//
//  Created by Studio on 16/9/2026.
//

import SwiftUI

enum AppTab: Hashable {
    case live, schedule, journalism, library, search
}

/// Root of the app: the system tab bar, one independent `NavigationStack`
/// per tab, and the docked mini player in the tab bar's accessory slot.
struct AppTabView: View {
    @EnvironmentObject private var player: RadioPlayerModel
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
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            MiniPlayer { selection = .live }
        }
        .preferredColorScheme(appearance.colorScheme)
        .task { player.prepareSession() }
    }
}

#Preview {
    AppTabView()
        .environmentObject(RadioPlayerModel())
}
