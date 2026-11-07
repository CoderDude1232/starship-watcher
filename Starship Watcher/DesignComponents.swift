import SwiftUI

/// Rectangular outline that inverts when pressed.
struct OutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .caps(.footnote, color: configuration.isPressed ? .black : .white, tracking: 3)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(configuration.isPressed ? Color.white : Color.clear)
            .overlay {
                Rectangle().strokeBorder(.white, lineWidth: 1)
            }
            .contentShape(Rectangle())
    }
}

/// Side by side, stacked at accessibility text sizes where a row no longer fits.
struct AdaptiveRow<Content: View>: View {
    var spacing: CGFloat = 16
    @ViewBuilder let content: Content

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: spacing))
        layout { content }
    }
}

/// Full-screen message with a retry, for when there is nothing to show.
struct NoDataView: View {
    var title = "No data"
    let isLoading: Bool
    let retry: () async -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text(title).caps(.title3.weight(.light), tracking: 4)
            Button("Retry") {
                Task { await retry() }
            }
            .buttonStyle(OutlineButtonStyle())
            .disabled(isLoading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Spinner for the first fetch, before there is anything to show.
struct FirstLoadView: View {
    var body: some View {
        ProgressView()
            .tint(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("Loading")
    }
}

/// Small grey line for refresh failures. Saved data stays on screen.
struct NoticeText: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(Theme.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    /// Pure black screen behind a tab.
    func blackScreen() -> some View {
        background(Color.black.ignoresSafeArea())
            .toolbarBackground(.black, for: .navigationBar)
    }

    /// Small progress indicator in the navigation bar during a refresh.
    func refreshingToolbar(isLoading: Bool) -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                }
            }
        }
    }
}
