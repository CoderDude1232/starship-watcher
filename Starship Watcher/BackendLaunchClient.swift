import Foundation

struct BackendLaunchClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder.starship
    }

    func fetchStarshipFlights(endpoint: URL?) async throws -> [StarshipFlight] {
        guard let endpoint else { return [] }
        var request = URLRequest(url: endpoint)
        request.setValue("Starship Watcher iOS", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        if let cached = try? decoder.decode(BackendFlightResponse.self, from: data) {
            return cached.flights
        }
        return try decoder.decode([StarshipFlight].self, from: data)
    }
}

private struct BackendFlightResponse: Decodable {
    let flights: [StarshipFlight]
}
