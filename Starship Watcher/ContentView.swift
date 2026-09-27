import SwiftUI

struct ContentView: View {
    @State private var repository = FlightRepository()
    @State private var newsRepository = NewsRepository()
    @AppStorage("usesUTC") private var usesUTC = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("liveActivityEnabled") private var liveActivityEnabled = true
    @AppStorage("highContrastTelemetry") private var highContrastTelemetry = false
    @AppStorage("activityLeadHours") private var activityLeadHours = 6
    @AppStorage("backendCacheURL") private var backendCacheURL = ""
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            WatchView(repository: repository, usesUTC: usesUTC)
                .tabItem {
                    Label("Watch", systemImage: "binoculars.fill")
                }

            FlightsView(repository: repository, usesUTC: usesUTC)
                .tabItem {
                    Label("Flights", systemImage: "list.bullet.rectangle")
                }

            MissionScreen(repository: repository, usesUTC: usesUTC)
                .tabItem {
                    Label("Mission", systemImage: "point.3.connected.trianglepath.dotted")
                }

            NewsView(repository: newsRepository, imageURL: repository.nextFlight?.imageURL)
                .tabItem {
                    Label("News", systemImage: "newspaper")
                }

            SettingsView(
                usesUTC: $usesUTC,
                notificationsEnabled: $notificationsEnabled,
                liveActivityEnabled: $liveActivityEnabled,
                highContrastTelemetry: $highContrastTelemetry,
                activityLeadHours: $activityLeadHours,
                backendCacheURL: $backendCacheURL,
                dataSource: repository.activeSource,
                lastUpdated: repository.lastUpdated,
                imageURL: repository.nextFlight?.imageURL
            )
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .tint(.white)
        .task {
            // Live Activities cap at 8h; older builds offered longer lead times.
            activityLeadHours = min(activityLeadHours, 8)
            await repository.refresh()
            await syncLiveActivity()
            if notificationsEnabled, let nextFlight = repository.nextFlight {
                await NotificationScheduler().scheduleReminders(for: nextFlight)
            }
            await newsRepository.refresh()
        }
        .onChange(of: liveActivityEnabled) { _, enabled in
            Task {
                #if canImport(ActivityKit)
                if !enabled { await StarshipActivityController().endAll() }
                #endif
                await syncLiveActivity()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Covers opening from the "countdown ready" reminder or a widget tap.
            guard phase == .active, !repository.isLoading else { return }
            Task {
                await repository.refresh(minInterval: 15 * 60)
                await syncLiveActivity()
            }
        }
        .onChange(of: repository.nextFlight) { _, _ in
            Task { await syncLiveActivity() }
        }
        .onChange(of: activityLeadHours) { _, _ in
            Task {
                await syncLiveActivity()
                if notificationsEnabled, let nextFlight = repository.nextFlight {
                    await NotificationScheduler().scheduleReminders(for: nextFlight)
                }
            }
        }
        .task(id: liveActivityMonitorID) {
            await monitorLiveActivityThresholds()
        }
    }

    private var liveActivityMonitorID: String {
        "\(repository.nextFlight?.id ?? "none")-\(repository.nextFlight?.launchDate?.timeIntervalSince1970 ?? 0)-\(activityLeadHours)-\(liveActivityEnabled)"
    }

    private func syncLiveActivity() async {
        #if canImport(ActivityKit)
        await StarshipActivityController().sync(flight: repository.nextFlight, canStart: true)
        #endif
    }

    private func monitorLiveActivityThresholds() async {
        #if canImport(ActivityKit)
        guard liveActivityEnabled, let launchDate = repository.nextFlight?.launchDate else { return }
        let start = StarshipActivityController.windowStart(for: launchDate)
        while !Task.isCancelled, start > .now {
            try? await Task.sleep(for: .seconds(min(max(start.timeIntervalSinceNow, 1), 60 * 60)))
        }
        await syncLiveActivity()
        #endif
    }
}

private struct WatchView: View {
    let repository: FlightRepository
    let usesUTC: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                FlightImageBackdrop(imageURL: repository.nextFlight?.imageURL)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        if repository.isFirstLoad {
                            SkeletonCard(lines: 4)
                            SkeletonCard(lines: 3)
                        } else if let flight = repository.nextFlight {
                            HeroFlightView(flight: flight, usesUTC: usesUTC)
                                .transition(.opacity)
                            if let warning = repository.sourceWarningMessage {
                                DataWarningBanner(message: warning)
                            }
                            MissionSummaryView(flight: flight, usesUTC: usesUTC)
                        } else {
                            EmptyFlightView()
                        }

                        if let errorMessage = repository.errorMessage {
                            InlineNotice(message: errorMessage)
                        }

                        if !repository.isFirstLoad {
                            LastUpdatedFooter(date: repository.lastUpdated, source: repository.activeSource, usesUTC: usesUTC)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .animation(.smooth, value: repository.nextFlight?.id)
                }
                .refreshable {
                    await repository.refresh(minInterval: 60)
                }
            }
            .navigationTitle("Starship Watcher")
            .refreshingToolbar(isLoading: repository.isLoading)
            .sensoryFeedback(.success, trigger: repository.lastUpdated)
        }
    }
}

private struct HeroFlightView: View {
    let flight: StarshipFlight
    let usesUTC: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Next Flight")
                        .eyebrowStyle(color: Theme.accent)
                    Spacer()
                    ShareLink(item: flight.shareText) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .accessibilityLabel("Share flight")
                }
                Text(flight.name)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    StatusTag(status: flight.status)
                    MetaTag(text: flight.launchSite, systemImage: "mappin.and.ellipse")
                    if flight.webcastLive {
                        MetaTag(text: "Live", systemImage: "dot.radiowaves.left.and.right", tint: StatusTint.failure.color)
                    }
                }
            }

            CountdownView(targetDate: flight.launchDate)

            TelemetryGrid(items: [
                TelemetryItem(label: "Vehicle", value: flight.vehicle, systemImage: "airplane.departure"),
                TelemetryItem(label: "Window", value: windowText(for: flight), systemImage: "clock"),
                TelemetryItem(label: "Pad", value: flight.padName, systemImage: "scope"),
                TelemetryItem(
                    label: "Probability",
                    value: flight.probability.map { "\($0)%" } ?? "—",
                    tint: flight.probability != nil ? StatusTint.go.color : .white,
                    systemImage: "percent"
                )
            ])
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .starshipGlass(cornerRadius: Theme.Radius.hero)
    }

    private func windowText(for flight: StarshipFlight) -> String {
        guard let start = flight.windowStart, let end = flight.windowEnd else {
            return flight.launchDate.formattedLaunchDate(usesUTC: usesUTC)
        }
        return "\(start.formattedTime(usesUTC: usesUTC))-\(end.formattedTime(usesUTC: usesUTC))"
    }
}

private struct CountdownView: View {
    let targetDate: Date?

    private var hasLaunched: Bool {
        guard let targetDate else { return false }
        return targetDate.timeIntervalSinceNow <= 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(hasLaunched ? "Mission Elapsed" : "Countdown")
                    .eyebrowStyle(color: .white.opacity(0.7))
                Spacer()
                if hasLaunched {
                    MetaTag(text: "Live", systemImage: "dot.radiowaves.left.and.right", tint: StatusTint.inFlight.color)
                }
            }
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                Text(Countdown.text(to: targetDate, now: timeline.date))
                    .contentTransition(.numericText(countsDown: !hasLaunched))
                    .font(.system(size: 38, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .frame(maxWidth: .infinity, minHeight: 74, alignment: .center)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                            .strokeBorder(.white.opacity(0.16), lineWidth: 1)
                    }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct MissionSummaryView: View {
    let flight: StarshipFlight
    let usesUTC: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionRule(title: "Mission", symbol: "scope")
            Text(flight.summary)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            TelemetryGrid(items: [
                TelemetryItem(label: "Target", value: flight.launchDate.formattedLaunchDate(usesUTC: usesUTC), systemImage: "calendar"),
                TelemetryItem(label: "Pad", value: "\(flight.padName), \(flight.launchSite)", systemImage: "mappin.and.ellipse"),
                TelemetryItem(
                    label: "Webcast",
                    value: flight.webcastLive ? "Live" : "Standby",
                    tint: flight.webcastLive ? StatusTint.failure.color : .white,
                    systemImage: "antenna.radiowaves.left.and.right"
                ),
                TelemetryItem(
                    label: "Probability",
                    value: flight.probability.map { "\($0)%" } ?? "—",
                    tint: flight.probability != nil ? StatusTint.go.color : .white,
                    systemImage: "percent"
                )
            ])
        }
        .padding(18)
        .starshipGlass(cornerRadius: Theme.Radius.lg)
    }
}

private struct FlightsView: View {
    let repository: FlightRepository
    let usesUTC: Bool

    var upcomingFlights: [StarshipFlight] {
        repository.flights.filter(\.isUpcoming)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FlightImageBackdrop(imageURL: repository.nextFlight?.imageURL)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if repository.isFirstLoad {
                            SkeletonCard(lines: 3)
                            SkeletonCard(lines: 2)
                            SkeletonCard(lines: 2)
                        } else {
                            if let warning = repository.sourceWarningMessage {
                                DataWarningBanner(message: warning)
                            }

                            if let nextFlight = repository.nextFlight {
                                NavigationLink {
                                    FlightDetailView(flight: nextFlight, usesUTC: usesUTC)
                                } label: {
                                    MainFlightCard(flight: nextFlight, usesUTC: usesUTC)
                                }
                                .buttonStyle(CardButtonStyle())
                            }

                            if let forecast = FlightForecast(flights: repository.flights) {
                                ForecastCard(forecast: forecast, usesUTC: usesUTC)
                            }

                            FlightSection(title: "Upcoming", flights: upcomingFlights, usesUTC: usesUTC)
                            FlightSection(title: "Previous tests", flights: repository.pastFlights, usesUTC: usesUTC)
                        }
                    }
                    .padding(20)
                }
                .refreshable {
                    await repository.refresh(minInterval: 60)
                }
            }
            .navigationTitle("Flights")
            .refreshingToolbar(isLoading: repository.isLoading)
        }
    }
}

private struct MainFlightCard: View {
    let flight: StarshipFlight
    let usesUTC: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Next Launch")
                    .eyebrowStyle(color: Theme.accent)
                Spacer()
                StatusTag(status: flight.status)
            }
            Text(flight.name)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            TelemetryGrid(items: [
                TelemetryItem(label: "Target", value: flight.launchDate.formattedLaunchDate(usesUTC: usesUTC), systemImage: "calendar"),
                TelemetryItem(label: "Pad", value: flight.padName, systemImage: "scope")
            ])
            Text(flight.summary)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.66))
                .lineLimit(4)
        }
        .padding(18)
        .starshipGlass(cornerRadius: Theme.Radius.lg)
    }
}

private extension StarshipFlight {
    var starshipFlightNumber: Int? {
        guard let range = name.range(of: #"(?:Flight|IFT)[\s-]*(\d+)"#, options: [.regularExpression, .caseInsensitive]) else {
            return nil
        }
        let match = String(name[range])
        let digits = match.filter(\.isNumber)
        return Int(digits)
    }

    var shareText: String {
        var lines = [name]
        if let launchDate {
            lines.append("Targeting \(launchDate.formatted(date: .abbreviated, time: .shortened))")
        }
        lines.append("\(padName), \(launchSite)")
        if let sourceURL {
            lines.append(sourceURL.absoluteString)
        }
        lines.append("via Starship Watcher")
        return lines.joined(separator: "\n")
    }
}

private struct FlightForecast {
    let flightNumber: Int
    let windowStart: Date?
    let windowEnd: Date?
    let confidence: String
    let basis: String

    init?(flights: [StarshipFlight]) {
        let numberedFlights = flights.compactMap { flight -> (number: Int, date: Date?)? in
            guard let number = flight.starshipFlightNumber else { return nil }
            return (number, flight.launchDate)
        }
        guard let highestNumber = numberedFlights.map(\.number).max() else { return nil }

        flightNumber = highestNumber + 1

        let latestKnownDate = numberedFlights
            .compactMap(\.date)
            .max()

        if let latestKnownDate {
            windowStart = Calendar.current.date(byAdding: .day, value: 45, to: latestKnownDate)
            windowEnd = Calendar.current.date(byAdding: .day, value: 110, to: latestKnownDate)
        } else {
            windowStart = nil
            windowEnd = nil
        }

        confidence = "Low"
        basis = "Estimated from recent Starship flight numbering and broad test cadence. This is not confirmed launch data."
    }
}

private struct ForecastCard: View {
    let forecast: FlightForecast
    let usesUTC: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionRule(title: "Forecast", symbol: "chart.line.uptrend.xyaxis")
                MetaTag(text: "Speculative", tint: StatusTint.caution.color)
            }

            Text("Starship Flight \(forecast.flightNumber)")
                .font(.title2.bold())
                .foregroundStyle(.white)

            TelemetryGrid(items: [
                TelemetryItem(label: "Est. Window", value: forecastWindowText, tint: StatusTint.caution.color, systemImage: "calendar"),
                TelemetryItem(label: "Confidence", value: forecast.confidence, systemImage: "gauge.with.dots.needle.33percent")
            ])

            Text(forecast.basis)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .starshipGlass(cornerRadius: 22)
        .accessibilityElement(children: .combine)
    }

    private var forecastWindowText: String {
        guard let start = forecast.windowStart, let end = forecast.windowEnd else {
            return "Unknown"
        }
        let startText = start.formatted(.dateTime.month(.abbreviated).day())
        let endText = end.formatted(.dateTime.month(.abbreviated).day().year())
        return "\(startText)-\(endText)"
    }
}

private struct FlightSection: View {
    let title: String
    let flights: [StarshipFlight]
    let usesUTC: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionRule(title: title)
                .padding(.horizontal, 2)

            if flights.isEmpty {
                Text("No records available.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .starshipGlass(cornerRadius: Theme.Radius.md)
            } else {
                ForEach(flights) { flight in
                    NavigationLink {
                        FlightDetailView(flight: flight, usesUTC: usesUTC)
                    } label: {
                        FlightRow(flight: flight, usesUTC: usesUTC)
                    }
                    .buttonStyle(CardButtonStyle())
                }
            }
        }
    }
}

private struct FlightRow: View {
    let flight: StarshipFlight
    let usesUTC: Bool

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(flight.launchDate?.formatted(.dateTime.month(.abbreviated)) ?? "TBD")
                    .font(.caption2.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.accent)
                Text(flight.launchDate?.formatted(.dateTime.day()) ?? "--")
                    .font(.title2.bold())
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            .frame(width: 58, height: 62)
            .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text(flight.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    StatusTag(status: flight.status, compact: true)
                }
                Text(flight.launchDate.formattedLaunchDate(usesUTC: usesUTC))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.66))
                Label(flight.launchSite, systemImage: "mappin.and.ellipse")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
            }
        }
        .padding(14)
        .starshipGlass(cornerRadius: Theme.Radius.md)
    }
}

private struct FlightDetailView: View {
    let flight: StarshipFlight
    let usesUTC: Bool

    var body: some View {
        ZStack {
            FlightImageBackdrop(imageURL: flight.imageURL)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            StatusTag(status: flight.status)
                            MetaTag(text: flight.vehicle, systemImage: "airplane.departure")
                        }
                        Text(flight.name)
                            .font(.title.bold())
                            .foregroundStyle(.white)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(flight.summary)
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.72))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .starshipGlass(cornerRadius: Theme.Radius.lg)

                    TelemetryGrid(items: [
                        TelemetryItem(label: "Target", value: flight.launchDate.formattedLaunchDate(usesUTC: usesUTC), systemImage: "calendar"),
                        TelemetryItem(label: "Pad", value: flight.padName, systemImage: "scope"),
                        TelemetryItem(label: "Site", value: flight.launchSite, systemImage: "mappin.and.ellipse"),
                        TelemetryItem(
                            label: "Source",
                            value: flight.sourceURL == nil ? "Unavailable" : "Available",
                            tint: flight.sourceURL == nil ? .white : StatusTint.go.color,
                            systemImage: "link"
                        )
                    ])

                    HStack(spacing: 12) {
                        if let sourceURL = flight.sourceURL {
                            Link(destination: sourceURL) {
                                Label(flight.webcastLive ? "Watch Live" : "Open Source", systemImage: flight.webcastLive ? "play.rectangle.fill" : "safari")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        Link(destination: URL(string: "https://www.spacex.com/launches")!) {
                            Label("SpaceX Launches", systemImage: "paperplane.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .tint(.white)

                    MissionSummaryView(flight: flight, usesUTC: usesUTC)

                    VStack(alignment: .leading, spacing: 12) {
                        SectionRule(title: "Mission Events", symbol: "point.3.connected.trianglepath.dotted")
                        TimelineView(.periodic(from: .now, by: 1)) { timeline in
                            let events = flight.timeline
                            VStack(spacing: 12) {
                                ForEach(events.indices, id: \.self) { index in
                                    MissionEventRow(
                                        event: events[index],
                                        state: events.missionState(for: index, now: timeline.date),
                                        usesUTC: usesUTC
                                    )
                                }
                            }
                        }
                    }
                    .padding(18)
                    .starshipGlass(cornerRadius: 22)
                }
                .padding(20)
            }
        }
        .navigationTitle("Flight")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: flight.shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
                .tint(.white)
            }
        }
    }
}

private struct MissionScreen: View {
    let repository: FlightRepository
    let usesUTC: Bool

    private var flight: StarshipFlight? { repository.nextFlight }

    var body: some View {
        NavigationStack {
            ZStack {
                FlightImageBackdrop(imageURL: flight?.imageURL)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if repository.isFirstLoad {
                            SkeletonCard(lines: 3)
                            SkeletonCard(lines: 4)
                        } else if let flight {
                            MissionHeaderView(flight: flight)

                            if let warning = repository.sourceWarningMessage {
                                DataWarningBanner(message: warning)
                            }

                            MissionTelemetryPanel(flight: flight)

                            VStack(alignment: .leading, spacing: 14) {
                                SectionRule(title: "Sequence", symbol: "list.number")
                                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                                    let events = flight.timeline
                                    VStack(spacing: 14) {
                                        ForEach(events.indices, id: \.self) { index in
                                            MissionEventRow(
                                                event: events[index],
                                                state: events.missionState(for: index, now: timeline.date),
                                                usesUTC: usesUTC
                                            )
                                        }
                                    }
                                }
                            }
                        } else {
                            EmptyFlightView()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
                }
                .refreshable {
                    await repository.refresh(minInterval: 60)
                }
            }
            .navigationTitle("Mission")
            .refreshingToolbar(isLoading: repository.isLoading)
            .task(id: flight?.id) {
                await refreshDuringActiveMission()
            }
        }
    }

    private func refreshDuringActiveMission() async {
        while !Task.isCancelled, shouldRefreshLiveMission {
            // Every 6 min keeps this under Launch Library's ~15 requests/hour.
            try? await Task.sleep(for: .seconds(6 * 60))
            if !Task.isCancelled {
                await repository.refresh(minInterval: 5 * 60)
            }
        }
    }

    private var shouldRefreshLiveMission: Bool {
        guard let launchDate = flight?.launchDate else { return false }
        let now = Date()
        return now >= launchDate.addingTimeInterval(-3 * 60 * 60) && now <= launchDate.addingTimeInterval(2 * 60 * 60)
    }

}

private extension Array where Element == FlightEvent {
    func missionState(for index: Int, now: Date) -> MissionEventState {
        guard indices.contains(index), let targetDate = self[index].targetDate else { return .pending }
        let nextDate = dropFirst(index + 1).first?.targetDate

        if let nextDate, now >= targetDate, now < nextDate {
            return .current
        }
        if now >= targetDate {
            return .complete
        }
        return .pending
    }

    /// Index into `FlightPhase.allCases` for the most recently started event's phase.
    func currentPhaseIndex(now: Date) -> Int? {
        let started = filter { ($0.targetDate ?? .distantFuture) <= now }
        guard let last = started.last else { return nil }
        return FlightPhase.allCases.firstIndex(of: last.phase)
    }

    /// The next event that has not yet occurred.
    func nextEvent(now: Date) -> FlightEvent? {
        first { ($0.targetDate ?? .distantPast) > now }
    }
}

private struct MissionTelemetryPanel: View {
    let flight: StarshipFlight

    var body: some View {
        let events = flight.timeline
        VStack(alignment: .leading, spacing: 16) {
            SectionRule(title: "Telemetry", symbol: "waveform.path.ecg")
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                let now = timeline.date
                let activeIndex = events.currentPhaseIndex(now: now)
                let next = events.nextEvent(now: now)
                VStack(spacing: 16) {
                    PhaseProgressBar(activeIndex: activeIndex)
                    TelemetryGrid(items: [
                        TelemetryItem(
                            label: "Phase",
                            value: activeIndex.map { FlightPhase.allCases[$0].rawValue } ?? "Pre-count",
                            tint: activeIndex == nil ? .white : Theme.accent,
                            systemImage: "circle.dotted"
                        ),
                        TelemetryItem(label: "Liftoff", value: Countdown.text(to: flight.launchDate, now: now), tint: .white, systemImage: "flame"),
                        TelemetryItem(label: "Next Event", value: next?.title ?? "Sequence complete", systemImage: "forward.end.fill"),
                        TelemetryItem(label: "Event In", value: next.flatMap { Countdown.text(to: $0.targetDate, now: now) } ?? "—", systemImage: "timer")
                    ])
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .starshipGlass(cornerRadius: Theme.Radius.lg)
    }
}

private struct MissionHeaderView: View {
    let flight: StarshipFlight

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Live Mission Sequence")
                .eyebrowStyle(color: Theme.accent)
            Text(flight.name)
                .font(.title.bold())
                .foregroundStyle(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text("Events track the live countdown and status refreshes automatically during the active flight window.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                StatusTag(status: flight.status)
                if flight.webcastLive {
                    MetaTag(text: "Live Webcast", systemImage: "play.rectangle.fill", tint: StatusTint.failure.color)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .starshipGlass(cornerRadius: Theme.Radius.lg)
    }
}

private enum MissionEventState: Equatable {
    case pending
    case current
    case complete

    var label: String {
        switch self {
        case .pending: "Pending"
        case .current: "Active"
        case .complete: "Complete"
        }
    }

    var opacity: Double {
        switch self {
        case .pending: 0.56
        case .current: 1.0
        case .complete: 0.78
        }
    }

    var symbol: String {
        switch self {
        case .pending: "circle"
        case .current: "largecircle.fill.circle"
        case .complete: "checkmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .pending: .white.opacity(0.56)
        case .current: StatusTint.inFlight.color
        case .complete: StatusTint.go.color
        }
    }
}

private struct MissionEventRow: View {
    let event: FlightEvent
    let state: MissionEventState
    let usesUTC: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 8) {
                Image(systemName: state.symbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(state.tint)
                    .frame(width: 22, height: 22)
                    .symbolEffect(.pulse, isActive: state == .current)
                Rectangle()
                    .fill(.white.opacity(0.18))
                    .frame(width: 2, height: 78)
            }
            .frame(width: 32)
            .padding(.top, 16)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(event.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Text(event.targetDate.formattedTime(usesUTC: usesUTC))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.66))
                        .lineLimit(1)
                }

                Text(event.detail)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Text(state.label)
                        .foregroundStyle(state.tint)
                    Text(event.phase.rawValue)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .font(.caption.weight(.black))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .starshipGlass(cornerRadius: 18)
            .opacity(state.opacity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct NewsView: View {
    let repository: NewsRepository
    let imageURL: URL?

    var body: some View {
        NavigationStack {
            ZStack {
                FlightImageBackdrop(imageURL: imageURL)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ScreenHeader(
                            eyebrow: "Feed",
                            title: "News",
                            subtitle: "Latest Starship and SpaceX coverage from Spaceflight News."
                        )

                        if let errorMessage = repository.errorMessage {
                            InlineNotice(message: errorMessage)
                        }

                        if repository.isFirstLoad {
                            ForEach(0..<5, id: \.self) { _ in
                                NewsSkeletonRow()
                            }
                        } else if repository.articles.isEmpty {
                            EmptyNewsView()
                        } else {
                            ForEach(repository.articles) { article in
                                NavigationLink {
                                    NewsArticleDetailView(article: article, relatedArticles: relatedArticles(for: article))
                                } label: {
                                    NewsArticleRow(article: article)
                                }
                                .buttonStyle(CardButtonStyle())
                            }
                        }
                    }
                    .padding(20)
                }
                .refreshable {
                    await repository.refresh()
                }
            }
            .navigationTitle("News")
            .refreshingToolbar(isLoading: repository.isLoading)
            .sensoryFeedback(.success, trigger: repository.lastUpdated)
        }
    }

    private func relatedArticles(for article: StarshipNewsArticle) -> [StarshipNewsArticle] {
        repository.articles
            .filter { $0.id != article.id && ($0.source == article.source || $0.title.localizedCaseInsensitiveContains("starship")) }
            .prefix(3)
            .map { $0 }
    }
}

private struct NewsArticleRow: View {
    let article: StarshipNewsArticle

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            AsyncImage(url: article.imageURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "newspaper")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.72))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.white.opacity(0.1))
                }
            }
            .frame(width: 86, height: 86)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(article.source)
                    .eyebrowStyle(color: Theme.accent)
                Text(article.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(3)
                Text(article.summary)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)
                Text(article.publishedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .starshipGlass(cornerRadius: Theme.Radius.md)
    }
}

private struct NewsArticleDetailView: View {
    let article: StarshipNewsArticle
    let relatedArticles: [StarshipNewsArticle]

    var body: some View {
        ZStack {
            FlightImageBackdrop(imageURL: article.imageURL)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    AsyncImage(url: article.imageURL) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "newspaper")
                                .font(.largeTitle)
                                .foregroundStyle(.white.opacity(0.72))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(.white.opacity(0.08))
                        }
                    }
                    .frame(height: 196)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(alignment: .bottomLeading) {
                        LinearGradient(colors: [.clear, .black.opacity(0.82)], startPoint: .top, endPoint: .bottom)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(article.source)
                            .eyebrowStyle(color: Theme.accent)
                        Text(article.title)
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .lineLimit(4)
                            .minimumScaleFactor(0.82)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(article.publishedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .starshipGlass(cornerRadius: Theme.Radius.lg)

                    VStack(alignment: .leading, spacing: 12) {
                        SectionRule(title: "Story", symbol: "text.alignleft")
                        Text(article.summary)
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.78))
                            .fixedSize(horizontal: false, vertical: true)
                        Link(destination: article.url) {
                            Label("Read Full Article", systemImage: "safari")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(CardButtonStyle())
                        .foregroundStyle(.black)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(18)
                    .starshipGlass(cornerRadius: 22)

                    if !relatedArticles.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionRule(title: "More Coverage", symbol: "photo.on.rectangle")
                                .padding(.horizontal, 2)
                            ForEach(relatedArticles) { relatedArticle in
                                Link(destination: relatedArticle.url) {
                                    NewsArticleRow(article: relatedArticle)
                                }
                                .buttonStyle(CardButtonStyle())
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Article")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct EmptyNewsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "newspaper")
                .font(.largeTitle)
            Text("No saved news")
                .font(.title3.bold())
            Text("Pull to refresh when Spaceflight News is reachable.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .starshipGlass(cornerRadius: 22)
    }
}

private struct SettingsView: View {
    @Binding var usesUTC: Bool
    @Binding var notificationsEnabled: Bool
    @Binding var liveActivityEnabled: Bool
    @Binding var highContrastTelemetry: Bool
    @Binding var activityLeadHours: Int
    @Binding var backendCacheURL: String
    let dataSource: String
    let lastUpdated: Date?
    let imageURL: URL?

    var body: some View {
        NavigationStack {
            ZStack {
                FlightImageBackdrop(imageURL: imageURL)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ScreenHeader(
                            eyebrow: "Configuration",
                            title: "Settings",
                            subtitle: "Tune alerts, countdowns, and display for how you follow launches."
                        )

                        SettingsPanel(title: "Time", symbol: "clock") {
                            SettingsToggleRow(
                                title: "Use UTC",
                                subtitle: "Show launch windows and target times in coordinated universal time.",
                                isOn: $usesUTC
                            )
                            SettingsPickerRow(title: "Live Activity starts", selection: $activityLeadHours)
                        }

                        SettingsPanel(title: "Alerts", symbol: "bell") {
                            SettingsToggleRow(
                                title: "Launch reminders",
                                subtitle: "Notify before major countdown milestones and livestream windows.",
                                isOn: $notificationsEnabled
                            )
                            SettingsToggleRow(
                                title: "Live Activity",
                                subtitle: "Pin the countdown to the Lock Screen automatically. Start it any time in the last 8h from the widget or Control Center.",
                                isOn: $liveActivityEnabled
                            )
                        }

                        SettingsPanel(title: "Display", symbol: "circle.lefthalf.filled") {
                            SettingsToggleRow(
                                title: "High contrast",
                                subtitle: "Use stronger labels and telemetry contrast in flight views.",
                                isOn: $highContrastTelemetry
                            )
                        }

                        SettingsPanel(title: "Status", symbol: "checkmark.seal") {
                            SettingsValueRow(title: "Last refreshed", value: lastUpdated.formattedLaunchDate(usesUTC: usesUTC))
                            SettingsValueRow(title: "Offline backup", value: backupStatusText)
                        }

                        SettingsPanel(title: "About", symbol: "info.circle") {
                            SettingsValueRow(title: "App", value: "Starship Watcher")
                            SettingsValueRow(title: "Version", value: appVersion)
                            SettingsValueRow(title: "Focus", value: "Starship flights and test events")
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var backupStatusText: String {
        backendCacheURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Standard" : "Ready"
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

private struct SettingsPanel<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionRule(title: title, symbol: symbol)
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .starshipGlass(cornerRadius: 20)
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(Color(.systemGreen))
        .padding(12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SettingsPickerRow: View {
    let title: String
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text("iOS keeps a Live Activity for up to 8 hours, so it starts no earlier than T-8h.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Picker(title, selection: $selection) {
                Text("1h").tag(1)
                Text("3h").tag(3)
                Text("6h").tag(6)
                Text("8h").tag(8)
            }
            .pickerStyle(.menu)
            .tint(.white)
        }
        .padding(12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SettingsValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct FlightImageBackdrop: View {
    let imageURL: URL?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                SpaceBackdrop()
                    .frame(width: proxy.size.width, height: proxy.size.height)

                if let imageURL {
                    AsyncImage(url: imageURL) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .overlay(.black.opacity(0.52))
                    .overlay(
                        LinearGradient(colors: [.black.opacity(0.16), .black.opacity(0.86)], startPoint: .top, endPoint: .bottom)
                    )
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
    }
}

private struct SpaceBackdrop: View {
    var body: some View {
        Theme.backgroundGradient
            .overlay(alignment: .top) {
                RadialGradient(
                    colors: [StatusTint.inFlight.color.opacity(0.12), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 420
                )
                .blendMode(.screen)
            }
            .overlay(StarField())
    }
}

private struct StarField: View {
    private struct Star: Identifiable {
        let id = UUID()
        let point: CGPoint
        let size: CGFloat
        let baseOpacity: Double
        let twinkleSpeed: Double
        let phase: Double
    }

    private let stars: [Star] = {
        var generator = SystemRandomNumberGenerator()
        return (0..<70).map { _ in
            Star(
                point: CGPoint(x: .random(in: 0...1, using: &generator), y: .random(in: 0...1, using: &generator)),
                size: .random(in: 1...2.6, using: &generator),
                baseOpacity: .random(in: 0.25...0.85, using: &generator),
                twinkleSpeed: .random(in: 0.6...1.8, using: &generator),
                phase: .random(in: 0...(2 * .pi), using: &generator)
            )
        }
    }()

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 0.2)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    for star in stars {
                        let twinkle = 0.5 + 0.5 * sin(t * star.twinkleSpeed + star.phase)
                        let opacity = star.baseOpacity * (0.55 + 0.45 * twinkle)
                        let rect = CGRect(
                            x: star.point.x * size.width,
                            y: star.point.y * size.height,
                            width: star.size,
                            height: star.size
                        )
                        context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
    }
}

private struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

private struct DataWarningBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(StatusTint.caution.color)
            Text(message)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StatusTint.caution.color.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(StatusTint.caution.color.opacity(0.3), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct InlineNotice: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.circle")
            .font(.footnote)
            .foregroundStyle(.white)
            .fixedSize(horizontal: false, vertical: true)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .starshipGlass(cornerRadius: Theme.Radius.md)
    }
}

private struct LastUpdatedFooter: View {
    let date: Date?
    let source: String
    let usesUTC: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.2.circlepath")
            Text(updatedText)
            Text("·")
            Text(source)
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }

    private var updatedText: String {
        guard let date else { return "Not yet refreshed" }
        return "Updated \(date.formatted(.relative(presentation: .named)))"
    }
}

private extension View {
    /// Adds a subtle progress indicator to the navigation bar while a repository refreshes.
    func refreshingToolbar(isLoading: Bool) -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                        .transition(.opacity)
                }
            }
        }
    }
}

private struct EmptyFlightView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.largeTitle)
            Text("No Starship flight data")
                .font(.title3.bold())
            Text("Refresh again when the launch provider is reachable.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .starshipGlass(cornerRadius: 22)
    }
}

private extension Optional where Wrapped == Date {
    func formattedLaunchDate(usesUTC: Bool) -> String {
        guard let self else { return "Date pending" }
        return self.formattedLaunchDate(usesUTC: usesUTC)
    }

    func formattedTime(usesUTC: Bool) -> String {
        guard let self else { return "TBD" }
        return self.formattedTime(usesUTC: usesUTC)
    }
}

private extension Date {
    func formattedLaunchDate(usesUTC: Bool) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = usesUTC ? TimeZone(secondsFromGMT: 0) : .current
        let suffix = usesUTC ? " UTC" : ""
        return formatter.string(from: self) + suffix
    }

    func formattedTime(usesUTC: Bool) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.timeZone = usesUTC ? TimeZone(secondsFromGMT: 0) : .current
        let suffix = usesUTC ? " UTC" : ""
        return formatter.string(from: self) + suffix
    }
}

private extension FlightPhase {
    var color: Color {
        switch self {
        case .preflight: return .white.opacity(0.72)
        case .launch: return .white
        case .ascent: return .white.opacity(0.86)
        case .booster: return .white.opacity(0.64)
        case .ship: return .white.opacity(0.78)
        }
    }
}

#Preview {
    ContentView()
}
