import AppIntents
import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> StarshipWidgetEntry {
        StarshipWidgetEntry(date: .now, configuration: ConfigurationAppIntent(), flight: .preview)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> StarshipWidgetEntry {
        StarshipWidgetEntry(date: .now, configuration: configuration, flight: FlightCache.load()?.flights.nextFlight ?? .preview)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<StarshipWidgetEntry> {
        // The app keeps the shared cache fresh (and reloads widgets when it does), so the widget
        // only hits the network itself before the app has ever loaded data.
        var flight = FlightCache.load()?.flights.nextFlight
        if flight == nil {
            flight = (try? await LaunchLibraryClient().fetchStarshipFlights(includePrevious: false))?.nextFlight
        }

        let now = Date()
        let reloadDate = now.addingTimeInterval(60 * 60)
        // "T-1D 12H" needs a fresh entry each hour, and the timer text ticks on its own.
        // The large widget's stage changes at each event, and the pin button appears at T-8h.
        var dates = stride(from: 0, to: 60, by: 15).map { now.addingTimeInterval(TimeInterval($0 * 60)) }
        if let flight, flight.hasFirmDate, let launchDate = flight.launchDate {
            dates += flight.timeline.compactMap(\.targetDate) + [launchDate.addingTimeInterval(-8 * 60 * 60)]
        }
        let entries = dates
            .filter { $0 >= now && $0 < reloadDate }
            .sorted()
            .map { StarshipWidgetEntry(date: $0, configuration: configuration, flight: flight) }
        return Timeline(entries: entries, policy: .after(reloadDate))
    }
}

struct StarshipWidgetEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    /// Nil only when nothing is cached and the network failed.
    let flight: StarshipFlight?
}

struct WidgetExtensionEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StarshipWidgetEntry

    var body: some View {
        Group {
            if let flight = entry.flight {
                switch family {
                case .systemSmall:
                    SmallStarshipWidget(flight: flight, now: entry.date)
                case .systemLarge:
                    LargeStarshipWidget(flight: flight, now: entry.date)
                case .accessoryInline:
                    Text("\(flight.shortName) \(clockText(for: flight, now: entry.date))")
                case .accessoryRectangular:
                    AccessoryStarshipWidget(flight: flight, now: entry.date)
                default:
                    MediumStarshipWidget(flight: flight, now: entry.date)
                }
            } else {
                Text("No data").caps(.caption, color: Theme.secondary)
            }
        }
        .containerBackground(.black, for: .widget)
    }
}

struct SmallStarshipWidget: View {
    let flight: StarshipFlight
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlightNameText(flight: flight)
            Spacer(minLength: 0)
            WidgetClock(flight: flight, now: now, font: .title2)
            Text(flight.status.shortName)
                .caps(.caption2, color: flight.status.color, tracking: 1.5)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct MediumStarshipWidget: View {
    let flight: StarshipFlight
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlightNameText(flight: flight)
            Spacer(minLength: 0)
            WidgetClock(flight: flight, now: now, font: .largeTitle)
            Spacer(minLength: 0)
            HStack(alignment: .lastTextBaseline, spacing: 12) {
                StatusPlaceText(flight: flight)
                Spacer(minLength: 0)
                StartCountdownButton(flight: flight, now: now)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct LargeStarshipWidget: View {
    let flight: StarshipFlight
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FlightNameText(flight: flight)
            WidgetClock(flight: flight, now: now, font: .largeTitle)
            HStack(alignment: .lastTextBaseline, spacing: 12) {
                StatusPlaceText(flight: flight)
                Spacer(minLength: 0)
                StartCountdownButton(flight: flight, now: now)
            }

            Rectangle().fill(Theme.hairline).frame(height: 1)

            if flight.isInActiveWindow(now: now) {
                WidgetStage(flight: flight, now: now)
            } else {
                Text(flight.summary)
                    .font(.footnote.weight(.light))
                    .foregroundStyle(Theme.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// Launch hour on the large widget. System-drawn timers aside, a snapshot, so no live remaining time.
private struct WidgetStage: View {
    let flight: StarshipFlight
    let now: Date

    var body: some View {
        let progress = flight.progress(now: now)
        VStack(alignment: .leading, spacing: 10) {
            Text(progress.title)
                .caps(.footnote, color: progress.isAlert ? Theme.alert : .white)
            ForEach(progress.upcoming) { event in
                HStack(spacing: 12) {
                    Text(event.offsetText)
                        .font(.caption.weight(.light).monospacedDigit())
                    Text(event.title)
                        .font(.caption.weight(.light))
                }
                .foregroundStyle(Theme.secondary)
            }
        }
    }
}

struct AccessoryStarshipWidget: View {
    let flight: StarshipFlight
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(flight.shortName)
                .font(.caption.weight(.light))
                .textCase(.uppercase)
                .tracking(1.5)
                .lineLimit(1)
            clockText(for: flight, now: now)
                .font(.headline.weight(.light).monospacedDigit())
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

private struct FlightNameText: View {
    let flight: StarshipFlight

    var body: some View {
        Text(flight.shortName)
            .caps(.caption, color: Theme.secondary)
            .lineLimit(1)
    }
}

private struct StatusPlaceText: View {
    let flight: StarshipFlight

    var body: some View {
        (Text(flight.status.shortName).foregroundStyle(flight.status.color)
            + Text(" · \(flight.placeText)").foregroundStyle(Theme.secondary))
            .font(.caption2)
            .textCase(.uppercase)
            .tracking(1.5)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

private struct WidgetClock: View {
    let flight: StarshipFlight
    let now: Date
    let font: Font

    var body: some View {
        clockText(for: flight, now: now)
            .font(font.weight(.light).monospacedDigit())
            .textCase(.uppercase)
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Starts the Live Activity in place. Only shown inside the 8 hour Live Activity limit.
private struct StartCountdownButton: View {
    let flight: StarshipFlight
    let now: Date

    var body: some View {
        if flight.hasFirmDate, let launchDate = flight.launchDate,
           launchDate > now, launchDate.timeIntervalSince(now) <= 8 * 60 * 60 {
            Button(intent: StartLaunchCountdownIntent()) {
                Text("Pin")
                    .caps(.caption2, tracking: 2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay { Rectangle().strokeBorder(.white, lineWidth: 1) }
            }
            .buttonStyle(.plain)
        }
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

/// Widgets are snapshots: under a day out, use system timer text so it ticks every second.
/// Further out, whole days/hours are fine since the timeline has an entry every 15 minutes.
func clockText(for flight: StarshipFlight, now: Date) -> Text {
    switch flight.clock(now: now) {
    case .net(let text):
        return Text(text)
    case .awaitingLiftoff:
        return Text("Awaiting liftoff")
    case .elapsed(let date):
        return Text("T+\(Text(date, style: .timer))")
    case .countdown(let date):
        let remaining = Int(date.timeIntervalSince(now))
        if remaining < 86_400 {
            return Text("T-\(Text(timerInterval: now...date, countsDown: true))")
        }
        return Text(String(format: "T-%dD %02dH", remaining / 86_400, remaining / 3_600 % 24))
    }
}

extension StarshipFlight {
    /// Sample for the widget gallery.
    static let preview = StarshipFlight(
        id: "preview", name: "Starship | Flight 15", missionName: "Flight 15",
        summary: "Next Starship flight test from Starbase.", vehicle: "Starship",
        status: LaunchStatus(name: "Go for Launch"), launchDate: .now.addingTimeInterval(26 * 60 * 60),
        windowStart: nil, windowEnd: nil, launchSite: "Starbase", padName: "Pad 2", probability: nil,
        imageURL: nil, webcastLive: false, sourceURL: nil
    )
}

extension ConfigurationAppIntent {
    fileprivate static var previewIntent: ConfigurationAppIntent {
        ConfigurationAppIntent()
    }
}

#Preview(as: .systemLarge) {
    WidgetExtension()
} timeline: {
    StarshipWidgetEntry(date: .now, configuration: .previewIntent, flight: .preview)
}
