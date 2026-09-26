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
        let milestones: [(TimeInterval, String, String, FlightPhase)] = [
            (-24 * 60 * 60, "Launch watch", "Begin monitoring for weather, marine notices, road closures, and webcast updates.", .preflight),
            (-8 * 60 * 60, "Road and pad clear", "Final pad access closes before propellant operations.", .preflight),
            (-3 * 60 * 60, "Livestream watch", "Check official channels for webcast availability and updated target time.", .preflight),
            (-2 * 60 * 60, "Propellant load", "Ship and booster loading enters the active countdown sequence.", .preflight),
            (-40 * 60, "Flight director poll", "Teams verify launch commit criteria and weather constraints.", .preflight),
            (-10 * 60, "Terminal count", "Vehicle and ground systems enter the final automated countdown.", .preflight),
            (0, "Liftoff", "Super Heavy and Starship clear the launch mount.", .launch),
            (60, "Max Q", "Vehicle passes through peak aerodynamic pressure.", .ascent),
            (2 * 60 + 45, "Hot staging", "Ship separates while Super Heavy begins boostback handling.", .ascent),
            (7 * 60, "Booster landing burn", "Super Heavy targets its planned landing or splashdown profile.", .booster),
            (18 * 60, "Ship engine cutoff", "Starship reaches its planned coast phase if ascent objectives continue nominally.", .ship),
            (48 * 60, "Ship reentry", "Starship begins entry interface and heating assessment.", .ship),
            (62 * 60, "Landing flip", "Ship transitions toward its terminal descent and landing-burn profile.", .ship),
            (66 * 60, "Ship splashdown", "Flight test objectives conclude with the planned terminal event.", .ship)
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
