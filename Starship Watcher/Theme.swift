import SwiftUI

/// Central design system for Starship Watcher. Keeping spacing, radii, materials,
/// and semantic colors in one place is what lets every screen feel like one app.
enum Theme {
    /// Consistent spacing scale used for stacks and padding across the app.
    enum Spacing {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 18
        static let xl: CGFloat = 22
        static let xxl: CGFloat = 28
    }

    /// Corner-radius scale. Larger surfaces get larger radii for a hierarchy of depth.
    enum Radius {
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 22
        static let hero: CGFloat = 28
    }

    /// Deep-space background gradient shared by every screen and the widget.
    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.02, green: 0.03, blue: 0.06),
            Color(red: 0.07, green: 0.08, blue: 0.12),
            Color(red: 0.01, green: 0.02, blue: 0.03)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Hairline color used for rules and grid dividers — the thing that makes a layout
    /// read as "engineered" rather than a stack of translucent cards.
    static let hairline = Color.white.opacity(0.14)

    /// The app's single accent, used sparingly for the active/live state.
    static let accent = Color(red: 0.42, green: 0.68, blue: 1.0)
}

extension View {
    /// Small caption label used above titles and as field labels. Uses a standard Apple
    /// text style so it never reads as a custom "designed" font.
    func eyebrowStyle(color: Color = .secondary) -> some View {
        self
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
    }
}

/// Semantic launch-status colors. Previously every status rendered white, which made
/// the whole app read as flat; mapping to intent gives instant visual meaning.
enum StatusTint {
    case go
    case caution
    case inFlight
    case success
    case failure
    case neutral

    init(statusName: String) {
        let value = statusName.lowercased()
        switch true {
        case value.contains("go") || value.contains("confirm"):
            self = .go
        case value.contains("success") || value.contains("complete"):
            self = .success
        case value.contains("fail") || value.contains("scrub") || value.contains("abort"):
            self = .failure
        case value.contains("flight") || value.contains("progress") || value.contains("live"):
            self = .inFlight
        case value.contains("hold") || value.contains("tbd") || value.contains("tbc") || value.contains("upcoming"):
            self = .caution
        default:
            self = .neutral
        }
    }

    var color: Color {
        switch self {
        case .go: Color(red: 0.36, green: 0.86, blue: 0.52)
        case .caution: Color(red: 0.98, green: 0.76, blue: 0.30)
        case .inFlight: Color(red: 0.42, green: 0.68, blue: 1.0)
        case .success: Color(red: 0.30, green: 0.82, blue: 0.78)
        case .failure: Color(red: 0.98, green: 0.45, blue: 0.42)
        case .neutral: Color.white.opacity(0.88)
        }
    }
}

extension LaunchStatus {
    var displayName: String {
        name.lowercased() == "go" ? "Go for launch" : name
    }

    var tint: Color {
        StatusTint(statusName: name).color
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

        if days >= 10 {
            return String(format: "%@%dD %02dH", sign, days, hours)
        }
        if days > 0 {
            return compact
                ? String(format: "%@%dD %02d:%02d", sign, days, hours, minutes)
                : String(format: "%@%dD %02d:%02d:%02d", sign, days, hours, minutes, seconds)
        }
        return String(format: "%@%02d:%02d:%02d", sign, hours, minutes, seconds)
    }
}

// MARK: - Glass surface

extension View {
    /// The signature translucent card surface. Uses Liquid Glass on iOS 26+, with a
    /// refined material fallback, plus a soft shadow for depth on every OS.
    @ViewBuilder
    func starshipGlass(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
                .shadow(color: .black.opacity(0.28), radius: 14, x: 0, y: 8)
        } else {
            self
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.28), .white.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: .black.opacity(0.28), radius: 14, x: 0, y: 8)
        }
    }
}
