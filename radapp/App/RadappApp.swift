//
//  RadappApp.swift
//  radapp
//
//  Created by Studio on 16/9/2026.
//

import SwiftUI

@main
struct radappApp: App {
    /// One player for the whole app so the stream survives tab switches and
    /// the mini player and Live tab always show the same state.
    @StateObject private var player = RadioPlayerModel()

    var body: some Scene {
        WindowGroup {
            AppTabView()
                .environmentObject(player)
        }
    }
}
