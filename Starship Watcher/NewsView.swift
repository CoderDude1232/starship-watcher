import SafariServices
import SwiftUI

struct NewsView: View {
    let repository: NewsRepository
    @State private var openArticle: StarshipNewsArticle?

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .blackScreen()
                .navigationTitle("NEWS")
                .refreshingToolbar(isLoading: repository.isLoading)
                .sheet(item: $openArticle) { article in
                    SafariView(url: article.url)
                        .ignoresSafeArea()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if repository.isFirstLoad {
            FirstLoadView()
        } else if repository.articles.isEmpty {
            NoDataView(title: "No news", isLoading: repository.isLoading) {
                await repository.refresh()
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if let errorMessage = repository.errorMessage {
                        NoticeText(message: errorMessage)
                            .padding(.vertical, 12)
                    }
                    ForEach(repository.articles) { article in
                        Button {
                            openArticle = article
                        } label: {
                            NewsRow(article: article)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 24)
            }
            .refreshable {
                await repository.refresh()
            }
        }
    }
}

private struct NewsRow: View {
    let article: StarshipNewsArticle

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            AsyncImage(url: article.imageURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.white.opacity(0.06)
                }
            }
            .frame(width: 72, height: 72)
            .clipped()
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text(article.title)
                    .font(.subheadline.weight(.light))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                Text("\(article.source) · \(article.publishedAt.formatted(.dateTime.month(.abbreviated).day()))")
                    .caps(.caption2, color: Theme.secondary, tracking: 1)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
