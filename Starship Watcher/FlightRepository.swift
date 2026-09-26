import Foundation
import Observation

@Observable
@MainActor
final class FlightRepository {
    private(set) var flights: [StarshipFlight] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var lastUpdated: Date?

    private(set) var activeSource = "Saved cache"
    private(set) var sourceWarningMessage: String?

    private let backendClient: BackendLaunchClient
    private let client: LaunchLibraryClient
    private let fallbackClient: SpaceXFallbackClient
    private let cacheURL: URL

    init(backendClient: BackendLaunchClient? = nil, client: LaunchLibraryClient? = nil, fallbackClient: SpaceXFallbackClient? = nil) {
        self.backendClient = backendClient ?? BackendLaunchClient()
        self.client = client ?? LaunchLibraryClient()
        self.fallbackClient = fallbackClient ?? SpaceXFallbackClient()
        self.cacheURL = SharedAppGroup.cacheURL(fileName: "starship-flights-cache.json")
        loadCachedFlights()
        if flights.isEmpty {
            flights = Self.previewFlights
            activeSource = "Preview data"
            sourceWarningMessage = "Showing preview launch data. Flight details may be incorrect until a trusted launch source responds."
        }
    }

    /// True during the very first fetch when no trusted data has ever loaded — used to
    /// drive loading skeletons instead of flashing placeholder content.
    var isFirstLoad: Bool {
        isLoading && lastUpdated == nil
    }

    var nextFlight: StarshipFlight? {
        flights
            .filter(\.isUpcoming)
            .sorted { ($0.launchDate ?? .distantFuture) < ($1.launchDate ?? .distantFuture) }
            .first
    }

    var pastFlights: [StarshipFlight] {
        flights
            .filter { !$0.isUpcoming }
            .sorted { ($0.launchDate ?? .distantPast) > ($1.launchDate ?? .distantPast) }
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if await refreshFromBackend() {
            return
        }

        do {
            let fetchedFlights = try await client.fetchStarshipFlights()
            guard !fetchedFlights.isEmpty else {
                throw URLError(.zeroByteResource)
            }
            flights = fetchedFlights
            activeSource = "Launch Library 2"
            sourceWarningMessage = nil
            lastUpdated = .now
            saveCachedFlights(fetchedFlights)
        } catch {
            await refreshFromFallback()
        }
    }

    private func refreshFromBackend() async -> Bool {
        let rawEndpoint = UserDefaults.standard.string(forKey: "backendCacheURL") ?? ""
        guard let endpoint = URL(string: rawEndpoint), !rawEndpoint.isEmpty else { return false }

        do {
            let backendFlights = try await backendClient.fetchStarshipFlights(endpoint: endpoint)
            guard !backendFlights.isEmpty else { return false }
            flights = backendFlights
            activeSource = "Backend cache"
            sourceWarningMessage = nil
            lastUpdated = .now
            saveCachedFlights(backendFlights)
            return true
        } catch {
            return false
        }
    }

    private func refreshFromFallback() async {
        do {
            let fallbackFlights = try await fallbackClient.fetchStarshipFlights()
            guard !fallbackFlights.isEmpty else {
                errorMessage = "Launch Library is unavailable and the backup source has no Starship records. Showing saved data."
                return
            }
            flights = fallbackFlights
            activeSource = "SpaceXData backup"
            sourceWarningMessage = "Showing lower-confidence SpaceXData backup results because trusted launch sources are unavailable. Flight timing or status may be incorrect."
            lastUpdated = .now
            saveCachedFlights(fallbackFlights)
            errorMessage = nil
        } catch {
            errorMessage = "Launch Library and backup launch data are unavailable. Showing saved data."
        }
    }

    private func loadCachedFlights() {
        do {
            let data = try Data(contentsOf: cacheURL)
            let cached = try JSONDecoder.starship.decode(CachedFlights.self, from: data)
            flights = cached.flights
            activeSource = "Saved cache"
            sourceWarningMessage = "Showing saved launch data. Flight timing or status may be outdated until a trusted launch source refreshes."
            lastUpdated = cached.lastUpdated
        } catch {
            flights = []
        }
    }

    private func saveCachedFlights(_ flights: [StarshipFlight]) {
        do {
            let cached = CachedFlights(lastUpdated: .now, flights: flights)
            let data = try JSONEncoder.starship.encode(cached)
            try data.write(to: cacheURL, options: [.atomic])
        } catch {
            errorMessage = "Fresh launch data loaded, but cache storage failed."
        }
    }
}

private struct CachedFlights: Codable {
    let lastUpdated: Date
    let flights: [StarshipFlight]
}

extension FlightRepository {
    static let previewFlights: [StarshipFlight] = [
        StarshipFlight(
            id: "preview-flight-13",
            name: "Starship | Flight 13",
            missionName: "Integrated Flight Test",
            summary: "Starship and Super Heavy are preparing for another integrated flight test from Starbase. Real launch data will replace this preview when Launch Library responds.",
            vehicle: "Starship / Super Heavy",
            status: LaunchStatus(name: "To Be Confirmed"),
            launchDate: Calendar.current.date(byAdding: .day, value: 1, to: .now),
            windowStart: Calendar.current.date(byAdding: .day, value: 1, to: .now),
            windowEnd: Calendar.current.date(byAdding: .hour, value: 26, to: .now),
            launchSite: "Starbase, Texas, USA",
            padName: "Orbital Launch Mount",
            probability: nil,
            imageURL: nil,
            webcastLive: false,
            sourceURL: URL(string: "https://ll.thespacedevs.com/2.0.0/launch/upcoming/?search=Starship")
        )
    ]
}

extension JSONDecoder {
    static let starship: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension JSONEncoder {
    static let starship: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}
