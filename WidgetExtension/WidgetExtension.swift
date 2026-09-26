import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> StarshipWidgetEntry {
        StarshipWidgetEntry(date: .now, configuration: ConfigurationAppIntent(), flight: .placeholder)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> StarshipWidgetEntry {
        StarshipWidgetEntry(date: .now, configuration: configuration, flight: .placeholder)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<StarshipWidgetEntry> {
        let flight: WidgetFlight
        if let cachedFlight = WidgetSharedCache().nextFlight() {
            flight = cachedFlight
        } else if let launchLibraryFlight = await WidgetLaunchClient().nextStarshipFlight() {
            flight = launchLibraryFlight
        } else if let fallbackFlight = await WidgetSpaceXClient().nextStarshipFlight() {
            flight = fallbackFlight
        } else {
            flight = .placeholder
        }
        let now = Date()
        let entries = stride(from: 0, through: 60, by: 15).map { minute in
            let date = Calendar.current.date(byAdding: .minute, value: minute, to: now) ?? now
            return StarshipWidgetEntry(date: date, configuration: configuration, flight: flight)
        }
        let reloadDate = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now.addingTimeInterval(3600)
        return Timeline(entries: entries, policy: .after(reloadDate))
    }
}

struct StarshipWidgetEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let flight: WidgetFlight
}

struct WidgetExtensionEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StarshipWidgetEntry

    var body: some View {
        ZStack {
            WidgetBackdrop()

            switch family {
            case .systemSmall:
                SmallStarshipWidget(entry: entry)
            case .systemLarge:
                LargeStarshipWidget(entry: entry)
            case .accessoryInline:
                Text("Starship \(compactCountdownText(for: entry.flight.launchDate, now: entry.date))")
            case .accessoryRectangular:
                AccessoryStarshipWidget(entry: entry)
            default:
                MediumStarshipWidget(entry: entry)
            }
        }
        .containerBackground(.black, for: .widget)
    }
}

private struct SmallStarshipWidget: View {
    let entry: StarshipWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetHeader(flight: entry.flight, compact: true)
            Spacer(minLength: 0)
            WidgetCountdown(targetDate: entry.flight.launchDate, size: 26)
            WidgetStatusSiteRow(flight: entry.flight, compact: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct MediumStarshipWidget: View {
    let entry: StarshipWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WidgetHeader(flight: entry.flight, compact: false)
            WidgetCountdown(targetDate: entry.flight.launchDate, size: 30)
            Spacer(minLength: 0)
            WidgetStatusSiteRow(flight: entry.flight, compact: false)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct LargeStarshipWidget: View {
    let entry: StarshipWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WidgetHeader(flight: entry.flight, compact: false)
            WidgetCountdown(targetDate: entry.flight.launchDate, size: 40)
            WidgetStatusSiteRow(flight: entry.flight, compact: false)
            Divider().overlay(.white.opacity(0.16))
            VStack(alignment: .leading, spacing: 6) {
                Text("NEXT EVENT")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.white.opacity(0.58))
                Text("Launch data refreshes automatically and falls back to saved flight data when offline.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct AccessoryStarshipWidget: View {
    let entry: StarshipWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.flight.name)
                .font(.caption.weight(.bold))
                .lineLimit(1)
            Text(compactCountdownText(for: entry.flight.launchDate, now: entry.date))
                .font(.caption2.weight(.black).monospacedDigit())
        }
    }
}

private struct WidgetHeader: View {
    let flight: WidgetFlight
    let compact: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("STARSHIP")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.white.opacity(0.58))
                Text(flight.name)
                    .font(.system(compact ? .headline : .title3, design: .default).weight(.black))
                    .lineLimit(compact ? 2 : 1)
                    .minimumScaleFactor(0.68)
            }
            Spacer(minLength: 0)
            Image(systemName: "paperplane.fill")
                .font(.system(size: compact ? 16 : 18, weight: .bold))
                .foregroundStyle(.white.opacity(0.78))
                .rotationEffect(.degrees(-28))
        }
    }
}

private struct WidgetCountdown: View {
    let targetDate: Date?
    let size: CGFloat

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            Text(compactCountdownText(for: targetDate, now: timeline.date))
                .font(.system(size: size, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.48)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                }
        }
    }
}

private struct WidgetStatusSiteRow: View {
    let flight: WidgetFlight
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            Text(shortStatus)
                .font(.caption.weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, compact ? 8 : 10)
                .padding(.vertical, compact ? 4 : 5)
                .background(.white.opacity(0.16), in: Capsule())

            Label(flight.pad, systemImage: "mappin.and.ellipse")
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.64)
                .foregroundStyle(.white.opacity(0.76))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var shortStatus: String {
        let status = flight.displayStatus.trimmingCharacters(in: .whitespacesAndNewlines)
        if status.localizedCaseInsensitiveContains("confirm") || status.localizedCaseInsensitiveContains("tbd") {
            return "TBD"
        }
        if status.localizedCaseInsensitiveContains("go") {
            return "GO"
        }
        return status.uppercased()
    }
}

struct WidgetExtension: Widget {
    let kind: String = "WidgetExtension"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            WidgetExtensionEntryView(entry: entry)
        }
        .configurationDisplayName("Starship Countdown")
        .description("Track the next Starship flight from your Home Screen or StandBy.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

private struct WidgetBackdrop: View {
    var body: some View {
        LinearGradient(
            colors: [.black, Color(red: 0.08, green: 0.08, blue: 0.09), .black],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .stroke(.white.opacity(0.08), lineWidth: 34)
                .frame(width: 150, height: 150)
                .offset(x: 56, y: -70)
        }
        .overlay(alignment: .bottomLeading) {
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 1)
        }
    }
}

private func compactCountdownText(for targetDate: Date?, now: Date) -> String {
    guard let targetDate else { return "TBD" }
    let interval = targetDate.timeIntervalSince(now)
    let sign = interval >= 0 ? "T-" : "T+"
    let remaining = abs(Int(interval))
    let days = remaining / 86400
    let hours = remaining / 3600 % 24
    let minutes = remaining / 60 % 60
    let seconds = remaining % 60
    if days >= 10 {
        return String(format: "%@%dD %02dH", sign, days, hours)
    }
    if days > 0 {
        return String(format: "%@%dD %02d:%02d", sign, days, hours, minutes)
    }
    return String(format: "%@%02d:%02d:%02d", sign, hours, minutes, seconds)
}

struct WidgetFlight: Decodable, Hashable {
    let name: String
    let status: String
    let launchDate: Date?
    let pad: String

    var displayStatus: String {
        status.lowercased() == "go" ? "Go for launch" : status
    }

    static let placeholder = WidgetFlight(name: "Flight Test", status: "TBD", launchDate: Calendar.current.date(byAdding: .day, value: 1, to: .now), pad: "Starbase")
}

private struct WidgetLaunchClient {
    func nextStarshipFlight() async -> WidgetFlight? {
        var components = URLComponents(string: "https://ll.thespacedevs.com/2.0.0/launch/upcoming/")
        components?.queryItems = [
            URLQueryItem(name: "search", value: "Starship"),
            URLQueryItem(name: "limit", value: "5"),
            URLQueryItem(name: "ordering", value: "net")
        ]
        guard let url = components?.url else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { return nil }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let value = try container.decode(String.self)
                if let date = ISO8601DateFormatter.withFractional.date(from: value) ?? ISO8601DateFormatter.plain.date(from: value) {
                    return date
                }
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date")
            }
            let decoded = try decoder.decode(WidgetLaunchResponse.self, from: data)
            return decoded.results.first.map { launch in
                WidgetFlight(name: launch.name, status: launch.status.name, launchDate: launch.net, pad: launch.pad?.location.name ?? "Starbase")
            }
        } catch {
            return nil
        }
    }
}

private struct WidgetSharedCache {
    func nextFlight() -> WidgetFlight? {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.morgandaly.Starship-Watcher") else {
            return nil
        }
        let cacheURL = containerURL.appending(path: "starship-flights-cache.json")
        guard let data = try? Data(contentsOf: cacheURL),
              let cached = try? JSONDecoder().decode(WidgetCachedFlights.self, from: data) else {
            return nil
        }
        return cached.flights
            .filter { ($0.launchDate ?? .distantFuture) >= .now.addingTimeInterval(-6 * 60 * 60) }
            .sorted { ($0.launchDate ?? .distantFuture) < ($1.launchDate ?? .distantFuture) }
            .first
            .map { WidgetFlight(name: $0.name, status: $0.status.name, launchDate: $0.launchDate, pad: $0.launchSite) }
    }
}

private struct WidgetCachedFlights: Decodable {
    let flights: [WidgetCachedFlight]
}

private struct WidgetCachedFlight: Decodable {
    let name: String
    let status: WidgetCachedStatus
    let launchDate: Date?
    let launchSite: String
}

private struct WidgetCachedStatus: Decodable {
    let name: String
}

private struct WidgetSpaceXClient {
    func nextStarshipFlight() async -> WidgetFlight? {
        guard let url = URL(string: "https://api.spacexdata.com/v5/launches/upcoming") else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { return nil }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let value = try container.decode(String.self)
                if let date = ISO8601DateFormatter.withFractional.date(from: value) ?? ISO8601DateFormatter.plain.date(from: value) {
                    return date
                }
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date")
            }
            let launches = try decoder.decode([WidgetSpaceXLaunch].self, from: data)
            return launches.first { launch in
                let searchable = "\(launch.name) \(launch.details ?? "")".lowercased()
                return searchable.contains("starship") || searchable.contains("flight test")
            }.map { launch in
                WidgetFlight(name: launch.name, status: "Backup source", launchDate: launch.dateUTC, pad: "SpaceX")
            }
        } catch {
            return nil
        }
    }
}

private struct WidgetSpaceXLaunch: Decodable {
    let name: String
    let details: String?
    let dateUTC: Date?

    enum CodingKeys: String, CodingKey {
        case name
        case details
        case dateUTC = "date_utc"
    }
}

private struct WidgetLaunchResponse: Decodable {
    let results: [WidgetLaunch]
}

private struct WidgetLaunch: Decodable {
    let name: String
    let status: WidgetLaunchStatus
    let net: Date?
    let pad: WidgetLaunchPad?
}

private struct WidgetLaunchStatus: Decodable {
    let name: String
}

private struct WidgetLaunchPad: Decodable {
    let location: WidgetLaunchLocation
}

private struct WidgetLaunchLocation: Decodable {
    let name: String
}

private extension ISO8601DateFormatter {
    static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let withFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

extension ConfigurationAppIntent {
    fileprivate static var preview: ConfigurationAppIntent {
        ConfigurationAppIntent()
    }
}

#Preview(as: .systemLarge) {
    WidgetExtension()
} timeline: {
    StarshipWidgetEntry(date: .now, configuration: .preview, flight: .placeholder)
}
