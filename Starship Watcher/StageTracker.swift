import SwiftUI

/// Live stage of a launch: where it is, how far along, and what comes next.
struct StageTracker: View {
    let flight: StarshipFlight
    let now: Date

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let progress = flight.progress(now: now)
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Stage").caps(color: Theme.secondary)
                Spacer()
                Text("Estimated").caps(.caption2, color: Theme.tertiary, tracking: 1.5)
            }

            Text(progress.title)
                .caps(.title3.weight(.light), color: progress.isAlert ? Theme.alert : .white, tracking: 3)

            PhaseRail(progress: progress, showsLabels: !typeSize.isAccessibilitySize)

            if !progress.upcoming.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(progress.upcoming) { event in
                        UpcomingEventRow(event: event, isPerVehicle: progress.upcoming.count > 1, now: now)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Estimated stage: \(progress.title)")
        .accessibilityValue(progress.upcoming.map { "Next: \($0.title)" }.joined(separator: ". "))
    }
}

/// Equal steps, because preflight alone spans a day. Booster and ship overlap in reality,
/// so the rows below the rail track them side by side.
private struct PhaseRail: View {
    let progress: MissionProgress
    let showsLabels: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            ForEach(FlightPhase.allCases, id: \.self) { phase in
                let fill = progress.fills[phase] ?? 0
                VStack(alignment: .leading, spacing: 6) {
                    Rectangle()
                        .fill(Theme.hairline)
                        .frame(height: 2)
                        .overlay {
                            Rectangle()
                                .fill(progress.isAlert ? Theme.alert : .white)
                                .scaleEffect(x: fill, y: 1, anchor: .leading)
                        }
                    if showsLabels {
                        Text(phase.rawValue)
                            .caps(.caption2, color: fill > 0 ? .white : Theme.tertiary, tracking: 1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct UpcomingEventRow: View {
    let event: FlightEvent
    let isPerVehicle: Bool
    let now: Date

    @ScaledMetric(relativeTo: .caption2) private var labelWidth: CGFloat = 62

    var body: some View {
        AdaptiveRow(spacing: 12) {
            Text(isPerVehicle ? event.phase.rawValue : "Next")
                .caps(.caption2, color: Theme.secondary, tracking: 1.5)
                .frame(minWidth: labelWidth, alignment: .leading)
            Text(title).caps(.caption, tracking: 1)
            Spacer(minLength: 0)
            if let target = event.targetDate, let remaining = Countdown.remaining(to: target, now: now) {
                Text("In \(remaining)")
                    .caps(.caption, color: Theme.secondary, tracking: 1)
                    .monospacedDigit()
            }
        }
    }

    /// "Ship engine cutoff" under a SHIP label reads as "Engine cutoff".
    private var title: String {
        guard isPerVehicle else { return event.title }
        let rest = event.title.replacing("\(event.phase.rawValue) ", with: "")
        return rest.prefix(1).uppercased() + rest.dropFirst()
    }
}

#Preview {
    let flight = StarshipFlight(
        id: "preview", name: "Starship | Flight 15", missionName: "Flight 15", summary: "", vehicle: "Starship",
        status: LaunchStatus(name: "Launch in Flight"), launchDate: .now.addingTimeInterval(-150), windowStart: nil,
        windowEnd: nil, launchSite: "Starbase", padName: "Pad 2", probability: nil, imageURL: nil, webcastLive: true,
        sourceURL: nil
    )
    StageTracker(flight: flight, now: .now)
        .padding(Theme.gutter)
        .background(.black)
}
