import SwiftUI

// MARK: - Status tag

/// Plain, native status indicator: a colored dot and label in the semantic status color.
/// No custom chip background — just standard Apple text and an SF Symbol.
struct StatusTag: View {
    let status: LaunchStatus
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "circle.fill")
                .font(.system(size: compact ? 6 : 7))
            Text(status.displayName)
                .font(compact ? .caption2 : .caption)
                .fontWeight(.semibold)
                .lineLimit(1)
        }
        .foregroundStyle(status.tint)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(status.displayName)")
    }
}

/// Plain native meta label (e.g. site, "Live", "Speculative") — an SF Symbol plus text.
struct MetaTag: View {
    let text: String
    var systemImage: String? = nil
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage).font(.caption2)
            }
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(tint)
        .lineLimit(1)
    }
}

// MARK: - Section rule

/// Eyebrow label followed by a hairline that runs to the trailing edge. Reads as an
/// engineered section divider rather than a generic bold `Label`.
struct SectionRule: View {
    let title: String
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            Label {
                Text(title)
            } icon: {
                if let symbol {
                    Image(systemName: symbol)
                }
            }
            .font(.headline)
            .foregroundStyle(.white)
            .fixedSize()

            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)
        }
    }
}

// MARK: - Telemetry grid

struct TelemetryItem: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    var tint: Color = .white
    var systemImage: String? = nil
}

/// A two-column instrument-panel readout. The 1pt gaps over a hairline background draw
/// the grid lines, giving a flight-console feel.
struct TelemetryGrid: View {
    let items: [TelemetryItem]

    private let columns = [
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 1) {
            ForEach(items) { item in
                TelemetryCell(item: item)
            }
        }
        .background(Theme.hairline)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        }
    }
}

private struct TelemetryCell: View {
    let item: TelemetryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                if let symbol = item.systemImage {
                    Image(systemName: symbol).font(.system(size: 9, weight: .bold))
                }
                Text(item.label).eyebrowStyle()
            }
            Text(item.value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(item.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.045))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.label): \(item.value)")
    }
}

// MARK: - Phase progress

/// Segmented mission-phase indicator: shows which flight phase is active.
struct PhaseProgressBar: View {
    let phases: [FlightPhase]
    let activeIndex: Int?

    init(activeIndex: Int?) {
        self.phases = FlightPhase.allCases
        self.activeIndex = activeIndex
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(phases.enumerated()), id: \.element) { index, phase in
                VStack(spacing: 6) {
                    Capsule()
                        .fill(fill(for: index))
                        .frame(height: 4)
                    Text(phase.rawValue)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(index == activeIndex ? Theme.accent : .white.opacity(0.4))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(activeIndex.map { "Current phase: \(phases[$0].rawValue)" } ?? "Mission not started")
    }

    private func fill(for index: Int) -> Color {
        guard let activeIndex else { return .white.opacity(0.14) }
        if index < activeIndex { return StatusTint.go.color.opacity(0.7) }
        if index == activeIndex { return Theme.accent }
        return .white.opacity(0.14)
    }
}

// MARK: - Skeleton loading

/// Shimmering placeholder block used to build first-load skeleton screens.
struct SkeletonBlock: View {
    var height: CGFloat = 16
    var width: CGFloat? = nil
    var cornerRadius: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let period = 1.4
                let t = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
                let travel = proxy.size.width + 160
                let offset = CGFloat(t) * travel - 80

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .overlay {
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.16), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 120)
                        .offset(x: offset - proxy.size.width / 2)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        }
        .frame(width: width, height: height)
    }
}

/// A single skeleton card approximating a content card while data loads.
struct SkeletonCard: View {
    var lines: Int = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                SkeletonBlock(height: 12, width: 70, cornerRadius: 4)
                Spacer()
                SkeletonBlock(height: 20, width: 64, cornerRadius: 6)
            }
            SkeletonBlock(height: 26, width: 200, cornerRadius: 6)
            ForEach(0..<lines, id: \.self) { index in
                SkeletonBlock(height: 12, width: index == lines - 1 ? 140 : nil, cornerRadius: 4)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .starshipGlass(cornerRadius: Theme.Radius.lg)
        .accessibilityLabel("Loading")
    }
}

/// Consistent screen header: accent eyebrow, expanded display title, muted subtitle.
struct ScreenHeader: View {
    var eyebrow: String
    var title: String
    var subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow).eyebrowStyle(color: Theme.accent)
            Text(title)
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .starshipGlass(cornerRadius: Theme.Radius.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }
}

/// Skeleton approximating a news row (thumbnail + text lines) during first load.
struct NewsSkeletonRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            SkeletonBlock(height: 86, width: 86, cornerRadius: 12)
            VStack(alignment: .leading, spacing: 8) {
                SkeletonBlock(height: 10, width: 70, cornerRadius: 4)
                SkeletonBlock(height: 16, cornerRadius: 5)
                SkeletonBlock(height: 12, cornerRadius: 4)
                SkeletonBlock(height: 12, width: 120, cornerRadius: 4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .starshipGlass(cornerRadius: Theme.Radius.md)
        .accessibilityLabel("Loading")
    }
}
