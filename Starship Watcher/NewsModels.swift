import Foundation

struct StarshipNewsArticle: Identifiable, Codable, Hashable {
    let id: Int
    let title: String
    let summary: String
    let source: String
    let publishedAt: Date
    let url: URL
    let imageURL: URL?
}
