import Foundation

struct LaunchLibraryClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = ISO8601DateFormatter.launchLibraryWithFractionalSeconds.date(from: value) ?? ISO8601DateFormatter.launchLibrary.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(value)")
        }
    }

    func fetchStarshipFlights() async throws -> [StarshipFlight] {
        async let upcoming = fetch(path: "launch/upcoming/", ordering: "net")
        async let previous = fetch(path: "launch/previous/", ordering: "-net")
        let combined = try await upcoming + previous

        return combined
            .map(StarshipFlight.init(response:))
            .filter { flight in
                let searchable = "\(flight.name) \(flight.vehicle) \(flight.missionName)".lowercased()
                return searchable.contains("starship") || searchable.contains("super heavy")
            }
            .sorted { lhs, rhs in
                switch (lhs.launchDate, rhs.launchDate) {
                case let (left?, right?):
                    return left < right
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return lhs.name < rhs.name
                }
            }
    }

    private func fetch(path: String, ordering: String) async throws -> [LaunchLibraryLaunch] {
        var components = URLComponents(string: "https://ll.thespacedevs.com/2.0.0/\(path)")!
        components.queryItems = [
            URLQueryItem(name: "search", value: "Starship"),
            URLQueryItem(name: "limit", value: "20"),
            URLQueryItem(name: "ordering", value: ordering)
        ]

        guard let url = components.url else { return [] }
        var request = URLRequest(url: url)
        request.setValue("Starship Watcher iOS", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode(LaunchLibraryResponse.self, from: data).results
    }
}

private extension StarshipFlight {
    init(response: LaunchLibraryLaunch) {
        self.id = response.id
        self.name = response.name
        self.missionName = response.mission?.name ?? response.name
        self.summary = response.mission?.description?.cleanedLaunchText ?? "Mission details are pending from the launch data provider."
        self.vehicle = response.rocket?.configuration.fullName ?? response.rocket?.configuration.name ?? "Starship"
        self.status = LaunchStatus(name: response.status.name)
        self.launchDate = response.net
        self.windowStart = response.windowStart
        self.windowEnd = response.windowEnd
        self.launchSite = response.pad?.location.name ?? "Starbase, Texas"
        self.padName = response.pad?.name ?? "Launch Pad"
        self.probability = response.probability
        self.imageURL = response.image
        self.webcastLive = response.webcastLive ?? false
        self.sourceURL = response.url
    }
}

private struct LaunchLibraryResponse: Decodable {
    let results: [LaunchLibraryLaunch]
}

private struct LaunchLibraryLaunch: Decodable {
    let id: String
    let url: URL?
    let name: String
    let status: LaunchLibraryStatus
    let net: Date?
    let windowStart: Date?
    let windowEnd: Date?
    let probability: Int?
    let rocket: LaunchLibraryRocket?
    let mission: LaunchLibraryMission?
    let pad: LaunchLibraryPad?
    let webcastLive: Bool?
    let image: URL?

    enum CodingKeys: String, CodingKey {
        case id
        case url
        case name
        case status
        case net
        case windowStart = "window_start"
        case windowEnd = "window_end"
        case probability
        case rocket
        case mission
        case pad
        case webcastLive = "webcast_live"
        case image
    }
}

private struct LaunchLibraryStatus: Decodable {
    let name: String
}

private struct LaunchLibraryRocket: Decodable {
    let configuration: LaunchLibraryRocketConfiguration
}

private struct LaunchLibraryRocketConfiguration: Decodable {
    let name: String?
    let fullName: String?

    enum CodingKeys: String, CodingKey {
        case name
        case fullName = "full_name"
    }
}

private struct LaunchLibraryMission: Decodable {
    let name: String?
    let description: String?
}

private struct LaunchLibraryPad: Decodable {
    let name: String
    let location: LaunchLibraryLocation
}

private struct LaunchLibraryLocation: Decodable {
    let name: String
}

private extension ISO8601DateFormatter {
    static let launchLibrary: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let launchLibraryWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private extension String {
    var cleanedLaunchText: String {
        replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
