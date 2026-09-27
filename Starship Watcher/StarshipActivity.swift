import Foundation

#if canImport(ActivityKit)
@preconcurrency import ActivityKit

nonisolated struct StarshipFlightAttributes: ActivityAttributes, Sendable {
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

enum CountdownStartError: Error, CustomLocalizedStringResourceConvertible {
    case activitiesDisabled
    case launchTBD
    case tooEarly

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .activitiesDisabled: "Live Activities are turned off for Starship Watcher in iOS Settings."
        case .launchTBD: "The launch time is TBD."
        case .tooEarly: "The countdown can start from T-8h."
        }
    }
}

struct StarshipActivityController {
    /// iOS ends a Live Activity after 8 hours, so it never starts earlier than this.
    static let maxLead: TimeInterval = 8 * 60 * 60

    /// Activities still on screen (ended/dismissed ones linger in `activities`).
    static var liveActivities: [Activity<StarshipFlightAttributes>] {
        Activity<StarshipFlightAttributes>.activities.filter { $0.activityState == .active || $0.activityState == .stale }
    }

    static var hasLiveActivity: Bool {
        !liveActivities.isEmpty
    }

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "liveActivityEnabled") as? Bool ?? true
    }

    /// Selected lead time, capped at the 8 hour limit.
    static var lead: TimeInterval {
        let hours = UserDefaults.standard.object(forKey: "activityLeadHours") as? Int ?? 6
        return min(TimeInterval(hours * 60 * 60), maxLead)
    }

    static func windowStart(for launchDate: Date) -> Date {
        launchDate.addingTimeInterval(-lead)
    }

    /// Updates a running activity, or starts one once the lead window opens.
    /// `canStart` is false in the background, where ActivityKit won't request new activities.
    func sync(flight: StarshipFlight?, canStart: Bool) async {
        guard let flight else {
            await endAll()
            return
        }

        if let existing = Self.liveActivities.first(where: { $0.attributes.flightID == flight.id }) {
            // Slipped more than 8h out (or started by an older build): hide until the window reopens.
            if let launchDate = flight.launchDate, launchDate.timeIntervalSinceNow > Self.maxLead {
                await endAll()
                return
            }
            // Otherwise keep it through holds and TBD so the status change stays visible.
            await update(existing, for: flight)
            await endAll(except: existing.id)
            return
        }

        await endAll()
        guard canStart, Self.isEnabled, let launchDate = flight.launchDate, Date.now >= Self.windowStart(for: launchDate) else { return }
        try? request(for: flight)
    }

    /// Manual start from the widget button, control or Shortcuts. Ignores the in-app toggle and lead setting.
    func startNow(flight: StarshipFlight) async throws {
        if let existing = Self.liveActivities.first(where: { $0.attributes.flightID == flight.id }) {
            await update(existing, for: flight)
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { throw CountdownStartError.activitiesDisabled }
        guard let launchDate = flight.launchDate else { throw CountdownStartError.launchTBD }
        guard launchDate.timeIntervalSinceNow <= Self.maxLead else { throw CountdownStartError.tooEarly }

        await endAll()
        try request(for: flight)
    }

    private func request(for flight: StarshipFlight) throws {
        let attributes = StarshipFlightAttributes(
            flightID: flight.id,
            flightName: flight.name,
            vehicle: flight.vehicle,
            launchSite: flight.launchSite
        )
        _ = try Activity.request(
            attributes: attributes,
            content: ActivityContent(state: contentState(for: flight), staleDate: flight.launchDate),
            pushType: nil
        )
    }

    func endAll(except keptID: String? = nil) async {
        for activity in Activity<StarshipFlightAttributes>.activities where activity.id != keptID {
            await activity.end(ActivityContent(state: activity.content.state, staleDate: nil), dismissalPolicy: .immediate)
        }
    }

    private func update(_ activity: Activity<StarshipFlightAttributes>, for flight: StarshipFlight) async {
        let old = activity.content.state
        let new = contentState(for: flight)
        guard old != new || activity.activityState == .stale else { return }

        let content = ActivityContent(state: new, staleDate: flight.launchDate)
        if let alert = alert(from: old, to: new, flightName: flight.name) {
            await activity.update(content, alertConfiguration: alert)
        } else {
            await activity.update(content)
        }
    }

    /// Lights up the Lock Screen when the status flips or the launch time moves.
    private func alert(from old: StarshipFlightAttributes.ContentState, to new: StarshipFlightAttributes.ContentState, flightName: String) -> AlertConfiguration? {
        let statusChanged = old.status != new.status
        let timeMoved: Bool = switch (old.targetDate, new.targetDate) {
        case let (oldDate?, newDate?): abs(oldDate.timeIntervalSince(newDate)) >= 60
        case (nil, nil): false
        default: true
        }
        guard statusChanged || timeMoved else { return nil }

        let body = if new.targetDate == nil {
            "Launch time is now TBD."
        } else if timeMoved, let date = new.targetDate {
            "New target: \(date.formatted(date: .abbreviated, time: .shortened))"
        } else {
            "Status: \(new.status)"
        }
        return AlertConfiguration(title: "\(flightName) update", body: "\(body)", sound: .default)
    }

    private func contentState(for flight: StarshipFlight) -> StarshipFlightAttributes.ContentState {
        StarshipFlightAttributes.ContentState(
            phase: "Countdown",
            status: flight.status.name,
            targetDate: flight.launchDate,
            detail: flight.padName
        )
    }
}
#endif
