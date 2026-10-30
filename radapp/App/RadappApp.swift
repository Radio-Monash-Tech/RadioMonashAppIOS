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
        // Created now rather than when the first view appears, so a widget
        // button that launches the app in the background reaches it.
        let player = RadioPlayerModel(modelContext: container.mainContext, schedule: schedule)
        _player = StateObject(wrappedValue: player)
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
