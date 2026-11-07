import Foundation

/// What the main clock shows.
enum FlightClock: Equatable {
    /// Soft date: never ticks.
    case net(String)
    case countdown(Date)
    /// Past NET unconfirmed: a hold or a late launch, not T+.
    case awaitingLiftoff
    case elapsed(Date)
}

extension StarshipFlight {
    func clock(now: Date) -> FlightClock {
        guard hasFirmDate, let launchDate else { return .net(netText) }
        if launchDate > now { return .countdown(launchDate) }
        return hasLiftedOff(now: now) ? .elapsed(launchDate) : .awaitingLiftoff
    }

    /// "Starship | Flight 15" -> "Flight 15". The vehicle is implied everywhere in this app.
    var shortName: String {
        guard let range = name.range(of: " | ") else { return name }
        return String(name[range.upperBound...])
    }

    /// T-3h to T+2h around a firm NET: when Launch polls and a stream may be called live.
    func isInActiveWindow(now: Date = .now) -> Bool {
        guard hasFirmDate, let launchDate else { return false }
        return now >= launchDate.addingTimeInterval(-3 * 60 * 60) && now <= launchDate.addingTimeInterval(2 * 60 * 60)
    }

    func isLive(now: Date = .now) -> Bool {
        webcastLive && isInActiveWindow(now: now)
    }

    /// Stream link once the launch is close. Launch Library can list one days ahead.
    func liveStreamURL(now: Date = .now) -> URL? {
        isInActiveWindow(now: now) ? webcastURL : nil
    }

    /// "NET Nov 13". Placeholder dates are midnight UTC, so local time could show the wrong day.
    var netText: String {
        guard let launchDate else { return "Date TBD" }
        var style = Date.FormatStyle(timeZone: .gmt).month(.abbreviated).day()
        if !Calendar.current.isDate(launchDate, equalTo: .now, toGranularity: .year) {
            style = style.year()
        }
        return "NET \(launchDate.formatted(style))"
    }

    /// Firm flights get date and time, the rest a NET date.
    func dateText(usesUTC: Bool, year: Bool = false) -> String {
        guard hasFirmDate, let launchDate else { return netText }
        return launchDate.launchText(usesUTC: usesUTC, year: year)
    }

    /// "Starbase · Pad 2"
    var placeText: String {
        let site = launchSite.components(separatedBy: ",").first ?? launchSite
        return "\(site) · \(padName)"
    }

    var shareText: String {
        var lines = [name]
        if let launchDate {
            lines.append(hasFirmDate ? "Targeting \(launchDate.formatted(date: .abbreviated, time: .shortened))" : netText)
        }
        lines.append("\(padName), \(launchSite)")
        lines.append("via Starship Watcher")
        return lines.joined(separator: "\n")
    }
}

extension Date {
    func launchText(usesUTC: Bool, year: Bool = false) -> String {
        var style = Date.FormatStyle(timeZone: usesUTC ? .gmt : .current).month(.abbreviated).day().hour().minute()
        if year { style = style.year() }
        return formatted(style) + (usesUTC ? " UTC" : "")
    }
}

extension FlightEvent {
    /// "T-0:39:00", "T+0:02:24".
    var offsetText: String {
        let total = Int(abs(offset))
        let sign = offset < 0 ? "T-" : "T+"
        return String(format: "%@%d:%02d:%02d", sign, total / 3600, total / 60 % 60, total % 60)
    }
}
