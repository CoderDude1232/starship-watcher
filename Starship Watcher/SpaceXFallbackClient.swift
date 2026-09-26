import Foundation

struct SpaceXFallbackClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = ISO8601DateFormatter.spaceXWithFractionalSeconds.date(from: value) ?? ISO8601DateFormatter.spaceX.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid SpaceX date: \(value)")
        }
    }

    func fetchStarshipFlights() async throws -> [StarshipFlight] {
        async let upcoming = fetch(endpoint: "upcoming")
        async let past = fetch(endpoint: "past")
        let combined = try await upcoming + past

        return combined
            .filter { launch in
                let searchable = "\(launch.name) \(launch.details ?? "")".lowercased()
                return searchable.contains("starship") || searchable.contains("flight test")
            }
            .map(StarshipFlight.init(spaceX:))
            .sorted { lhs, rhs in
                switch (lhs.launchDate, rhs.launchDate) {
                case let (left?, right?): return left < right
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return lhs.name < rhs.name
                }
            }
    }

    private func fetch(endpoint: String) async throws -> [SpaceXLaunch] {
        let url = URL(string: "https://api.spacexdata.com/v5/launches/\(endpoint)")!
        var request = URLRequest(url: url)
        request.setValue("Starship Watcher iOS", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode([SpaceXLaunch].self, from: data)
    }
}

private extension StarshipFlight {
    init(spaceX launch: SpaceXLaunch) {
        self.id = "spacex-\(launch.id)"
        self.name = launch.name
        self.missionName = launch.name
        self.summary = launch.details?.cleanedSpaceXText ?? "SpaceX launch details are pending. This record is from the fallback SpaceXData source."
        self.vehicle = launch.name.lowercased().contains("starship") ? "Starship / Super Heavy" : "SpaceX vehicle"
        self.status = LaunchStatus(name: launch.upcoming ? "Upcoming" : launch.success == true ? "Complete" : "Unknown")
        self.launchDate = launch.dateUTC
        self.windowStart = launch.dateUTC
        self.windowEnd = launch.dateUTC?.addingTimeInterval(90 * 60)
        self.launchSite = "SpaceX launch site"
        self.padName = "Pad pending"
        self.probability = nil
        self.imageURL = launch.links.patch.large ?? launch.links.patch.small
        self.webcastLive = false
        self.sourceURL = launch.links.webcast
    }
}

private struct SpaceXLaunch: Decodable {
    let id: String
    let name: String
    let details: String?
    let dateUTC: Date?
    let upcoming: Bool
    let success: Bool?
    let links: SpaceXLinks

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case details
        case dateUTC = "date_utc"
        case upcoming
        case success
        case links
    }
}

private struct SpaceXLinks: Decodable {
    let patch: SpaceXPatch
    let webcast: URL?
}

private struct SpaceXPatch: Decodable {
    let small: URL?
    let large: URL?
}

private extension ISO8601DateFormatter {
    static let spaceX: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let spaceXWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private extension String {
    var cleanedSpaceXText: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
