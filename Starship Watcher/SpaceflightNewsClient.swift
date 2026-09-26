import Foundation

struct SpaceflightNewsClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = ISO8601DateFormatter.newsWithFractionalSeconds.date(from: value) ?? ISO8601DateFormatter.news.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid news date: \(value)")
        }
    }

    func fetchStarshipNews() async throws -> [StarshipNewsArticle] {
        var components = URLComponents(string: "https://api.spaceflightnewsapi.net/v4/articles/")!
        components.queryItems = [
            URLQueryItem(name: "search", value: "Starship SpaceX"),
            URLQueryItem(name: "limit", value: "20"),
            URLQueryItem(name: "ordering", value: "-published_at")
        ]
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue("Starship Watcher iOS", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        return try decoder.decode(SpaceflightNewsResponse.self, from: data)
            .results
            .map(StarshipNewsArticle.init(response:))
    }
}

private extension StarshipNewsArticle {
    init(response: SpaceflightNewsArticle) {
        self.id = response.id
        self.title = response.title
        self.summary = response.summary.cleanedNewsText
        self.source = response.newsSite
        self.publishedAt = response.publishedAt
        self.url = response.url
        self.imageURL = response.imageURL
    }
}

private struct SpaceflightNewsResponse: Decodable {
    let results: [SpaceflightNewsArticle]
}

private struct SpaceflightNewsArticle: Decodable {
    let id: Int
    let title: String
    let url: URL
    let imageURL: URL?
    let newsSite: String
    let summary: String
    let publishedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case url
        case imageURL = "image_url"
        case newsSite = "news_site"
        case summary
        case publishedAt = "published_at"
    }
}

private extension ISO8601DateFormatter {
    static let news: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let newsWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private extension String {
    var cleanedNewsText: String {
        replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
