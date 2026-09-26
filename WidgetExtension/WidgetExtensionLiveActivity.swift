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
                        Text(context.attributes.vehicle)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
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

private struct MissionCountdownText: View {
    let targetDate: Date?
    let size: CGFloat

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            Text(formattedCountdown(now: timeline.date))
                .font(.system(size: size, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
    }

    private func formattedCountdown(now: Date) -> String {
        guard let targetDate else { return "TBD" }
        let interval = targetDate.timeIntervalSince(now)
        let sign = interval >= 0 ? "T-" : "T+"
        let remaining = abs(Int(interval))
        let days = remaining / 86400
        let hours = remaining / 3600 % 24
        let minutes = remaining / 60 % 60
        let seconds = remaining % 60
        if days >= 10 {
            return String(format: "%@%dD %02dH", sign, days, hours)
        }
        if days > 0 {
            return String(format: "%@%dD %02d:%02d:%02d", sign, days, hours, minutes, seconds)
        }
        return String(format: "%@%02d:%02d:%02d", sign, hours, minutes, seconds)
    }
}

private struct CompactCountdown: View {
    let targetDate: Date?

    var body: some View {
        Text(shortText)
            .font(.caption.weight(.black).monospacedDigit())
            .foregroundStyle(.white)
            .frame(maxWidth: 42, alignment: .trailing)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }

    private var shortText: String {
        guard let targetDate else { return "TBD" }
        let remaining = max(0, Int(targetDate.timeIntervalSince(.now)))
        let days = remaining / 86400
        let hours = remaining / 3600 % 24
        let minutes = remaining / 60 % 60
        if days > 0 {
            return "\(days)d"
        }
        if hours > 0 {
            return "\(hours)h"
        }
        return "\(minutes)m"
    }
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
