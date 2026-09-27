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
                // The UI is designed dark-only; in light mode system chrome (large titles,
                // tab bar) rendered black on the dark photo backdrop.
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
