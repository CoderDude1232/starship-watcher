import BackgroundTasks
import Foundation

/// Periodic background check-in so the Live Activity picks up delays, scrubs and status changes
/// without the app being opened. iOS decides the actual cadence; these are lower bounds.
enum BackgroundRefresh {
    static let identifier = "com.morgandaly.Starship-Watcher.refresh"

    static func schedule() {
        let identifier = identifier
        let earliestBeginDate = Date.now.addingTimeInterval(nextInterval(launchDate: FlightRepository().nextFlight?.launchDate))
        // The async submit API must not be called on the main thread.
        Task.detached(priority: .utility) {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
            let request = BGAppRefreshTaskRequest(identifier: identifier)
            request.earliestBeginDate = earliestBeginDate
            try? await BGTaskScheduler.shared.submitTaskRequest(request)
        }
    }

    static func run() async {
        schedule()

        let repository = FlightRepository()
        await repository.refresh(minInterval: 15 * 60)
        guard !Task.isCancelled else { return }

        #if canImport(ActivityKit)
        await StarshipActivityController().sync(flight: repository.nextFlight, canStart: false)
        #endif

        let notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        if notificationsEnabled, let nextFlight = repository.nextFlight {
            await NotificationScheduler().scheduleReminders(for: nextFlight)
        }

        schedule()
    }

    /// Keeps background use of Launch Library light: check often only when a launch is close.
    private static func nextInterval(launchDate: Date?) -> TimeInterval {
        #if canImport(ActivityKit)
        if StarshipActivityController.hasLiveActivity {
            return 30 * 60
        }
        #endif
        if let launchDate, launchDate.timeIntervalSinceNow < 24 * 60 * 60 {
            return 2 * 60 * 60
        }
        return 6 * 60 * 60
    }
}
