import SwiftUI

/// Design system: white text on pure black, red only for bad news and LIVE.
enum Theme {
    static let gutter: CGFloat = 20
    static let hairline = Color.white.opacity(0.16)
    /// Labels and future events.
    static let secondary = Color.white.opacity(0.6)
    /// Past events and footnotes.
    static let tertiary = Color.white.opacity(0.36)
    /// Scrub, failure and LIVE. Nothing else gets colour.
    static let alert = Color(red: 1.0, green: 0.27, blue: 0.23)
}

extension View {
    /// The app's voice: uppercase, widely tracked, never bold.
    func caps(_ font: Font = .footnote, color: Color = .white, tracking: CGFloat = 2) -> some View {
        self
            .font(font)
            .textCase(.uppercase)
            .tracking(tracking)
            .foregroundStyle(color)
    }
}

extension LaunchStatus {
    var displayName: String {
        switch name.lowercased() {
        case "go": "Go for launch"
        case "tbd": "To be determined"
        case "tbc": "To be confirmed"
        default: name
        }
    }

    /// Any scrub or failure. Holds stay white.
    var isAlert: Bool {
        let value = name.lowercased()
        return value.contains("fail") || value.contains("scrub") || value.contains("abort")
    }

    var color: Color {
        isAlert ? Theme.alert : .white
    }
}

// MARK: - Countdown formatting

enum Countdown {
    /// Shared formatter for the whole app. Counts down (T-) before launch and up (T+)
    /// afterwards so an in-flight mission never freezes at zero.
    static func text(to target: Date?, now: Date, compact: Bool = false) -> String {
        guard let target else { return "TBD" }
        let interval = target.timeIntervalSince(now)
        let sign = interval >= 0 ? "T-" : "T+"
        let remaining = abs(Int(interval))
        let days = remaining / 86_400
        let hours = remaining / 3_600 % 24
        let minutes = remaining / 60 % 60
        let seconds = remaining % 60

        if days > 0 {
            return compact
                ? String(format: "%@%dD %02d:%02d", sign, days, hours, minutes)
                : String(format: "%@%d:%02d:%02d:%02d", sign, days, hours, minutes, seconds)
        }
        return String(format: "%@%02d:%02d:%02d", sign, hours, minutes, seconds)
    }
}
