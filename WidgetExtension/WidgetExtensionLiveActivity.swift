import ActivityKit
import WidgetKit
import SwiftUI

struct StarshipFlightAttributes: ActivityAttributes, Sendable {
    struct ContentState: Codable, Hashable, Sendable {
        let phase: String
        let status: String
        let targetDate: Date?
        let detail: String
        /// Current mission event ("Hot staging"). Optional so states from older builds still decode.
        var stage: String? = nil
    }

    let flightID: String
    let flightName: String
    let vehicle: String
    let launchSite: String
}

struct WidgetExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StarshipFlightAttributes.self) { context in
            LockScreenActivity(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.shortName)
                        .caps(.caption, tracking: 1.5)
                        .lineLimit(1)
                        .padding(.leading, 8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    StatusText(status: context.state.status)
                        .padding(.trailing, 8)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        ActivityClock(state: context.state, font: .title)
                        StageText(state: context.state)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                }
            } compactLeading: {
                StatusText(status: context.state.status)
            } compactTrailing: {
                CompactCountdown(state: context.state)
            } minimal: {
                StatusText(status: context.state.status)
                    .minimumScaleFactor(0.5)
            }
            .widgetURL(URL(string: "starshipwatcher://flight/\(context.attributes.flightID)"))
            .keylineTint(Color.white.opacity(0.55))
        }
    }
}

struct LockScreenActivity: View {
    let attributes: StarshipFlightAttributes
    let state: StarshipFlightAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(attributes.shortName)
                    .caps(.footnote, tracking: 2)
                    .lineLimit(1)
                Spacer(minLength: 8)
                StatusText(status: state.status)
            }
            ActivityClock(state: state, font: .largeTitle)
            StageText(state: state)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Live Activities are rendered as snapshots, so `TimelineView` never ticks there.
/// `Text(timerInterval:)` / `.timer` are drawn by the system and update every second on their own.
private struct ActivityClock: View {
    let state: StarshipFlightAttributes.ContentState
    let font: Font

    var body: some View {
        Group {
            if let targetDate = state.targetDate {
                if targetDate > .now {
                    Text("T-\(Text(timerInterval: Date.now...targetDate, countsDown: true))")
                } else if LaunchStatus(name: state.status).isHoldOrTBD {
                    Text("Awaiting liftoff")
                } else {
                    // Re-rendered when the activity goes stale at the target date. Unlike the app it runs on
                    // while Go: between background refreshes a frozen clock would look broken mid-flight.
                    Text("T+\(Text(targetDate, style: .timer))")
                }
            } else {
                Text("Date TBD")
            }
        }
        .font(font.weight(.light).monospacedDigit())
        .textCase(.uppercase)
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
}

private struct CompactCountdown: View {
    let state: StarshipFlightAttributes.ContentState

    var body: some View {
        Group {
            if let targetDate = state.targetDate, targetDate > .now {
                if targetDate.timeIntervalSinceNow >= 86400 {
                    Text("\(Int(targetDate.timeIntervalSinceNow / 86400))d")
                } else {
                    Text(timerInterval: Date.now...targetDate, countsDown: true)
                }
            } else if state.targetDate != nil {
                Text(targetDateIsLive ? "LIVE" : "—")
                    .foregroundStyle(targetDateIsLive ? Theme.alert : .white)
            } else {
                Text("—")
            }
        }
        .font(.caption.weight(.light).monospacedDigit())
        .foregroundStyle(.white)
        .multilineTextAlignment(.trailing)
        .frame(maxWidth: 52, alignment: .trailing)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }

    private var targetDateIsLive: Bool {
        let status = LaunchStatus(name: state.status)
        return !status.isHoldOrTBD && !status.isSuccess && !status.isAlert
    }
}

private struct StatusText: View {
    let status: String

    var body: some View {
        let status = LaunchStatus(name: status)
        Text(status.shortName)
            .caps(.caption2, color: status.color, tracking: 1.5)
            .lineLimit(1)
    }
}

private struct StageText: View {
    let state: StarshipFlightAttributes.ContentState

    var body: some View {
        if let stage = state.stage {
            Text(stage)
                .caps(.caption2, color: Theme.secondary, tracking: 1.5)
                .lineLimit(1)
        }
    }
}

extension StarshipFlightAttributes {
    /// "Starship | Flight 15" -> "Flight 15".
    fileprivate var shortName: String {
        guard let range = flightName.range(of: " | ") else { return flightName }
        return String(flightName[range.upperBound...])
    }
}

extension StarshipFlightAttributes {
    fileprivate static var preview: StarshipFlightAttributes {
        StarshipFlightAttributes(
            flightID: "preview",
            flightName: "Starship | Flight 15",
            vehicle: "Starship / Super Heavy",
            launchSite: "Starbase"
        )
    }
}

extension StarshipFlightAttributes.ContentState {
    fileprivate static var countdown: StarshipFlightAttributes.ContentState {
        StarshipFlightAttributes.ContentState(
            phase: "Countdown",
            status: "Go for launch",
            targetDate: Calendar.current.date(byAdding: .day, value: 1, to: .now),
            detail: "Orbital Launch Mount",
            stage: "Engine chill"
        )
    }
}

#Preview("Notification", as: .content, using: StarshipFlightAttributes.preview) {
    WidgetExtensionLiveActivity()
} contentStates: {
    StarshipFlightAttributes.ContentState.countdown
}
