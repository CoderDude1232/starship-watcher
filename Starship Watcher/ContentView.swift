import SwiftUI

struct ContentView: View {
    @State private var repository = FlightRepository()
    @State private var newsRepository = NewsRepository()
    @AppStorage("usesUTC") private var usesUTC = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("liveActivityEnabled") private var liveActivityEnabled = true
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            LaunchView(repository: repository, usesUTC: usesUTC)
                .tabItem {
                    Label("Launch", systemImage: "timer")
                }

            FlightsView(repository: repository, usesUTC: usesUTC)
                .tabItem {
                    Label("Flights", systemImage: "list.bullet")
                }

            NewsView(repository: newsRepository)
                .tabItem {
                    Label("News", systemImage: "newspaper")
                }

            SettingsView(
                usesUTC: $usesUTC,
                notificationsEnabled: $notificationsEnabled,
                liveActivityEnabled: $liveActivityEnabled
            )
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .tint(.white)
        .task {
            await repository.refresh()
            await syncLiveActivity()
            await NotificationScheduler().sync(flight: repository.nextFlight)
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
        .onChange(of: notificationsEnabled) { _, _ in
            Task { await NotificationScheduler().sync(flight: repository.nextFlight) }
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
            Task {
                await syncLiveActivity()
                await NotificationScheduler().sync(flight: repository.nextFlight)
            }
        }
        .task(id: liveActivityMonitorID) {
            await monitorLiveActivityThresholds()
        }
    }

    private var liveActivityMonitorID: String {
        "\(repository.nextFlight?.id ?? "none")-\(repository.nextFlight?.launchDate?.timeIntervalSince1970 ?? 0)-\(liveActivityEnabled)"
    }

    private func syncLiveActivity() async {
        #if canImport(ActivityKit)
        await StarshipActivityController().sync(flight: repository.nextFlight, canStart: true)
        #endif
    }

    private func monitorLiveActivityThresholds() async {
        #if canImport(ActivityKit)
        guard liveActivityEnabled, let flight = repository.nextFlight, flight.hasFirmDate, let launchDate = flight.launchDate else { return }
        let start = StarshipActivityController.windowStart(for: launchDate)
        while !Task.isCancelled, start > .now {
            try? await Task.sleep(for: .seconds(min(max(start.timeIntervalSinceNow, 1), 60 * 60)))
        }
        await syncLiveActivity()
        #endif
    }
}

#Preview {
    ContentView()
}
