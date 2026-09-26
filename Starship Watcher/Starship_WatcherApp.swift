//
//  Starship_WatcherApp.swift
//  Starship Watcher
//
//  Created by Ethan Daly on 22/7/2026.
//

import SwiftUI

@main
struct Starship_WatcherApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                BackgroundRefresh.schedule()
            }
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
            await BackgroundRefresh.run()
        }
    }
}
