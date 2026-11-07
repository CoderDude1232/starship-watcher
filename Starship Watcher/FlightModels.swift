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
    /// Best stream from Launch Library. Upcoming flights only; nil until a stream is listed.
    var webcastURL: URL? = nil
    /// False when Launch Library marks the date or time as a placeholder. Nil means unknown.
    var hasExactTime: Bool? = nil

    var isUpcoming: Bool {
        guard let launchDate else { return true }
        return launchDate >= .now.addingTimeInterval(-6 * 60 * 60)
    }

    /// Worth a ticking clock: confirmed Go, already flown, or an exact time with a date set.
    /// Otherwise the date is a placeholder (e.g. "To Be Determined", NET midnight UTC).
    var hasFirmDate: Bool {
        guard launchDate != nil else { return false }
        if status.isGo || status.confirmsLiftoff { return true }
        return !status.isTBD && hasExactTime != false
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

extension Array where Element == StarshipFlight {
    var nextFlight: StarshipFlight? {
        filter(\.isUpcoming)
            .sorted { ($0.launchDate ?? .distantFuture) < ($1.launchDate ?? .distantFuture) }
            .first
    }
}

struct LaunchStatus: Codable, Hashable {
    let name: String

    /// Launch Library: "Launch in Flight", "Launch Successful", "Launch Failure", "Launch was a Partial Failure".
    var confirmsLiftoff: Bool {
        let value = name.lowercased()
        return value.contains("flight") || value.contains("progress") || value.contains("success") || value.contains("fail")
    }

    /// Launch Library: "Go for Launch".
    var isGo: Bool {
        name.lowercased().hasPrefix("go")
    }

    /// Launch Library: "To Be Determined".
    var isTBD: Bool {
        let value = name.lowercased()
        return value.contains("determined") || value.contains("tbd")
    }

    /// Launch Library: "On Hold".
    var isHold: Bool {
        name.lowercased().contains("hold")
    }

    /// Launch Library: "On Hold", "To Be Determined".
    var isHoldOrTBD: Bool {
        isTBD || isHold
    }

    /// Launch Library: "Launch Successful". "Payload Deployed" also means it worked.
    var isSuccess: Bool {
        let value = name.lowercased()
        return value.contains("success") || value.contains("deployed")
    }

    /// Any scrub or failure. Holds stay white.
    var isAlert: Bool {
        let value = name.lowercased()
        return value.contains("fail") || value.contains("scrub") || value.contains("abort")
    }
}

struct FlightEvent: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let targetDate: Date?
    /// Seconds from liftoff. Holds even when the date slips.
    let offset: TimeInterval
    let phase: FlightPhase

    init(id: UUID = UUID(), title: String, targetDate: Date?, offset: TimeInterval, phase: FlightPhase) {
        self.id = id
        self.title = title
        self.targetDate = targetDate
        self.offset = offset
        self.phase = phase
    }

    static func standardTemplate(relativeTo launchDate: Date?) -> [FlightEvent] {
        // Offsets follow SpaceX's published timelines for Starship V3 (Flights 12 and 13, 2026).
        // Post-SECO events assume the suborbital profile; orbital flights run much longer.
        let milestones: [(TimeInterval, String, FlightPhase)] = [
            (-24 * 60 * 60, "Launch watch", .preflight),
            (-8 * 60 * 60, "Road and pad clear", .preflight),
            (-60 * 60, "Livestream watch", .preflight),
            (-50 * 60, "Flight director poll", .preflight),
            (-39 * 60, "Propellant load", .preflight),
            (-21 * 60 - 30, "Engine chill", .preflight),
            (-30, "Go for launch", .preflight),
            (0, "Liftoff", .ascent),
            (45, "Max Q", .ascent),
            (2 * 60 + 24, "Hot staging", .ascent),
            (2 * 60 + 30, "Boostback burn", .booster),
            (6 * 60 + 34, "Booster landing burn", .booster),
            (8 * 60 + 11, "Ship engine cutoff", .ship),
            (47 * 60 + 47, "Ship reentry", .ship),
            (65 * 60 + 8, "Landing flip", .ship),
            (65 * 60 + 26, "Ship splashdown", .ship)
        ]

        return milestones.map { offset, title, phase in
            FlightEvent(title: title, targetDate: launchDate?.addingTimeInterval(offset), offset: offset, phase: phase)
        }
    }
}

enum FlightPhase: String, Codable, CaseIterable {
    case preflight = "Preflight"
    case ascent = "Ascent"
    case booster = "Booster"
    case ship = "Ship"
}
