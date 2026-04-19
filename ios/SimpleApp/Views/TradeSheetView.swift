import SwiftUI

struct TradeSheetView: View {
    let market: Market
    @Bindable var viewModel: MarketViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var amount: String = ""
    @State private var isBelieve: Bool = true
    @State private var mode: TradeMode = .spot
    @State private var leverage: Double = 2
    @State private var triggerHaptic: Int = 0

    enum TradeMode: String, CaseIterable { case spot = "Spot", sell = "Sell", leverage = "Leverage" }
    private var isSelling: Bool { mode == .sell }
    private var isLeverage: Bool { mode == .leverage }
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var tradeSuccess: Bool = false

    private var side: TradeSide { isBelieve ? .believe : .doubt }

    private var amountValue: Double {
        Double(amount) ?? 0
    }

    private var existingPosition: Position? {
        viewModel.account.positions.first { $0.marketId == market.id && $0.side == side }
    }

    private var buyEstimate: (shares: Double, avgPrice: Double, priceImpact: Double, fee: Double) {
        MarketEngine.estimateBuy(market: market, side: side, amount: amountValue)
    }

    private var sellEstimate: (payout: Double, avgPrice: Double, priceImpact: Double, fee: Double) {
        MarketEngine.estimateSell(market: market, side: side, shares: amountValue)
    }

    var body: some View {
        VStack(spacing: 20) {
            header
            sideToggle
            buySellToggle

            switch mode {
            case .spot: buyContent
            case .sell: sellContent
            case .leverage: leverageContent
            }

            Spacer()

            balanceBar
            actionButton
        }
        .padding()
        .alert("Trade Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .overlay {
            if tradeSuccess {
                successOverlay
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Trade \(market.name)")
                    .font(.headline)
                Text(isSelling ? "Sell shares" : "Buy shares with SOL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var sideToggle: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.snappy) { isBelieve = true }
                triggerHaptic += 1
            } label: {
                Text("Believe")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isBelieve ? Color.green : Color(.tertiarySystemFill))
                    .foregroundStyle(isBelieve ? .white : .primary)
            }

            Button {
                withAnimation(.snappy) { isBelieve = false }
                triggerHaptic += 1
            } label: {
                Text("Doubt")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(!isBelieve ? Color.red : Color(.tertiarySystemFill))
                    .foregroundStyle(!isBelieve ? .white : .primary)
            }
        }
        .clipShape(.rect(cornerRadius: 10))
        .sensoryFeedback(.selection, trigger: triggerHaptic)
    }

    private var buySellToggle: some View {
        HStack(spacing: 0) {
            ForEach(TradeMode.allCases, id: \.self) { m in
                Button {
                    withAnimation(.snappy) { mode = m }
                    amount = ""
                } label: {
                    Text(m.rawValue)
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(mode == m ? Color(.label).opacity(0.1) : Color.clear)
                        .clipShape(.rect(cornerRadius: 7))
                }
                .foregroundStyle(mode == m ? .primary : .secondary)
            }
        }
        .padding(3)
        .background(Color(.tertiarySystemFill))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var leverageContent: some View {
        let price = isBelieve ? market.currentBelieve : market.currentDoubt
        let size = amountValue * leverage
        let mm = 0.005
        let liq = price * (1.0 - (1.0 - mm) / max(leverage, 1))
        return VStack(spacing: 14) {
            amountInput(label: "Collateral (SOL)", prefix: "◎")
            presetButtons

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Leverage")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.0fx", leverage))
                        .font(.subheadline.bold())
                        .foregroundStyle(leverage >= 20 ? .red : (leverage >= 10 ? .orange : .primary))
                }
                Slider(value: $leverage, in: 2...50, step: 1)
                    .tint(leverage >= 20 ? .red : (leverage >= 10 ? .orange : .blue))
                HStack {
                    ForEach([2.0, 5.0, 10.0, 25.0, 50.0], id: \.self) { v in
                        Button {
                            withAnimation(.snappy) { leverage = v }
                        } label: {
                            Text(String(format: "%.0fx", v))
                                .font(.caption.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(abs(leverage - v) < 0.01 ? Color(.label).opacity(0.15) : Color(.tertiarySystemFill))
                                .clipShape(.rect(cornerRadius: 7))
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(.rect(cornerRadius: 12))

            if amountValue > 0 {
                VStack(spacing: 8) {
                    infoRow("Position size", String(format: "%.4f SOL", size))
                    infoRow("Entry price", String(format: "%.4f", price))
                    infoRow("Liquidation price", String(format: "%.4f", liq))
                    infoRow("Direction", isBelieve ? "Long Believe" : "Long Doubt")
                }
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text("At \(Int(leverage))x, a \(String(format: "%.1f%%", 100.0 / leverage)) adverse move liquidates your collateral.")
                        .font(.caption2)
                }
                .foregroundStyle(.orange)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
                .clipShape(.rect(cornerRadius: 10))
            }
        }
    }

    private var buyContent: some View {
        VStack(spacing: 14) {
            amountInput(label: "Amount (SOL)", prefix: "◎")
            presetButtons

            if amountValue > 0 {
                VStack(spacing: 8) {
                    infoRow("Est. shares", String(format: "%.2f", buyEstimate.shares))
                    infoRow("Avg. price", String(format: "%.4f SOL", buyEstimate.avgPrice))
                    infoRow("Price impact", String(format: "%+.2f%%", buyEstimate.priceImpact))
                    infoRow("Fee (1%)", String(format: "%.4f SOL", buyEstimate.fee))
                    infoRow("Current price", String(format: "%.4f SOL", isBelieve ? market.currentBelieve : market.currentDoubt))
                }
            }
        }
    }

    private var sellContent: some View {
        VStack(spacing: 14) {
            if let position = existingPosition, position.shares > 0.001 {
                HStack {
                    Text("You hold")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.2f shares", position.shares))
                        .font(.caption.bold())
                }
                .padding(.horizontal, 4)

                amountInput(label: "Shares to sell", prefix: nil)

                HStack {
                    ForEach([25, 50, 75, 100], id: \.self) { pct in
                        Button {
                            let shares = position.shares * Double(pct) / 100.0
                            amount = String(format: "%.2f", shares)
                        } label: {
                            Text("\(pct)%")
                                .font(.caption.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color(.tertiarySystemFill))
                                .clipShape(.rect(cornerRadius: 8))
                        }
                        .foregroundStyle(.primary)
                    }
                }

                if amountValue > 0 {
                    VStack(spacing: 8) {
                        infoRow("Est. payout", String(format: "%.4f SOL", sellEstimate.payout))
                        infoRow("Avg. price", String(format: "%.4f SOL", sellEstimate.avgPrice))
                        infoRow("Price impact", String(format: "%+.2f%%", sellEstimate.priceImpact))
                        infoRow("Fee (1%)", String(format: "%.4f SOL", sellEstimate.fee))
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No \(side.rawValue) shares to sell")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
    }

    private func amountInput(label: String, prefix: String?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                if let prefix {
                    Text(prefix)
                        .font(.title2.bold())
                        .foregroundStyle(.secondary)
                }
                TextField("0.00", text: $amount)
                    .font(.title2.bold())
                    .keyboardType(.decimalPad)
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(.rect(cornerRadius: 12))
        }
    }

    private var presetButtons: some View {
        HStack {
            ForEach([0.1, 0.5, 1.0, 5.0], id: \.self) { preset in
                Button {
                    amount = "\(preset)"
                } label: {
                    Text("◎\(preset.formatted())")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(.rect(cornerRadius: 8))
                }
                .foregroundStyle(.primary)
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
        .padding(.horizontal, 4)
    }

    private var balanceBar: some View {
        HStack {
            Text("SOL Balance")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(String(format: "◎ %.4f", viewModel.wallet.tradingBalance))
                .font(.caption.bold())
        }
        .padding(.horizontal, 4)
    }

    private var actionButton: some View {
        Button {
            executeTrade()
        } label: {
            let buttonDisabled = amountValue <= 0
            let label: String = {
                switch mode {
                case .spot: return "Buy \(side.rawValue)"
                case .sell: return "Sell \(side.rawValue)"
                case .leverage: return String(format: "Open %.0fx %@", leverage, side.rawValue)
                }
            }()
            Text(label)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(buttonDisabled ? Color(.systemGray3) : (isBelieve ? Color.green : Color.red))
                .foregroundStyle(.white)
                .clipShape(.rect(cornerRadius: 14))
        }
        .disabled(amountValue <= 0)
    }

    private var successOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("Trade Executed!")
                .font(.title2.bold())
            if let result = viewModel.lastTradeResult {
                Text(String(format: "%.2f shares at %.4f SOL", result.shares, result.avgPrice))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        }
    }

    private func executeTrade() {
        Task {
            do {
                switch mode {
                case .sell:
                    try await viewModel.executeSell(marketId: market.id, side: side, shares: amountValue)
                case .spot:
                    try await viewModel.executeBuy(marketId: market.id, side: side, amount: amountValue)
                case .leverage:
                    try await viewModel.openLeveragePosition(marketId: market.id, side: side, leverage: leverage, collateral: amountValue)
                }
                withAnimation(.spring(response: 0.3)) {
                    tradeSuccess = true
                }
            } catch TradeError.insufficientBalance {
                errorMessage = "Insufficient SOL balance. You have \(String(format: "%.4f SOL", viewModel.wallet.tradingBalance))."
                showError = true
            } catch TradeError.insufficientShares {
                errorMessage = "You don't have enough shares to sell."
                showError = true
            } catch {
                errorMessage = "Trade failed. Please try again."
                showError = true
            }
        }
    }
}
