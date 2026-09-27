import ActivityKit
import WidgetKit
import SwiftUI

struct StarshipFlightAttributes: ActivityAttributes, Sendable {
    struct ContentState: Codable, Hashable, Sendable {
        let phase: String
        let status: String
        let targetDate: Date?
        let detail: String
    }

    let flightID: String
    let flightName: String
    let vehicle: String
    let launchSite: String
}

struct WidgetExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StarshipFlightAttributes.self) { context in
            ConceptLockScreenActivity(context: context)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    StarshipMark()
                        .frame(width: 34, height: 20)
                        .padding(.leading, 10)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(shortMissionName(context.attributes.flightName))
                            .font(.caption.weight(.black))
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                        Text(flightNumberText(context.attributes.flightName))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.trailing, 10)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(context.attributes.vehicle)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                            Spacer(minLength: 4)
                            StatusPill(status: context.state.status)
                        }
                        MissionCountdownText(targetDate: context.state.targetDate, size: 18)
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                }
            } compactLeading: {
                StarshipMark()
                    .frame(width: 28, height: 16)
            } compactTrailing: {
                CompactCountdown(targetDate: context.state.targetDate)
            } minimal: {
                StarshipMark()
                    .frame(width: 18, height: 12)
            }
            .widgetURL(URL(string: "starshipwatcher://flight/\(context.attributes.flightID)"))
            .keylineTint(Color.white.opacity(0.55))
        }
    }
}

private struct ConceptLockScreenActivity: View {
    let context: ActivityViewContext<StarshipFlightAttributes>

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.08), .white.opacity(0.02), .black.opacity(0.22)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(colors: [.white.opacity(0.28), .clear, .white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )

            VStack(spacing: 10) {
                HStack(alignment: .top) {
                    StatusPill(status: context.state.status)
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(shortMissionName(context.attributes.flightName))
                            .font(.system(.title3, design: .monospaced).weight(.black))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text(flightNumberText(context.attributes.flightName))
                            .font(.system(.callout, design: .monospaced).weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                HStack(alignment: .bottom, spacing: 16) {
                    StarshipMark()
                        .frame(width: 138, height: 58)
                        .padding(.bottom, 3)

                    Spacer(minLength: 6)

                    MissionCountdownText(targetDate: context.state.targetDate, size: 32)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
    }
}

/// Live Activities are rendered as snapshots, so `TimelineView` never ticks there.
/// `Text(timerInterval:)` / `.timer` are drawn by the system and update every second on their own.
private struct MissionCountdownText: View {
    let targetDate: Date?
    let size: CGFloat

    var body: some View {
        Group {
            if let targetDate {
                if targetDate > .now {
                    Text("T-\(Text(timerInterval: Date.now...targetDate, countsDown: true))")
                } else {
                    // Re-rendered when the activity goes stale at the target date.
                    Text("T+\(Text(targetDate, style: .timer))")
                }
            } else {
                Text("TBD")
            }
        }
        .font(.system(size: size, weight: .bold))
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
        .foregroundStyle(.white)
    }
}

private struct CompactCountdown: View {
    let targetDate: Date?

    var body: some View {
        Group {
            if let targetDate, targetDate > .now {
                if targetDate.timeIntervalSinceNow >= 86400 {
                    Text("\(Int(targetDate.timeIntervalSinceNow / 86400))d")
                } else {
                    Text(timerInterval: Date.now...targetDate, countsDown: true)
                }
            } else if targetDate != nil {
                Text("LIVE")
            } else {
                Text("TBD")
            }
        }
        .font(.caption.weight(.black).monospacedDigit())
        .foregroundStyle(.white)
        .multilineTextAlignment(.trailing)
        .frame(maxWidth: 52, alignment: .trailing)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
}

private struct StatusPill: View {
    let status: String

    var body: some View {
        let (label, tint) = launchStatusBadge(status)
        Text(label)
            .font(.caption2.weight(.black))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tint.opacity(0.18), in: Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.45), lineWidth: 1))
    }
}

/// Short label + tint for Launch Library status names ("Go for Launch", "To Be Determined", ...).
/// Shared by the Live Activity and Home Screen widgets.
func launchStatusBadge(_ status: String) -> (String, Color) {
    let value = status.lowercased()
    if value.contains("success") { return ("SUCCESS", .teal) }
    if value.contains("scrub") { return ("SCRUB", .red) }
    if value.contains("fail") { return ("FAILURE", .red) }
    if value.contains("flight") || value.contains("progress") { return ("IN FLIGHT", .blue) }
    if value.contains("hold") { return ("HOLD", .orange) }
    if value.contains("determined") || value.contains("tbd") { return ("TBD", .orange) }
    if value.contains("confirmed") || value.contains("tbc") { return ("TBC", .yellow) }
    if value.contains("go") { return ("GO", .green) }
    return (status.isEmpty ? "—" : status.uppercased(), .gray)
}

private struct StarshipMark: View {
    var body: some View {
        Image("SpaceXMark")
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)
    }
}

private func shortMissionName(_ name: String) -> String {
    if name.localizedCaseInsensitiveContains("starship") {
        return "StarShip"
    }
    return name
}

private func flightNumberText(_ name: String) -> String {
    if let range = name.range(of: #"Flight\s*\d+"#, options: [.regularExpression, .caseInsensitive]) {
        let match = String(name[range])
        return match.prefix(1).uppercased() + match.dropFirst()
    }
    return "Flight"
}

extension StarshipFlightAttributes {
    fileprivate static var preview: StarshipFlightAttributes {
        StarshipFlightAttributes(
            flightID: "preview",
            flightName: "Starship Flight 13",
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
            detail: "Orbital Launch Mount"
        )
    }
}

#Preview("Notification", as: .content, using: StarshipFlightAttributes.preview) {
    WidgetExtensionLiveActivity()
} contentStates: {
    StarshipFlightAttributes.ContentState.countdown
}
