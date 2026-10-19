import Foundation

struct StarshipFlight: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let missionName: String
    let summary: String
    let vehicle: String
    let status: LaunchStatus
    let launchDate: Date?
    let windowStart: Date?
    let windowEnd: Date?
    let launchSite: String
    let padName: String
    let probability: Int?
    let imageURL: URL?
    let webcastLive: Bool
    let sourceURL: URL?

    var isUpcoming: Bool {
        guard let launchDate else { return true }
        return launchDate >= .now.addingTimeInterval(-6 * 60 * 60)
    }

    var timeline: [FlightEvent] {
        guard let launchDate else {
            return FlightEvent.standardTemplate(relativeTo: nil)
        }
        return FlightEvent.standardTemplate(relativeTo: launchDate)
    }

    /// Liftoff confirmed by status, or webcast live past NET while still Go. Holds and TBD never count,
    /// so the timeline waits at the last pre-launch event instead of running on the device clock.
    func hasLiftedOff(now: Date) -> Bool {
        if status.confirmsLiftoff { return true }
        guard !status.isHoldOrTBD, webcastLive, let launchDate else { return false }
        return now >= launchDate
    }

    /// The latest event reached: past its target time and, after T0, only once liftoff is confirmed.
    func currentEventIndex(in events: [FlightEvent], now: Date) -> Int? {
        let liftedOff = hasLiftedOff(now: now)
        return events.lastIndex { event in
            guard let targetDate = event.targetDate, targetDate <= now else { return false }
            return event.phase == .preflight || liftedOff
        }
    }

    func currentEvent(now: Date) -> FlightEvent? {
        let events = timeline
        return currentEventIndex(in: events, now: now).map { events[$0] }
    }
}

struct LaunchStatus: Codable, Hashable {
    let name: String

    var tintName: String {
        switch name.lowercased() {
        case let value where value.contains("go") || value.contains("confirm"):
            return "green"
        case let value where value.contains("hold") || value.contains("tbd"):
            return "orange"
        case let value where value.contains("flight") || value.contains("progress"):
            return "blue"
        case let value where value.contains("fail") || value.contains("scrub"):
            return "red"
        case let value where value.contains("success"):
            return "teal"
        default:
            return "gray"
        }
    }

    /// Launch Library: "Launch in Flight", "Launch Successful", "Launch Failure", "Launch was a Partial Failure".
    var confirmsLiftoff: Bool {
        let value = name.lowercased()
        return value.contains("flight") || value.contains("progress") || value.contains("success") || value.contains("fail")
    }

    /// Launch Library: "On Hold", "To Be Determined".
    var isHoldOrTBD: Bool {
        let value = name.lowercased()
        return value.contains("hold") || value.contains("determined") || value.contains("tbd")
    }
}

struct FlightEvent: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let detail: String
    let targetDate: Date?
    let phase: FlightPhase

    init(id: UUID = UUID(), title: String, detail: String, targetDate: Date?, phase: FlightPhase) {
        self.id = id
        self.title = title
        self.detail = detail
        self.targetDate = targetDate
        self.phase = phase
    }

    static func standardTemplate(relativeTo launchDate: Date?) -> [FlightEvent] {
        // Offsets follow SpaceX's published timelines for Starship V3 (Flights 12 and 13, 2026).
        // Post-SECO events assume the suborbital profile; orbital flights run much longer.
        let milestones: [(TimeInterval, String, String, FlightPhase)] = [
            (-24 * 60 * 60, "Launch watch", "Begin monitoring for weather, marine notices, road closures, and webcast updates.", .preflight),
            (-8 * 60 * 60, "Road and pad clear", "Final pad access closes before propellant operations.", .preflight),
            (-60 * 60, "Livestream watch", "Check official channels for webcast availability and updated target time.", .preflight),
            (-50 * 60, "Flight director poll", "Teams verify GO for propellant loading.", .preflight),
            (-39 * 60, "Propellant load", "Ship and booster liquid oxygen and methane loading begins.", .preflight),
            (-21 * 60 - 30, "Engine chill", "Raptor engine chill begins on booster and ship.", .preflight),
            (-30, "Go for launch", "Flight director verifies GO for launch.", .preflight),
            (0, "Liftoff", "Super Heavy and Starship clear the launch mount.", .launch),
            (45, "Max Q", "Vehicle passes through peak aerodynamic pressure.", .ascent),
            (2 * 60 + 24, "Hot staging", "Ship engines ignite and the stages separate.", .ascent),
            (2 * 60 + 30, "Boostback burn", "Super Heavy turns back toward its landing or splashdown zone.", .booster),
            (6 * 60 + 34, "Booster landing burn", "Super Heavy targets its planned landing or splashdown profile.", .booster),
            (8 * 60 + 11, "Ship engine cutoff", "Starship reaches its planned coast phase if ascent objectives continue nominally.", .ship),
            (47 * 60 + 47, "Ship reentry", "Starship begins entry interface and heating assessment.", .ship),
            (65 * 60 + 8, "Landing flip", "Ship flips and lights its landing burn.", .ship),
            (65 * 60 + 26, "Ship splashdown", "Flight test objectives conclude with the planned terminal event.", .ship)
        ]

        return milestones.map { offset, title, detail, phase in
            FlightEvent(title: title, detail: detail, targetDate: launchDate?.addingTimeInterval(offset), phase: phase)
        }
    }
}

enum FlightPhase: String, Codable, CaseIterable {
    case preflight = "Preflight"
    case launch = "Launch"
    case ascent = "Ascent"
    case booster = "Booster"
    case ship = "Ship"
}

struct StarshipSettings: Codable, Hashable {
    var usesUTC: Bool = false
    var notificationsEnabled: Bool = true
    var liveActivityEnabled: Bool = true
    var highContrastTelemetry: Bool = false
}
