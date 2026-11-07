import Foundation

/// On-disk flight cache in the app group, written by the app and read by the widget.
struct CachedFlights: Codable {
    let lastUpdated: Date
    let flights: [StarshipFlight]
}

enum FlightCache {
    private static var url: URL {
        SharedAppGroup.cacheURL(fileName: "starship-flights-cache.json")
    }

    static func load() -> CachedFlights? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder.starship.decode(CachedFlights.self, from: data)
    }

    static func save(_ flights: [StarshipFlight]) throws {
        let cached = CachedFlights(lastUpdated: .now, flights: flights)
        let data = try JSONEncoder.starship.encode(cached)
        try data.write(to: url, options: [.atomic])
    }
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
