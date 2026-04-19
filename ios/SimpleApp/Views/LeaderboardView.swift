import SwiftUI

struct LeaderboardView: View {
    let viewModel: MarketViewModel
    @State private var tab: Tab = .markets

    enum Tab: String, CaseIterable {
        case markets = "Top Believed"
        case traders = "Top Traders"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                switch tab {
                case .markets: marketsContent
                case .traders: tradersContent
                }
            }
        }
        .navigationDestination(for: UUID.self) { id in
            MarketDetailView(marketId: id, viewModel: viewModel)
        }
    }

    // MARK: - Markets

    private var sortedMarkets: [Market] {
        viewModel.markets.sorted { $0.currentBelieve > $1.currentBelieve }
    }

    @ViewBuilder
    private var marketsContent: some View {
        if sortedMarkets.count >= 3 {
            topThreeMarkets
        }
        restOfMarkets
    }

    private var topThreeMarkets: some View {
        HStack(alignment: .bottom, spacing: 16) {
            podiumMarket(sortedMarkets[1], rank: 2, height: 80)
            podiumMarket(sortedMarkets[0], rank: 1, height: 100)
            podiumMarket(sortedMarkets[2], rank: 3, height: 65)
        }
        .padding()
        .padding(.top, 8)
    }

    private func podiumMarket(_ market: Market, rank: Int, height: CGFloat) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .top) {
                Color(.secondarySystemBackground)
                    .frame(width: 52, height: 52)
                    .overlay {
                        AsyncImage(url: URL(string: market.avatarURL)) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .allowsHitTesting(false)
                    }
                    .clipShape(Circle())

                if rank == 1 {
                    Image(systemName: "crown.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                        .offset(y: -14)
                }
            }

            Text(market.name)
                .font(.caption.bold())
                .lineLimit(1)

            Text("\(market.believePercentage)%")
                .font(.caption2.bold())
                .foregroundStyle(.green)

            RoundedRectangle(cornerRadius: 8)
                .fill(
                    rank == 1 ? Color.yellow.opacity(0.2) :
                    rank == 2 ? Color(.systemGray4) :
                    Color.orange.opacity(0.15)
                )
                .frame(height: height)
                .overlay {
                    Text("#\(rank)")
                        .font(.title3.bold())
                        .foregroundStyle(.secondary)
                }
        }
        .frame(maxWidth: .infinity)
    }

    private var restOfMarkets: some View {
        VStack(spacing: 0) {
            ForEach(Array(sortedMarkets.dropFirst(3).enumerated()), id: \.element.id) { index, market in
                NavigationLink(value: market.id) {
                    HStack(spacing: 14) {
                        Text("#\(index + 4)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 32)

                        Color(.secondarySystemBackground)
                            .frame(width: 40, height: 40)
                            .overlay {
                                AsyncImage(url: URL(string: market.avatarURL)) { phase in
                                    if let image = phase.image {
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } else {
                                        Image(systemName: "person.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .allowsHitTesting(false)
                            }
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(market.name)
                                .font(.subheadline.bold())
                                .foregroundStyle(.primary)
                            Text(market.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(market.believePercentage)%")
                                .font(.subheadline.bold())
                                .foregroundStyle(.green)
                            if market.change24h != 0 {
                                Text(String(format: "%+.1f%%", market.change24h))
                                    .font(.caption)
                                    .foregroundStyle(market.change24h >= 0 ? .green : .red)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                if index < sortedMarkets.count - 4 {
                    Divider()
                        .padding(.leading, 78)
                }
            }
        }
    }

    // MARK: - Traders

    @ViewBuilder
    private var tradersContent: some View {
        if viewModel.topTraders.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "person.3.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No traders yet")
                    .font(.subheadline.bold())
                Text("Be the first to make a trade.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(viewModel.topTraders.enumerated()), id: \.element.id) { index, trader in
                    traderRow(trader, rank: index + 1)
                    if index < viewModel.topTraders.count - 1 {
                        Divider().padding(.leading, 78)
                    }
                }
            }
            .padding(.top, 12)
        }
    }

    private func traderRow(_ trader: LiveTopTrader, rank: Int) -> some View {
        let isMe = trader.wallet == viewModel.wallet.publicAddress
        let displayName = trader.username.isEmpty ? truncate(trader.wallet) : trader.username
        return HStack(spacing: 14) {
            Text("#\(rank)")
                .font(.subheadline.bold())
                .foregroundStyle(rank <= 3 ? .yellow : .secondary)
                .frame(width: 32)

            Color(.secondarySystemBackground)
                .frame(width: 40, height: 40)
                .overlay {
                    if let url = URL(string: trader.avatarURL), !trader.avatarURL.isEmpty {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .allowsHitTesting(false)
                    } else {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(displayName)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    if isMe {
                        Text("YOU")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.18))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
                Text("\(trader.tradeCount) trade\(trader.tradeCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.2f SOL", trader.volume))
                    .font(.subheadline.bold())
                Text("volume")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func truncate(_ s: String) -> String {
        guard s.count > 10 else { return s }
        return "\(s.prefix(4))…\(s.suffix(4))"
    }
}
