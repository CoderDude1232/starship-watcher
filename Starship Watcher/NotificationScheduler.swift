import Foundation
import UserNotifications

struct NotificationScheduler {
    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func scheduleReminders(for flight: StarshipFlight) async {
        guard await requestAuthorization() else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers(for: flight))

        schedule(title: "Starship launch tomorrow", body: flight.name, date: flight.launchDate?.addingTimeInterval(-24 * 60 * 60), identifier: "\(flight.id)-24h")
        let liveLead = liveActivityLead
        if liveLead != 6 * 60 * 60 {
            schedule(title: "Starship launch in 6 hours", body: flight.name, date: flight.launchDate?.addingTimeInterval(-6 * 60 * 60), identifier: "\(flight.id)-6h")
        }
        if liveLead != 60 * 60 {
            schedule(title: "Starship launch in 1 hour", body: flight.name, date: flight.launchDate?.addingTimeInterval(-60 * 60), identifier: "\(flight.id)-1h")
        }
        if let liveLead {
            // Opening the app from this starts the Live Activity if iOS didn't let it start in the background.
            let hours = Int(liveLead / 3600)
            schedule(title: "Starship launch in \(hours) hour\(hours == 1 ? "" : "s")", body: "Tap to pin the \(flight.name) countdown to your Lock Screen.", date: flight.launchDate?.addingTimeInterval(-liveLead), identifier: "\(flight.id)-live")
        }
        schedule(title: "Starship launch window opening", body: "Check livestream availability for \(flight.name).", date: flight.windowStart ?? flight.launchDate?.addingTimeInterval(-30 * 60), identifier: "\(flight.id)-stream")
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

    private func identifiers(for flight: StarshipFlight) -> [String] {
        ["\(flight.id)-24h", "\(flight.id)-6h", "\(flight.id)-1h", "\(flight.id)-live", "\(flight.id)-stream"]
    }
}
