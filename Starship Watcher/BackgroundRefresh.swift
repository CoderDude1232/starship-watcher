import BackgroundTasks
import Foundation
import WidgetKit

/// Periodic background check-in so the Live Activity picks up delays, scrubs and status changes
/// without the app being opened. iOS decides the actual cadence; these are lower bounds.
enum BackgroundRefresh {
    static let identifier = "com.morgandaly.Starship-Watcher.refresh"

    static func schedule() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = .now.addingTimeInterval(nextInterval)
        try? BGTaskScheduler.shared.submit(request)
    }

    static func run() async {
        schedule()

        let repository = FlightRepository()
        await repository.refresh()
        guard !Task.isCancelled else { return }

        #if canImport(ActivityKit)
        await StarshipActivityController().sync(flight: repository.nextFlight, canStart: false)
        #endif

        let notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        if notificationsEnabled, let nextFlight = repository.nextFlight {
            await NotificationScheduler().scheduleReminders(for: nextFlight)
        }

        WidgetCenter.shared.reloadAllTimelines()
        schedule()
    }

    private static var nextInterval: TimeInterval {
        #if canImport(ActivityKit)
        if StarshipActivityController.hasLiveActivity {
            return 20 * 60
        }
        #endif
        return 3 * 60 * 60
    }
}
