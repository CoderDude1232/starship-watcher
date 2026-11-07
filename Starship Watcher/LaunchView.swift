import SwiftUI

/// The next flight: a full-screen hero over its photo, then mission text and the sequence on black.
struct LaunchView: View {
    let repository: FlightRepository
    let usesUTC: Bool

    private var flight: StarshipFlight? {
        repository.nextFlight
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                HeroPhoto(imageURL: flight?.imageURL)
                    .ignoresSafeArea()

                content
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                if let flight {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: flight.shareText) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Share flight")
                    }
                }
            }
            .refreshingToolbar(isLoading: repository.isLoading)
            .sensoryFeedback(.success, trigger: repository.lastUpdated)
            .task(id: flight?.id) {
                await refreshDuringActiveWindow()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if repository.isFirstLoad {
            FirstLoadView()
        } else if let flight {
            ScrollView {
                VStack(spacing: 0) {
                    // At least a full screen, and taller when large text needs it.
                    ZStack(alignment: .bottomLeading) {
                        Color.clear.containerRelativeFrame(.vertical)
                        LaunchHero(flight: flight, usesUTC: usesUTC)
                    }

                    LaunchDetails(flight: flight, repository: repository)
                }
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await repository.refresh(minInterval: 60)
            }
        } else {
            NoDataView(isLoading: repository.isLoading) {
                await repository.refresh(minInterval: 0)
            }
        }
    }

    private func refreshDuringActiveWindow() async {
        while !Task.isCancelled, flight?.isInActiveWindow() ?? false {
            // Every 6 min keeps this under Launch Library's ~15 requests/hour.
            try? await Task.sleep(for: .seconds(6 * 60))
            if !Task.isCancelled {
                await repository.refresh(minInterval: 5 * 60)
                // Push the current stage even when Launch Library data didn't change.
                #if canImport(ActivityKit)
                await StarshipActivityController().sync(flight: repository.nextFlight, canStart: false)
                #endif
            }
        }
    }
}

private struct LaunchHero: View {
    let flight: StarshipFlight
    let usesUTC: Bool

    @Environment(\.openURL) private var openURL
    @ScaledMetric(relativeTo: .largeTitle) private var clockSize: CGFloat = 46

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let now = timeline.date
            VStack(alignment: .leading, spacing: 18) {
                Text(flight.shortName)
                    .caps(.title3.weight(.light), tracking: 4)

                Text(clockText(now: now))
                    .font(.system(size: clockSize, weight: .light).monospacedDigit())
                    .textCase(.uppercase)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 14) {
                        Text(flight.status.displayName)
                            .caps(color: flight.status.color)
                        if flight.isLive(now: now) {
                            Text("● Live").caps(color: Theme.alert)
                        }
                    }
                    Text(flight.hasFirmDate ? "\(flight.dateText(usesUTC: usesUTC)) · \(flight.placeText)" : flight.placeText)
                        .caps(.caption, color: Theme.secondary, tracking: 1.5)
                }

                if flight.isInActiveWindow(now: now) {
                    StageTracker(flight: flight, now: now)
                        .padding(.top, 6)
                }

                if let streamURL = flight.liveStreamURL(now: now) {
                    Button("Watch Live") { openURL(streamURL) }
                        .buttonStyle(OutlineButtonStyle())
                        .padding(.top, 6)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 28)
        .accessibilityElement(children: .contain)
    }

    private func clockText(now: Date) -> String {
        switch flight.clock(now: now) {
        case .net(let text): text
        case .awaitingLiftoff: "Awaiting liftoff"
        case .countdown(let date), .elapsed(let date): Countdown.text(to: date, now: now)
        }
    }
}

private struct LaunchDetails: View {
    let flight: StarshipFlight
    let repository: FlightRepository

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Fades the fixed photo out as the details scroll up over it.
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: 120)

            VStack(alignment: .leading, spacing: 36) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Mission").caps(color: Theme.secondary)
                    Text(flight.summary)
                        .font(.body.weight(.light))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }

                SequenceList(flight: flight)

                VStack(alignment: .leading, spacing: 8) {
                    if let errorMessage = repository.errorMessage {
                        NoticeText(message: errorMessage)
                    }
                    if let lastUpdated = repository.lastUpdated {
                        Text("Updated \(lastUpdated.formatted(.relative(presentation: .named)))")
                            .caps(.caption2, color: Theme.tertiary, tracking: 1.5)
                    }
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 8)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Overscroll at the bottom must not reveal the photo.
            .background(Color.black.padding(.bottom, -1000))
        }
    }
}

/// Template offsets from recent flights, not live data, hence "Typical timeline".
/// The tracker sits here until launch nears, then moves up into the hero.
private struct SequenceList: View {
    let flight: StarshipFlight

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let events = flight.timeline
            // A placeholder date passing proves nothing, so soft dates mark no progress.
            let current = flight.hasFirmDate ? flight.currentEventIndex(in: events, now: timeline.date) : nil
            VStack(alignment: .leading, spacing: 36) {
                if !flight.isInActiveWindow(now: timeline.date) {
                    StageTracker(flight: flight, now: timeline.date)
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Sequence").caps(color: Theme.secondary)
                        Spacer()
                        Text("Typical timeline").caps(.caption2, color: Theme.tertiary, tracking: 1.5)
                    }

                    VStack(spacing: 0) {
                        ForEach(events.indices, id: \.self) { index in
                            SequenceRow(event: events[index], color: color(for: index, current: current))
                        }
                    }
                }
            }
        }
    }

    private func color(for index: Int, current: Int?) -> Color {
        guard let current else { return Theme.secondary }
        if index == current { return .white }
        return index < current ? Theme.tertiary : Theme.secondary
    }
}

private struct SequenceRow: View {
    let event: FlightEvent
    let color: Color

    @ScaledMetric(relativeTo: .footnote) private var offsetWidth: CGFloat = 86

    var body: some View {
        AdaptiveRow {
            Text(event.offsetText)
                .font(.footnote.weight(.light).monospacedDigit())
                .frame(minWidth: offsetWidth, alignment: .leading)
            Text(event.title)
                .font(.subheadline.weight(.light))
            Spacer(minLength: 0)
        }
        .foregroundStyle(color)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Fixed flight photo, darkened for the hero text. Plain black when there is no image.
private struct HeroPhoto: View {
    let imageURL: URL?
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { proxy in
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .overlay {
                        LinearGradient(
                            stops: [
                                .init(color: .black.opacity(0.45), location: 0),
                                .init(color: .black.opacity(0.2), location: 0.35),
                                .init(color: .black.opacity(0.95), location: 0.95)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .transition(.opacity)
            }
        }
        .accessibilityHidden(true)
        .task(id: imageURL) {
            guard let imageURL else {
                image = nil
                return
            }
            if let cached = BackdropImageLoader.shared.cachedImage(for: imageURL) {
                image = cached
                return
            }
            let loaded = await BackdropImageLoader.shared.image(for: imageURL)
            withAnimation(.easeOut(duration: 0.4)) { image = loaded }
        }
    }
}
