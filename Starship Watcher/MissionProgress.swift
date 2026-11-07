import Foundation

/// Where a flight is against the typical timeline. Worked out from the clock and Launch Library
/// status, never telemetry, so screens label it an estimate.
struct MissionProgress: Equatable {
    /// "Hot staging", "Awaiting liftoff", "Launch Failure".
    let title: String
    let isAlert: Bool
    /// 0...1 per phase. Phases are equal steps, not time: preflight alone spans a day.
    let fills: [FlightPhase: Double]
    /// Next event, or one per vehicle once booster and ship separate.
    let upcoming: [FlightEvent]
}

extension StarshipFlight {
    func progress(now: Date) -> MissionProgress {
        let events = timeline
        // A placeholder date passing proves nothing, so soft dates mark no progress.
        let current = hasFirmDate ? currentEventIndex(in: events, now: now) : nil
        let reached = events.prefix((current ?? -1) + 1)
        let fills = Dictionary(uniqueKeysWithValues: FlightPhase.allCases.map { phase in
            let total = events.count { $0.phase == phase }
            return (phase, Double(reached.count { $0.phase == phase }) / Double(total))
        })

        func stopped(_ title: String, isAlert: Bool = false) -> MissionProgress {
            MissionProgress(title: title, isAlert: isAlert, fills: fills, upcoming: [])
        }

        if status.isAlert { return stopped(status.displayName, isAlert: true) }
        if status.isSuccess {
            let complete = Dictionary(uniqueKeysWithValues: FlightPhase.allCases.map { ($0, 1.0) })
            return MissionProgress(title: "Mission complete", isAlert: false, fills: complete, upcoming: [])
        }
        guard hasFirmDate, let launchDate else { return stopped("Awaiting date") }
        if status.isHold { return stopped("On hold") }
        if launchDate <= now, !hasLiftedOff(now: now) { return stopped("Awaiting liftoff") }

        let remaining = events.dropFirst(reached.count)
        let upcoming: [FlightEvent]
        if let next = remaining.first, next.phase == .booster || next.phase == .ship {
            upcoming = [FlightPhase.booster, .ship].compactMap { phase in remaining.first { $0.phase == phase } }
        } else {
            upcoming = remaining.first.map { [$0] } ?? []
        }
        return MissionProgress(title: reached.last?.title ?? "Pre-count", isAlert: false, fills: fills, upcoming: upcoming)
    }
}
