//
//  RadappApp.swift
//  radapp
//
//  Created by Studio on 16/9/2026.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct radappApp: App {
    /// One player for the whole app so the stream survives tab switches and
    /// the mini player and Live tab always show the same state.
    @StateObject private var player: RadioPlayerModel
    @StateObject private var schedule: ScheduleStore
    @StateObject private var journalism = JournalismStore()
    private let container: ModelContainer

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: FavouriteTrack.self, SavedArticle.self, ListeningSegment.self)
        } catch {
            fatalError("Couldn't open the local database: \(error)")
        }
        self.container = container
        let schedule = ScheduleStore()
        _schedule = StateObject(wrappedValue: schedule)
        _player = StateObject(wrappedValue: RadioPlayerModel(modelContext: container.mainContext, schedule: schedule))
        UNUserNotificationCenter.current().delegate = ForegroundNotificationPresenter.shared
    }

    var body: some Scene {
        WindowGroup {
            AppTabView()
                .environmentObject(player)
                .environmentObject(schedule)
                .environmentObject(journalism)
                .modelContainer(container)
        }
    }
}
