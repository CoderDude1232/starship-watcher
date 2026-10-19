import Foundation

#if canImport(ActivityKit)
@preconcurrency import ActivityKit

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

    /// Slips smaller than this update the countdown silently. Launch Library nudges NET often on
    /// launch day, and corrects it to the real liftoff time afterwards.
    static let alertSlipThreshold: TimeInterval = 15 * 60
    /// Minimum gap between alerts, except for liftoff and the final result.
    static let alertCooldown: TimeInterval = 15 * 60
    private static let lastAlertKey = "liveActivityLastAlert"

    /// Lights up the Lock Screen only for changes worth a sound: hold/TBD, a real slip, liftoff, result.
    /// Everything else updates the activity silently.
    private func alert(from old: StarshipFlightAttributes.ContentState, to new: StarshipFlightAttributes.ContentState, flightName: String) -> AlertConfiguration? {
        let oldKind = StatusKind(old.status)
        let newKind = StatusKind(new.status)

        let body: String
        if newKind != oldKind, newKind.isFinal || newKind == .inFlight {
            body = newKind == .inFlight ? "Liftoff!" : "Status: \(new.status)"
        } else if new.targetDate == nil, old.targetDate != nil {
            body = "Launch time is now TBD."
        } else if newKind != oldKind, newKind == .hold || newKind == .tbd {
            body = "Status: \(new.status)"
        } else if newKind == .go, oldKind == .hold || oldKind == .tbd {
            body = "Countdown resumed."
        } else if !newKind.isAfterLiftoff, let oldDate = old.targetDate, let newDate = new.targetDate,
                  oldDate > .now, abs(oldDate.timeIntervalSince(newDate)) >= Self.alertSlipThreshold {
            body = "New target: \(newDate.formatted(date: .abbreviated, time: .shortened))"
        } else {
            return nil
        }

        let defaults = UserDefaults.standard
        let urgent = newKind != oldKind && (newKind.isFinal || newKind == .inFlight)
        if !urgent, let last = defaults.object(forKey: Self.lastAlertKey) as? Date,
           Date.now.timeIntervalSince(last) < Self.alertCooldown {
            return nil
        }
        defaults.set(Date.now, forKey: Self.lastAlertKey)
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

/// Launch Library status names bucketed for alert decisions ("Go for Launch", "On Hold", ...).
private enum StatusKind {
    case go, tbc, tbd, hold, inFlight, success, failure, other

    init(_ status: String) {
        let value = status.lowercased()
        self = if value.contains("success") { .success }
        else if value.contains("fail") { .failure }
        else if value.contains("flight") || value.contains("progress") { .inFlight }
        else if value.contains("hold") { .hold }
        else if value.contains("determined") || value.contains("tbd") { .tbd }
        else if value.contains("confirmed") || value.contains("tbc") { .tbc }
        else if value.contains("go") { .go }
        else { .other }
    }

    var isFinal: Bool { self == .success || self == .failure }
    var isAfterLiftoff: Bool { self == .inFlight || isFinal }
}
#endif
