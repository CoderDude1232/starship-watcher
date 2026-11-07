import Foundation
import UserNotifications
#if canImport(ActivityKit)
import ActivityKit
#endif

struct NotificationScheduler {
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Replaces all pending reminders. At most three per launch: the day before, the Live Activity
    /// pin prompt (if enabled), and webcast time. The Live Activity covers everything in between.
    func sync(flight: StarshipFlight?) async {
        // Only this scheduler uses local notifications. Clearing first also drops reminders for a flight
        // that slipped, lost its firm date or stopped being next, and everything when switched off.
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        guard Self.isEnabled, await requestAuthorization() else { return }
        // A placeholder date would promise a launch nobody has scheduled.
        guard let flight, flight.hasFirmDate else { return }

        schedule(title: "Starship launch tomorrow", body: flight.shortName, date: flight.launchDate?.addingTimeInterval(-24 * 60 * 60), identifier: "\(flight.id)-24h")
        if let liveLead = liveActivityLead, !hasLiveActivity(for: flight) {
            // Opening the app from this starts the Live Activity if iOS didn't let it start in the background.
            let hours = Int(liveLead / 3600)
            schedule(title: "Starship launch in \(hours) hour\(hours == 1 ? "" : "s")", body: "Tap to pin the \(flight.shortName) countdown to your Lock Screen.", date: flight.launchDate?.addingTimeInterval(-liveLead), identifier: "\(flight.id)-live")
        }
        // Not `windowStart`: for Starship it usually equals NET, so the reminder landed at liftoff.
        schedule(title: "Starship webcast starting soon", body: "\(flight.shortName) launches in about 30 minutes.", date: flight.launchDate?.addingTimeInterval(-30 * 60), identifier: "\(flight.id)-stream")
    }

    private func schedule(title: String, body: String, date: Date?, identifier: String) {
        guard let date, date > .now.addingTimeInterval(30) else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private var liveActivityLead: TimeInterval? {
        #if canImport(ActivityKit)
        StarshipActivityController.isEnabled ? StarshipActivityController.lead : nil
        #else
        nil
        #endif
    }

    private func hasLiveActivity(for flight: StarshipFlight) -> Bool {
        #if canImport(ActivityKit)
        StarshipActivityController.liveActivities.contains { $0.attributes.flightID == flight.id }
        #else
        false
        #endif
    }
}
