import AppIntents

#if canImport(ActivityKit)
/// Starts the Live Activity without opening the app. Runs in the app process; the widget
/// extension has a matching stub so its buttons and controls can reference it.
struct StartLaunchCountdownIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Start Launch Countdown"
    static let description = IntentDescription("Pins the next Starship launch countdown to the Lock Screen.")

    @MainActor
    func perform() async throws -> some IntentResult {
        let repository = FlightRepository()
        if (repository.lastUpdated ?? .distantPast).timeIntervalSinceNow < -15 * 60 {
            await repository.refresh()
        }
        guard let flight = repository.nextFlight else { throw CountdownStartError.launchTBD }
        try await StarshipActivityController().startNow(flight: flight)
        BackgroundRefresh.schedule()
        return .result()
    }
}

struct StarshipShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartLaunchCountdownIntent(),
            phrases: ["Start the \(.applicationName) countdown", "Pin the \(.applicationName) countdown"],
            shortTitle: "Start Countdown",
            systemImageName: "timer"
        )
    }
}
#endif
