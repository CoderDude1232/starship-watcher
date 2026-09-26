//
//  WidgetExtensionBundle.swift
//  WidgetExtension
//
//  Created by Ethan Daly on 22/7/2026.
//

import WidgetKit
import SwiftUI

@main
struct WidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        WidgetExtension()
        WidgetExtensionControl()
        WidgetExtensionLiveActivity()
    }
}
