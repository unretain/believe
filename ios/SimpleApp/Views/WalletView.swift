import SwiftUI
import CoreImage.CIFilterBuiltins

struct WalletView: View {
    let viewModel: MarketViewModel
    @State private var copied: Bool = false
    @State private var showResetConfirm: Bool = false
    @State private var showDeposit: Bool = false
    @State private var showWithdraw: Bool = false
    @State private var depositAmount: String = ""
    @State private var withdrawAmount: String = ""
    @State private var withdrawDestination: String = ""
    @State private var actionError: String?
    @State private var isSubmitting: Bool = false

    private var wallet: WalletService { viewModel.wallet }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                balanceCard
                addressCard
                positionsSummary
                actionsSection
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .refreshable {
            await wallet.refreshBalance()
        }
        .navigationTitle("Wallet")
        .sheet(isPresented: $showDeposit) {
            depositSheet
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showWithdraw) {
            withdrawSheet
                .presentationDetents([.medium, .large])
        }
        .alert("Reset Wallet", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                wallet.resetWallet()
                viewModel.resetAccount()
            }
        } message: {
            Text("This will generate a new wallet and clear all positions. This cannot be undone.")
        }
    }

    private var balanceCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Trading Balance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(String(format: "%.4f", wallet.tradingBalance))
                    .font(.system(size: 44, weight: .bold, design: .rounded))

                Text("SOL")
                    .font(.title3.bold())
                    .foregroundStyle(.secondary)

                if viewModel.isLive {
                    HStack(spacing: 4) {
                        Circle().fill(.green).frame(width: 6, height: 6)
                        Text("Live · Shared liquidity")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }

                if let error = wallet.balanceError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Divider()

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("Positions Value")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.4f SOL", viewModel.portfolioValue))
                        .font(.subheadline.bold())
                }

                VStack(spacing: 4) {
                    Text("P&L")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    let pnl = viewModel.portfolioPnL
                    Text(String(format: "%@%.4f SOL", pnl >= 0 ? "+" : "", pnl))
                        .font(.subheadline.bold())
                        .foregroundStyle(pnl >= 0 ? .green : .red)
                }

                VStack(spacing: 4) {
                    Text("Trades")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.account.trades.count)")
                        .font(.subheadline.bold())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 20))
    }

    private var addressCard: some View {
        VStack(spacing: 16) {
            Text("Deposit SOL")
                .font(.headline)

            if let qrImage = generateQRCode(from: wallet.publicAddress) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .padding(12)
                    .background(.white)
                    .clipShape(.rect(cornerRadius: 12))
            }

            VStack(spacing: 8) {
                Text("Your Solana Address")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(wallet.publicAddress)
                    .font(.system(.caption, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 8)

                Button {
                    UIPasteboard.general.string = wallet.publicAddress
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        copied = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copied!" : "Copy Address")
                    }
                    .font(.subheadline.bold())
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Capsule())
                }
                .sensoryFeedback(.success, trigger: copied)
            }

            Text("Send SOL to this address to fund your account for trading.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 20))
    }

    @ViewBuilder
    private var positionsSummary: some View {
        if !viewModel.activePositions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Open Positions")
                    .font(.headline)

                ForEach(viewModel.activePositions) { position in
                    if let market = viewModel.market(for: position.marketId) {
                        let price = position.side == .believe ? market.currentBelieve : market.currentDoubt
                        let pnl = position.pnl(price: price)

                        HStack(spacing: 12) {
                            Circle()
                                .fill(position.side == .believe ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                                .frame(width: 36, height: 36)
                                .overlay {
                                    Image(systemName: position.side == .believe ? "arrow.up" : "arrow.down")
                                        .font(.caption.bold())
                                        .foregroundStyle(position.side == .believe ? .green : .red)
                                }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(market.name)
                                    .font(.subheadline.bold())
                                Text("\(position.side.rawValue) · \(String(format: "%.2f shares", position.shares))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%.4f SOL", position.currentValue(price: price)))
                                    .font(.subheadline.bold())
                                Text(String(format: "%@%.4f", pnl >= 0 ? "+" : "", pnl))
                                    .font(.caption)
                                    .foregroundStyle(pnl >= 0 ? .green : .red)
                            }
                        }
                    }
                }
            }
            .padding(20)
            .background(Color(.secondarySystemBackground))
            .clipShape(.rect(cornerRadius: 20))
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            if viewModel.isLive {
                HStack(spacing: 12) {
                    Button {
                        showDeposit = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Deposit")
                        }
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(.rect(cornerRadius: 14))
                    }

                    Button {
                        showWithdraw = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                            Text("Withdraw")
                        }
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.tertiarySystemFill))
                        .foregroundStyle(.primary)
                        .clipShape(.rect(cornerRadius: 14))
                    }
                }
            }

            Button {
                Task {
                    await wallet.refreshBalance()
                    await viewModel.refreshLive()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(.tertiarySystemFill))
                .clipShape(.rect(cornerRadius: 14))
            }
            .foregroundStyle(.primary)

            Button {
                showResetConfirm = true
            } label: {
                Text("Reset Wallet & Data")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
            .padding(.top, 8)
        }
        .padding(.bottom, 20)
    }

    private var depositSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("Current balance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.4f SOL", wallet.tradingBalance))
                        .font(.title2.bold())
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Amount (SOL)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text("◎")
                            .font(.title2.bold())
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $depositAmount)
                            .font(.title2.bold())
                            .keyboardType(.decimalPad)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(.rect(cornerRadius: 12))
                }

                HStack {
                    ForEach([1.0, 5.0, 10.0, 50.0], id: \.self) { p in
                        Button {
                            depositAmount = "\(p)"
                        } label: {
                            Text("◎\(p.formatted())")
                                .font(.caption.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color(.tertiarySystemFill))
                                .clipShape(.rect(cornerRadius: 10))
                        }
                        .foregroundStyle(.primary)
                    }
                }

                Text("Funds are credited to your trading account against the shared AMM liquidity.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()

                if let err = actionError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    let amt = Double(depositAmount) ?? 0
                    guard amt > 0, !isSubmitting else { return }
                    Task {
                        isSubmitting = true
                        actionError = nil
                        do {
                            try await viewModel.deposit(amount: amt)
                            depositAmount = ""
                            showDeposit = false
                        } catch {
                            actionError = "Deposit failed. Please try again."
                        }
                        isSubmitting = false
                    }
                } label: {
                    HStack {
                        if isSubmitting { ProgressView().tint(.white) }
                        Text(isSubmitting ? "Depositing…" : "Deposit")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background((Double(depositAmount) ?? 0) > 0 ? Color.accentColor : Color(.systemGray3))
                    .foregroundStyle(.white)
                    .clipShape(.rect(cornerRadius: 14))
                }
                .disabled((Double(depositAmount) ?? 0) <= 0 || isSubmitting)
            }
            .padding()
            .navigationTitle("Deposit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { showDeposit = false }
                }
            }
        }
    }

    private var withdrawSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 6) {
                        Text("Available")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.4f SOL", wallet.tradingBalance))
                            .font(.title2.bold())
                    }
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Amount (SOL)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text("◎")
                                .font(.title2.bold())
                                .foregroundStyle(.secondary)
                            TextField("0.00", text: $withdrawAmount)
                                .font(.title2.bold())
                                .keyboardType(.decimalPad)
                            Button("Max") {
                                withdrawAmount = String(format: "%.4f", wallet.tradingBalance)
                            }
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(Capsule())
                        }
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(.rect(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Destination Solana address")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Paste Solana address", text: $withdrawDestination)
                            .font(.system(.subheadline, design: .monospaced))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(14)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(.rect(cornerRadius: 12))
                    }

                    Text("Withdrawals debit your trading balance and are queued to the destination address.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if let err = actionError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    let amt = Double(withdrawAmount) ?? 0
                    let valid = amt > 0 && amt <= wallet.tradingBalance && withdrawDestination.count >= 32

                    Button {
                        guard valid, !isSubmitting else { return }
                        Task {
                            isSubmitting = true
                            actionError = nil
                            do {
                                try await viewModel.withdraw(amount: amt)
                                withdrawAmount = ""
                                withdrawDestination = ""
                                showWithdraw = false
                            } catch TradeError.insufficientBalance {
                                actionError = "Insufficient balance."
                            } catch {
                                actionError = "Withdrawal failed. Please try again."
                            }
                            isSubmitting = false
                        }
                    } label: {
                        HStack {
                            if isSubmitting { ProgressView().tint(.white) }
                            Text(isSubmitting ? "Withdrawing…" : "Withdraw")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(valid ? Color.accentColor : Color(.systemGray3))
                        .foregroundStyle(.white)
                        .clipShape(.rect(cornerRadius: 14))
                    }
                    .disabled(!valid || isSubmitting)
                }
                .padding()
            }
            .navigationTitle("Withdraw")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { showWithdraw = false }
                }
            }
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }
        let scale = 300.0 / outputImage.extent.width
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
