import SwiftUI

struct FlightsView: View {
    let repository: FlightRepository
    let usesUTC: Bool

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .blackScreen()
                .navigationTitle("FLIGHTS")
                .refreshingToolbar(isLoading: repository.isLoading)
        }
    }

    @ViewBuilder
    private var content: some View {
        if repository.isFirstLoad {
            FirstLoadView()
        } else if repository.flights.isEmpty {
            NoDataView(isLoading: repository.isLoading) {
                await repository.refresh(minInterval: 0)
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    FlightSection(title: "Upcoming", flights: repository.flights.filter(\.isUpcoming), usesUTC: usesUTC)
                    FlightSection(title: "Previous", flights: repository.pastFlights, usesUTC: usesUTC, showsYear: true)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 24)
            }
            .refreshable {
                await repository.refresh(minInterval: 60)
            }
        }
    }
}

private struct FlightSection: View {
    let title: String
    let flights: [StarshipFlight]
    let usesUTC: Bool
    var showsYear = false

    var body: some View {
        if !flights.isEmpty {
            Text(title)
                .caps(.caption, color: Theme.tertiary)
                .padding(.top, 24)
                .padding(.bottom, 6)

            ForEach(flights) { flight in
                NavigationLink {
                    FlightDetailView(flight: flight, usesUTC: usesUTC)
                } label: {
                    FlightRow(flight: flight, usesUTC: usesUTC, showsYear: showsYear)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct FlightRow: View {
    let flight: StarshipFlight
    let usesUTC: Bool
    let showsYear: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(flight.shortName)
                    .caps(.subheadline.weight(.light), tracking: 1.5)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Text(flight.dateText(usesUTC: usesUTC, year: showsYear))
                    .caps(.caption2, color: Theme.secondary, tracking: 1)
            }
            Spacer(minLength: 0)
            Text(flight.status.name)
                .caps(.caption2, color: flight.status.isAlert ? Theme.alert : Theme.secondary, tracking: 1)
                .lineLimit(1)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
        .contentShape(Rectangle())
    }
}

private struct FlightDetailView: View {
    let flight: StarshipFlight
    let usesUTC: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(flight.shortName)
                        .caps(.title2.weight(.light), tracking: 3)
                    Text(flight.status.displayName)
                        .caps(color: flight.status.color)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(flight.dateText(usesUTC: usesUTC, year: true))
                    Text(flight.placeText)
                    Text(flight.vehicle)
                }
                .caps(.caption, color: Theme.secondary, tracking: 1.5)

                Text(flight.summary)
                    .font(.body.weight(.light))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Theme.gutter)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .blackScreen()
        .navigationBarTitleDisplayMode(.inline)
    }
}
