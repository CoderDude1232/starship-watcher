import AppIntents
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
        // The app keeps the shared cache fresh (and reloads widgets when it does), so the widget
        // only hits the network itself before the app has ever loaded data.
        var next = FlightCache.load()?.flights.nextFlight
        if next == nil {
            next = (try? await LaunchLibraryClient().fetchStarshipFlights(includePrevious: false))?.nextFlight
        }
        let flight = next.map(WidgetFlight.init) ?? .unavailable

        let now = Date()
        let reloadDate = now.addingTimeInterval(60 * 60)
        // Countdown text only changes format at T-24h (days -> ticking timer) and T-0 (T+),
        // and "T-1D 12H" needs a fresh entry each hour. The timer text ticks on its own.
        var dates = stride(from: 0, to: 60, by: 15).map { now.addingTimeInterval(TimeInterval($0 * 60)) }
        if let launchDate = flight.launchDate {
            dates += [launchDate.addingTimeInterval(-24 * 60 * 60), launchDate, launchDate.addingTimeInterval(-8 * 60 * 60)]
                .filter { $0 > now && $0 < reloadDate }
        }
        let entries = dates.sorted().map { StarshipWidgetEntry(date: $0, configuration: configuration, flight: flight) }
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
                Text("Starship \(countdownText(for: entry.flight.launchDate, now: entry.date))")
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
            WidgetCountdown(targetDate: entry.flight.launchDate, now: entry.date, size: 26)
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
            WidgetCountdown(targetDate: entry.flight.launchDate, now: entry.date, size: 30)
            Spacer(minLength: 0)
            HStack {
                WidgetStatusSiteRow(flight: entry.flight, compact: false)
                StartCountdownButton(entry: entry)
            }
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
            WidgetCountdown(targetDate: entry.flight.launchDate, now: entry.date, size: 40)
            HStack {
                WidgetStatusSiteRow(flight: entry.flight, compact: false)
                StartCountdownButton(entry: entry)
            }
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
            countdownText(for: entry.flight.launchDate, now: entry.date)
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
    let now: Date
    let size: CGFloat

    var body: some View {
        countdownText(for: targetDate, now: now)
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

/// Starts the Live Activity in place. Only shown inside the 8 hour Live Activity limit.
private struct StartCountdownButton: View {
    let entry: StarshipWidgetEntry

    var body: some View {
        if let launchDate = entry.flight.launchDate,
           launchDate > entry.date,
           launchDate.timeIntervalSince(entry.date) <= 8 * 60 * 60 {
            Button(intent: StartLaunchCountdownIntent()) {
                Label("Pin", systemImage: "pin.fill")
                    .font(.caption.weight(.black))
            }
            .buttonStyle(.bordered)
            .tint(.white)
        }
    }
}

private struct WidgetStatusSiteRow: View {
    let flight: WidgetFlight
    let compact: Bool

    var body: some View {
        let (label, tint) = launchStatusBadge(flight.status)
        HStack(spacing: compact ? 6 : 8) {
            Text(label)
                .font(.caption.weight(.black))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, compact ? 8 : 10)
                .padding(.vertical, compact ? 4 : 5)
                .background(tint.opacity(0.18), in: Capsule())

            Label(flight.pad, systemImage: "mappin.and.ellipse")
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.64)
                .foregroundStyle(.white.opacity(0.76))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

/// Widgets are snapshots: under a day out, use system timer text so it ticks every second.
/// Further out, whole days/hours are fine since the timeline has an entry every 15 minutes.
private func countdownText(for targetDate: Date?, now: Date) -> Text {
    guard let targetDate else { return Text("TBD") }
    let interval = targetDate.timeIntervalSince(now)
    if interval <= 0 {
        return Text("T+\(Text(targetDate, style: .timer))")
    }
    if interval < 86400 {
        return Text("T-\(Text(timerInterval: now...targetDate, countsDown: true))")
    }
    let remaining = Int(interval)
    return Text(String(format: "T-%dD %02dH", remaining / 86400, remaining / 3600 % 24))
}

struct WidgetFlight: Hashable {
    let name: String
    let status: String
    let launchDate: Date?
    let pad: String

    static let placeholder = WidgetFlight(name: "Flight Test", status: "TBD", launchDate: Calendar.current.date(byAdding: .day, value: 1, to: .now), pad: "Starbase")
    /// No data at all: show TBD rather than a fake countdown.
    static let unavailable = WidgetFlight(name: "Starship", status: "TBD", launchDate: nil, pad: "Starbase")
}

extension WidgetFlight {
    init(_ flight: StarshipFlight) {
        self.init(name: flight.name, status: flight.status.name, launchDate: flight.launchDate, pad: flight.launchSite)
    }
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
