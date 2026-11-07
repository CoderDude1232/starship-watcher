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

    init() {
        let largeTitle = UIFont.systemFont(ofSize: 28, weight: .light)
        let inlineTitle = UIFont.systemFont(ofSize: 15, weight: .regular)
        UINavigationBar.appearance().largeTitleTextAttributes = [.font: largeTitle, .kern: 4]
        UINavigationBar.appearance().titleTextAttributes = [.font: inlineTitle, .kern: 2]
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Dark-only: system chrome must stay light on black.
                .preferredColorScheme(.dark)
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
