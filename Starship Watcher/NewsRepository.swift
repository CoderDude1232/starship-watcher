import Foundation
import Observation

@Observable
@MainActor
final class NewsRepository {
    private(set) var articles: [StarshipNewsArticle] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var lastUpdated: Date?

    private let client: SpaceflightNewsClient
    private let cacheURL: URL

    init(client: SpaceflightNewsClient? = nil) {
        self.client = client ?? SpaceflightNewsClient()
        self.cacheURL = URL.documentsDirectory.appending(path: "starship-news-cache.json")
        loadCachedArticles()
    }

    /// True during the first fetch when no cached articles exist — drives loading skeletons.
    var isFirstLoad: Bool {
        isLoading && articles.isEmpty
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetchedArticles = try await client.fetchStarshipNews()
            guard !fetchedArticles.isEmpty else {
                errorMessage = "No Starship news was returned. Showing saved articles."
                return
            }
            articles = fetchedArticles
            lastUpdated = .now
            saveCachedArticles(fetchedArticles)
        } catch {
            errorMessage = "Unable to refresh Spaceflight News. Showing saved articles."
        }
    }

    private func loadCachedArticles() {
        do {
            let data = try Data(contentsOf: cacheURL)
            let cached = try JSONDecoder.starship.decode(CachedNews.self, from: data)
            articles = cached.articles
            lastUpdated = cached.lastUpdated
        } catch {
            articles = []
        }
    }

    private func saveCachedArticles(_ articles: [StarshipNewsArticle]) {
        do {
            let cached = CachedNews(lastUpdated: .now, articles: articles)
            let data = try JSONEncoder.starship.encode(cached)
            try data.write(to: cacheURL, options: [.atomic])
        } catch {
            errorMessage = "Fresh news loaded, but cache storage failed."
        }
    }
}

private struct CachedNews: Codable {
    let lastUpdated: Date
    let articles: [StarshipNewsArticle]
}
