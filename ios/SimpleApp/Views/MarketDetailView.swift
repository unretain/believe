import SwiftUI

struct MarketDetailView: View {
    let marketId: UUID
    @Bindable var viewModel: MarketViewModel
    @State private var selectedTimeRange: TimeRange = .oneDay
    @State private var showTradeSheet: Bool = false

    private var market: Market? {
        viewModel.market(for: marketId)
    }

    var body: some View {
        Group {
            if let market {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        headerSection(market)
                        chartSection(market)
                        positionsSection(market)
                        statsSection(market)
                        activitySection(market)
                    }
                }
                .background(Color(.systemBackground))
                .navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .bottom) {
                    tradeButtons
                }
                .sheet(isPresented: $showTradeSheet) {
                    if let m = self.market {
                        TradeSheetView(market: m, viewModel: viewModel)
                            .presentationDetents([.large])
                    }
                }
            }
        }
    }

    private func headerSection(_ market: Market) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    if market.isTrending {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                            Text("Trending")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(.orange)
                    }

                    Text(market.name)
                        .font(.title.bold())

                    Text(market.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Label(market.handle, systemImage: "at")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 2) {
                            Text("𝕏")
                                .font(.caption.bold())
                            Text(market.xHandle)
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                BeliefGaugeView(percentage: market.believePercentage, size: 90)
            }
        }
        .padding()
    }

    private func chartSection(_ market: Market) -> some View {
        VStack(spacing: 12) {
            if market.priceHistory.count > 1 {
                SentimentChartView(priceHistory: market.priceHistory, timeRange: selectedTimeRange)
                    .padding(.horizontal)
                timeRangePicker
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.flattrend.xyaxis")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("No trade history yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Be the first to trade this market")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
            }
        }
    }

    private var timeRangePicker: some View {
        HStack(spacing: 0) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button {
                    withAnimation(.snappy) {
                        selectedTimeRange = range
                    }
                } label: {
                    Text(range.rawValue)
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selectedTimeRange == range
                            ? Color(.label).opacity(0.1)
                            : Color.clear
                        )
                        .clipShape(.rect(cornerRadius: 8))
                }
                .foregroundStyle(selectedTimeRange == range ? .primary : .secondary)
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func positionsSection(_ market: Market) -> some View {
        let positions = viewModel.positionsForMarket(market.id)
        if !positions.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Divider().padding(.vertical, 8)

                Text("Your Positions")
                    .font(.headline)
                    .padding(.horizontal)

                ForEach(positions) { position in
                    let price = position.side == .believe ? market.currentBelieve : market.currentDoubt
                    let pnl = position.pnl(price: price)

                    HStack {
                        Circle()
                            .fill(position.side == .believe ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                            .frame(width: 36, height: 36)
                            .overlay {
                                Image(systemName: position.side == .believe ? "arrow.up" : "arrow.down")
                                    .font(.caption.bold())
                                    .foregroundStyle(position.side == .believe ? .green : .red)
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(position.side.rawValue)
                                .font(.subheadline.bold())
                            Text(String(format: "%.2f shares @ %.4f SOL avg", position.shares, position.avgCost))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "%.4f SOL", position.currentValue(price: price)))
                                .font(.subheadline.bold())
                            Text(String(format: "%@%.4f SOL", pnl >= 0 ? "+" : "", pnl))
                                .font(.caption)
                                .foregroundStyle(pnl >= 0 ? .green : .red)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private func statsSection(_ market: Market) -> some View {
        VStack(spacing: 16) {
            Divider()
                .padding(.vertical, 8)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatCardView(
                    title: "Believe",
                    value: String(format: "%.4f SOL", market.currentBelieve),
                    subtitle: market.change24h != 0 ? String(format: "%+.1f%%", market.change24h) : "—",
                    color: .green
                )
                StatCardView(
                    title: "Doubt",
                    value: String(format: "%.4f SOL", market.currentDoubt),
                    subtitle: market.change24h != 0 ? String(format: "%+.1f%%", -market.change24h) : "—",
                    color: .red
                )
                StatCardView(
                    title: "24h Volume",
                    value: viewModel.formatSOLShort(market.volume24h),
                    subtitle: "Total traded",
                    color: .blue
                )
                StatCardView(
                    title: "Liquidity",
                    value: viewModel.formatSOLShort(market.believePool + market.doubtPool),
                    subtitle: "Pool depth",
                    color: .purple
                )
            }
            .padding(.horizontal)
        }
    }

    private func activitySection(_ market: Market) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .padding(.vertical, 8)

            Text("Your Trades")
                .font(.headline)
                .padding(.horizontal)

            let trades = viewModel.recentTradesForMarket(market.id)
            if trades.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("No trades yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(trades.prefix(10)) { trade in
                    TradeHistoryRow(trade: trade, marketName: market.name)
                }
            }

            Color.clear.frame(height: 80)
        }
    }

    private var tradeButtons: some View {
        HStack(spacing: 12) {
            Button {
                showTradeSheet = true
            } label: {
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                    Text("Believe")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.green)
                .foregroundStyle(.white)
                .clipShape(.rect(cornerRadius: 14))
            }

            Button {
                showTradeSheet = true
            } label: {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("Doubt")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.red)
                .foregroundStyle(.white)
                .clipShape(.rect(cornerRadius: 14))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

struct StatCardView: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 12))
    }
}
