import SwiftUI

struct PortfolioView: View {
    let viewModel: MarketViewModel
    @State private var showEditProfile: Bool = false

    @State private var liquidationAlert: Int = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                profileSection
                portfolioHeader
                leverageSection
                holdingsSection
                recentTradesSection
            }
        }
        .alert("Position Liquidated", isPresented: Binding(
            get: { liquidationAlert > 0 && liquidationAlert != viewModel.lastLiquidations },
            set: { if !$0 { liquidationAlert = viewModel.lastLiquidations } }
        )) {
            Button("OK") { liquidationAlert = viewModel.lastLiquidations }
        } message: {
            Text("\(viewModel.lastLiquidations) leveraged position\(viewModel.lastLiquidations == 1 ? " was" : "s were") liquidated. Collateral lost.")
        }
        .onChange(of: viewModel.lastLiquidations) { _, new in
            if new > 0 { liquidationAlert = new - 1 }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
    }

    private var profileSection: some View {
        let p = viewModel.profile
        let hasProfile = !p.username.isEmpty
        return HStack(spacing: 14) {
            Color(.secondarySystemBackground)
                .frame(width: 64, height: 64)
                .overlay {
                    if let url = URL(string: p.avatarURL), !p.avatarURL.isEmpty {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .allowsHitTesting(false)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(hasProfile ? p.username : "Set up your profile")
                    .font(.headline)
                    .lineLimit(1)
                if hasProfile && !p.bio.isEmpty {
                    Text(p.bio)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text(truncate(viewModel.wallet.publicAddress))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                showEditProfile = true
            } label: {
                Text(hasProfile ? "Edit" : "Create")
                    .font(.caption.bold())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Capsule())
            }
            .foregroundStyle(.primary)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 20))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func truncate(_ s: String) -> String {
        guard s.count > 10 else { return s }
        return "\(s.prefix(6))…\(s.suffix(4))"
    }

    private var portfolioHeader: some View {
        VStack(spacing: 8) {
            Text("Positions Value")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(String(format: "%.4f", viewModel.portfolioValue))
                .font(.system(size: 42, weight: .bold, design: .rounded))
            Text("SOL")
                .font(.title3.bold())
                .foregroundStyle(.secondary)

            if viewModel.totalInvested > 0 {
                let pnl = viewModel.portfolioPnL
                let pnlPct = viewModel.portfolioPnLPercentage
                HStack(spacing: 4) {
                    Image(systemName: pnl >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption.bold())
                    Text(String(format: "%@%.4f SOL (%.1f%%)", pnl >= 0 ? "+" : "", pnl, pnlPct))
                        .font(.subheadline.bold())
                }
                .foregroundStyle(pnl >= 0 ? .green : .red)
            }

            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("Wallet")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.4f SOL", viewModel.wallet.tradingBalance))
                        .font(.caption.bold())
                }
                VStack(spacing: 2) {
                    Text("Invested")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.4f SOL", viewModel.totalInvested))
                        .font(.caption.bold())
                }
                VStack(spacing: 2) {
                    Text("Trades")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.account.trades.count)")
                        .font(.caption.bold())
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            LinearGradient(
                colors: [
                    (viewModel.portfolioPnL >= 0 ? Color.green : Color.red).opacity(0.08),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    @ViewBuilder
    private var leverageSection: some View {
        let open = viewModel.openLeverage
        if !open.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Leveraged Positions")
                        .font(.headline)
                    Spacer()
                    Text("\(open.count) open")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                ForEach(open) { pos in
                    if let market = viewModel.market(for: pos.marketId) {
                        LeverageRowView(position: pos, market: market, viewModel: viewModel)
                    }
                }
            }
        }
    }

    private var holdingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Positions")
                .font(.headline)
                .padding(.horizontal)

            if viewModel.activePositions.isEmpty {
                emptyPrompt
            } else {
                ForEach(viewModel.activePositions) { position in
                    if let market = viewModel.market(for: position.marketId) {
                        HoldingRowView(market: market, position: position)
                    }
                }
            }
        }
    }

    private var recentTradesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let trades = viewModel.account.trades.sorted { $0.timestamp > $1.timestamp }.prefix(10)
            if !trades.isEmpty {
                Text("Recent Trades")
                    .font(.headline)
                    .padding(.horizontal)

                ForEach(Array(trades)) { trade in
                    if let market = viewModel.market(for: trade.marketId) {
                        TradeHistoryRow(trade: trade, marketName: market.name)
                    }
                }
            }
        }
    }

    private var emptyPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No positions yet")
                .font(.subheadline.bold())
            Text("Deposit SOL and trade markets to build your portfolio")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

struct LeverageRowView: View {
    let position: LiveLeveragePosition
    let market: Market
    let viewModel: MarketViewModel
    @State private var isClosing: Bool = false

    private var markPrice: Double {
        position.side == "Believe" ? market.currentBelieve : market.currentDoubt
    }

    private var pnl: Double {
        guard position.entryPrice > 0 else { return 0 }
        return position.size * (markPrice - position.entryPrice) / position.entryPrice
    }

    private var pnlPct: Double {
        guard position.collateral > 0 else { return 0 }
        return pnl / position.collateral * 100
    }

    private var distToLiq: Double {
        guard markPrice > 0 else { return 0 }
        return (markPrice - position.liquidationPrice) / markPrice * 100
    }

    private var leverageColor: Color {
        position.leverage >= 20 ? .red : (position.leverage >= 10 ? .orange : .blue)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Color(.tertiarySystemBackground)
                    .frame(width: 40, height: 40)
                    .overlay {
                        AsyncImage(url: URL(string: market.avatarURL)) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Image(systemName: "person.fill").foregroundStyle(.secondary)
                            }
                        }
                        .allowsHitTesting(false)
                    }
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(market.name)
                            .font(.subheadline.bold())
                            .lineLimit(1)
                        Text(String(format: "%.0fx", position.leverage))
                            .font(.caption2.bold())
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(leverageColor.opacity(0.2))
                            .foregroundStyle(leverageColor)
                            .clipShape(Capsule())
                    }
                    HStack(spacing: 4) {
                        Circle()
                            .fill(position.side == "Believe" ? Color.green : Color.red)
                            .frame(width: 6, height: 6)
                        Text(position.side)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.3f SOL size", position.size))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%@%.4f", pnl >= 0 ? "+" : "", pnl))
                        .font(.subheadline.bold())
                        .foregroundStyle(pnl >= 0 ? .green : .red)
                    Text(String(format: "%@%.1f%%", pnl >= 0 ? "+" : "", pnlPct))
                        .font(.caption)
                        .foregroundStyle(pnl >= 0 ? .green : .red)
                }
            }

            VStack(spacing: 4) {
                HStack {
                    Text("Liq \(String(format: "%.4f", position.liquidationPrice))")
                        .font(.caption2)
                        .foregroundStyle(.red)
                    Spacer()
                    Text("Mark \(String(format: "%.4f", markPrice))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Entry \(String(format: "%.4f", position.entryPrice))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                GeometryReader { geo in
                    let safe = max(0, min(distToLiq, 100))
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.tertiarySystemFill))
                        Capsule()
                            .fill(LinearGradient(colors: [.red, .orange, .green], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(safe) / 100)
                    }
                }
                .frame(height: 4)
                Text(distToLiq > 0 ? String(format: "%.1f%% to liquidation", distToLiq) : "Liquidating…")
                    .font(.caption2)
                    .foregroundStyle(distToLiq < 10 ? .red : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                isClosing = true
                Task {
                    try? await viewModel.closeLeveragePosition(id: position.id)
                    isClosing = false
                }
            } label: {
                HStack {
                    if isClosing { ProgressView().controlSize(.small) }
                    Text(isClosing ? "Closing…" : "Close Position")
                        .font(.caption.bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemFill))
                .clipShape(.rect(cornerRadius: 8))
            }
            .foregroundStyle(.primary)
            .disabled(isClosing)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 14))
        .padding(.horizontal)
    }
}

struct HoldingRowView: View {
    let market: Market
    let position: Position

    private var currentPrice: Double {
        position.side == .believe ? market.currentBelieve : market.currentDoubt
    }

    var body: some View {
        HStack(spacing: 12) {
            Color(.secondarySystemBackground)
                .frame(width: 44, height: 44)
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

            VStack(alignment: .leading, spacing: 3) {
                Text(market.name)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Circle()
                        .fill(position.side == .believe ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    Text(position.side.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2f shares", position.shares))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(String(format: "%.4f SOL", position.currentValue(price: currentPrice)))
                    .font(.subheadline.bold())
                let pnl = position.pnl(price: currentPrice)
                Text(String(format: "%@%.4f SOL", pnl >= 0 ? "+" : "", pnl))
                    .font(.caption)
                    .foregroundStyle(pnl >= 0 ? .green : .red)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}

struct TradeHistoryRow: View {
    let trade: Trade
    let marketName: String

    private var isBuy: Bool { trade.shares > 0 }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill((isBuy ? Color.green : Color.orange).opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: isBuy ? "arrow.up" : "arrow.down")
                        .font(.caption.bold())
                        .foregroundStyle(isBuy ? .green : .orange)
                }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(isBuy ? "Bought" : "Sold")
                        .font(.subheadline.bold())
                    Text(trade.side.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(trade.side == .believe ? .green : .red)
                }
                Text("\(marketName) · \(trade.timestamp.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.4f SOL", abs(trade.amount)))
                    .font(.subheadline.bold())
                Text(String(format: "%.2f shares", abs(trade.shares)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}
