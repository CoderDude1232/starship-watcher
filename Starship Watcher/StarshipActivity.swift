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

struct StarshipActivityController {
    func start(for flight: StarshipFlight) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = StarshipFlightAttributes(
            flightID: flight.id,
            flightName: flight.name,
            vehicle: flight.vehicle,
            launchSite: flight.launchSite
        )
        let contentState = contentState(for: flight)

        if let existingActivity = Activity<StarshipFlightAttributes>.activities.first(where: { $0.attributes.flightID == flight.id }) {
            if #available(iOS 16.2, *) {
                await existingActivity.update(ActivityContent(state: contentState, staleDate: flight.launchDate))
            } else {
                await existingActivity.update(using: contentState)
            }
            return
        }

        await stopAll()

        if #available(iOS 16.2, *) {
            _ = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: contentState, staleDate: flight.launchDate),
                pushType: nil
            )
        } else {
            _ = try Activity.request(
                attributes: attributes,
                contentState: contentState,
                pushType: nil
            )
        }
    }

    func stopAll() async {
        for activity in Activity<StarshipFlightAttributes>.activities {
            if #available(iOS 16.2, *) {
                await activity.end(ActivityContent(state: activity.content.state, staleDate: nil), dismissalPolicy: .immediate)
            } else {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }

    func sync(enabled: Bool, flight: StarshipFlight?) async {
        guard enabled, let flight else {
            await stopAll()
            return
        }

        do {
            try await start(for: flight)
        } catch {
            await stopAll()
        }
    }

    private func contentState(for flight: StarshipFlight) -> StarshipFlightAttributes.ContentState {
        StarshipFlightAttributes.ContentState(
            phase: "Countdown",
            status: flight.status.name.lowercased() == "go" ? "Go for launch" : flight.status.name,
            targetDate: flight.launchDate,
            detail: flight.padName
        )
    }
}
#endif
