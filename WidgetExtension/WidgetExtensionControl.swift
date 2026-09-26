//
//  WidgetExtensionControl.swift
//  WidgetExtension
//
//  Created by Ethan Daly on 22/7/2026.
//

import AppIntents
import SwiftUI
import WidgetKit

/// Control Center / Lock Screen / Action button control that pins the launch countdown.
struct WidgetExtensionControl: ControlWidget {
    static let kind: String = "com.morgandaly.Starship-Watcher.WidgetExtension"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: StartLaunchCountdownIntent()) {
                Label("Launch Countdown", systemImage: "timer")
            }
        }
        .displayName("Launch Countdown")
        .description("Pin the next Starship launch countdown to the Lock Screen.")
    }
}
