import AppIntents

/// Mirror of the app target's intent. LiveActivityIntent runs in the app process, so this copy
/// only exists so widget buttons and controls can reference the type.
struct StartLaunchCountdownIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Start Launch Countdown"
    static let description = IntentDescription("Pins the next Starship launch countdown to the Lock Screen.")

    func perform() async throws -> some IntentResult {
        .result()
    }
}
