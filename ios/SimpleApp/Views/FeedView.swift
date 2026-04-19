import SwiftUI

struct FeedView: View {
    let viewModel: MarketViewModel
    @State private var appeared: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                walletBanner
                if !viewModel.trendingMarkets.isEmpty {
                    trendingSection
                }
                categoryPicker
                marketsList
            }
        }
        .onAppear { appeared = true }
    }

    private var walletBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "wallet.bifold")
                .font(.title3)
                .foregroundStyle(.purple)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%.4f SOL", viewModel.wallet.tradingBalance))
                    .font(.subheadline.bold())
                Text(truncatedAddress(viewModel.wallet.publicAddress))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("50/50")
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.green.opacity(0.12))
                .foregroundStyle(.green)
                .clipShape(Capsule())
        }
        .padding(14)
        .padding(.horizontal, 2)
    }

    private func truncatedAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }

    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Hot Right Now")
                    .font(.title3.bold())
                Spacer()
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(viewModel.trendingMarkets) { market in
                        NavigationLink(value: market.id) {
                            TrendingCardView(market: market, viewModel: viewModel)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .contentMargins(.horizontal, 16)
            .scrollIndicators(.hidden)
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(MarketCategory.allCases, id: \.self) { category in
                    Button {
                        withAnimation(.snappy) {
                            viewModel.selectedCategory = category
                        }
                    } label: {
                        Text(category.rawValue)
                            .font(.subheadline.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                viewModel.selectedCategory == category
                                ? Color(.label)
                                : Color(.tertiarySystemFill)
                            )
                            .foregroundStyle(
                                viewModel.selectedCategory == category
                                ? Color(.systemBackground)
                                : .primary
                            )
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .contentMargins(.horizontal, 16)
        .scrollIndicators(.hidden)
        .padding(.vertical, 16)
    }

    private var marketsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Markets")
                    .font(.title3.bold())
                Spacer()
                Text("\(viewModel.filteredMarkets.count) active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.filteredMarkets.enumerated()), id: \.element.id) { index, market in
                    NavigationLink(value: market.id) {
                        MarketCardView(market: market, viewModel: viewModel)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 12)
                            .animation(.spring(response: 0.4).delay(Double(index) * 0.04), value: appeared)
                    }
                    .buttonStyle(.plain)

                    if index < viewModel.filteredMarkets.count - 1 {
                        Divider()
                            .padding(.leading, 86)
                    }
                }
            }
        }
    }
}

struct TrendingCardView: View {
    let market: Market
    let viewModel: MarketViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Color(.tertiarySystemBackground)
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
                        .lineLimit(1)
                    Text(market.title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(market.believePercentage)% Belief")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                    Text(viewModel.formatSOLShort(market.volume24h) + " vol")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(String(format: "%+.1f%%", market.change24h))
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(market.change24h >= 0 ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                    .foregroundStyle(market.change24h >= 0 ? .green : .red)
                    .clipShape(.rect(cornerRadius: 6))
            }
        }
        .padding(14)
        .frame(width: 200)
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 16))
    }
}
