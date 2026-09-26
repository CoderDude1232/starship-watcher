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
        schedule(title: "Starship launch in 6 hours", body: flight.name, date: flight.launchDate?.addingTimeInterval(-6 * 60 * 60), identifier: "\(flight.id)-6h")
        schedule(title: "Starship launch in 1 hour", body: flight.name, date: flight.launchDate?.addingTimeInterval(-60 * 60), identifier: "\(flight.id)-1h")
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

    private func identifiers(for flight: StarshipFlight) -> [String] {
        ["\(flight.id)-24h", "\(flight.id)-6h", "\(flight.id)-1h", "\(flight.id)-stream"]
    }
}
