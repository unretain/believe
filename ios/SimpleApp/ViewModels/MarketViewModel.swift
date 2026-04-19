import Foundation

@Observable
@MainActor
class MarketViewModel {
    var markets: [Market] = []
    var account: UserAccount = UserAccount()
    var wallet: WalletService = WalletService()
    var selectedCategory: MarketCategory = .all
    var searchText: String = ""
    var tradeError: String?
    var lastTradeResult: TradeResult?
    var isLoading: Bool = false
    var isLive: Bool = LiveService.isConfigured
    var liveError: String?
    var profile: LiveProfile = LiveProfile(wallet: "", username: "", bio: "", avatarURL: "")
    var topTraders: [LiveTopTrader] = []
    var leveragePositions: [LiveLeveragePosition] = []
    var lastLiquidations: Int = 0
    private var refreshTask: Task<Void, Never>?

    struct TradeResult: Sendable {
        let marketName: String
        let side: TradeSide
        let amount: Double
        let shares: Double
        let avgPrice: Double
    }

    init() {
        loadState()
        if isLive {
            Task { await refreshLive() }
            startPolling()
        } else {
            Task { await wallet.refreshBalance() }
        }
    }

    var filteredMarkets: [Market] {
        var result = markets
        if selectedCategory != .all {
            if selectedCategory == .trending {
                result = result.filter { $0.isTrending }
            } else {
                result = result.filter { $0.category == selectedCategory }
            }
        }
        if !searchText.isEmpty {
            let q = searchText
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(q) ||
                $0.title.localizedCaseInsensitiveContains(q) ||
                $0.handle.localizedCaseInsensitiveContains(q) ||
                $0.xHandle.localizedCaseInsensitiveContains(q) ||
                $0.category.rawValue.localizedCaseInsensitiveContains(q)
            }
        }
        return result
    }

    var trendingMarkets: [Market] {
        markets.filter { $0.isTrending }.sorted { $0.volume24h > $1.volume24h }
    }

    var topMovers: [Market] {
        markets.sorted { abs($0.change24h) > abs($1.change24h) }
    }

    var activePositions: [Position] {
        account.positions.filter { $0.shares > 0.001 }
    }

    var portfolioValue: Double {
        var total: Double = 0
        for position in activePositions {
            if let market = markets.first(where: { $0.id == position.marketId }) {
                let price = position.side == .believe ? market.currentBelieve : market.currentDoubt
                total += position.currentValue(price: price)
            }
        }
        return total
    }

    var totalInvested: Double {
        activePositions.reduce(0) { $0 + $1.totalInvested }
    }

    var portfolioPnL: Double {
        portfolioValue - totalInvested
    }

    var portfolioPnLPercentage: Double {
        guard totalInvested > 0 else { return 0 }
        return (portfolioPnL / totalInvested) * 100
    }

    func market(for id: UUID) -> Market? {
        markets.first { $0.id == id }
    }

    func positionsForMarket(_ marketId: UUID) -> [Position] {
        activePositions.filter { $0.marketId == marketId }
    }

    func recentTradesForMarket(_ marketId: UUID) -> [Trade] {
        account.trades
            .filter { $0.marketId == marketId }
            .sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Live backend

    private func startPolling() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                await self?.refreshLive()
            }
        }
    }

    func refreshLive() async {
        guard isLive else { return }
        guard !wallet.publicAddress.isEmpty else { return }
        do {
            async let liveMarkets = LiveService.getMarkets()
            async let portfolio = LiveService.getPortfolio(wallet: wallet.publicAddress)
            let (lm, pf) = try await (liveMarkets, portfolio)
            self.markets = lm.map { Self.convert($0) }
            self.account = UserAccount(
                positions: pf.positions.map {
                    Position(id: $0.id, marketId: $0.marketId,
                             side: $0.side == "Believe" ? .believe : .doubt,
                             shares: $0.shares, avgCost: $0.avgCost,
                             totalInvested: $0.totalInvested)
                },
                trades: pf.trades.map {
                    Trade(id: $0.id, marketId: $0.marketId,
                          side: $0.side == "Believe" ? .believe : .doubt,
                          amount: $0.amount, shares: $0.shares,
                          pricePerShare: $0.pricePerShare, timestamp: $0.timestamp)
                }
            )
            self.wallet.tradingBalance = pf.balance
            self.liveError = nil
            async let prof = LiveService.getProfile(wallet: wallet.publicAddress)
            async let traders = LiveService.getTopTraders()
            async let lev = LiveService.getLeverage(wallet: wallet.publicAddress)
            _ = try? await LiveService.liquidateUnderwater()
            if let p = try? await prof { self.profile = p }
            if let t = try? await traders { self.topTraders = t }
            if let l = try? await lev {
                let prevOpen = Set(self.leveragePositions.filter { $0.status == "open" }.map(\.id))
                let newlyLiquidated = l.filter { $0.status == "liquidated" && prevOpen.contains($0.id) }.count
                if newlyLiquidated > 0 { self.lastLiquidations = newlyLiquidated }
                self.leveragePositions = l
            }
        } catch {
            self.liveError = "Live sync error"
        }
    }

    func saveProfile(username: String, bio: String, avatarURL: String) async throws {
        guard isLive, !wallet.publicAddress.isEmpty else { throw TradeError.invalidAmount }
        let p = try await LiveService.upsertProfile(
            wallet: wallet.publicAddress,
            username: username, bio: bio, avatarURL: avatarURL
        )
        self.profile = p
    }

    func deposit(amount: Double) async throws {
        guard isLive else { throw TradeError.invalidAmount }
        guard amount > 0 else { throw TradeError.invalidAmount }
        let r = try await LiveService.deposit(wallet: wallet.publicAddress, amount: amount)
        wallet.tradingBalance = r.balance
        liveError = nil
    }

    func withdraw(amount: Double) async throws {
        guard isLive else { throw TradeError.invalidAmount }
        guard amount > 0 else { throw TradeError.invalidAmount }
        do {
            let r = try await LiveService.withdraw(wallet: wallet.publicAddress, amount: amount)
            wallet.tradingBalance = r.balance
            liveError = nil
        } catch let e as LiveServiceError {
            if case .requestFailed(let msg) = e, msg.contains("insufficient_balance") {
                throw TradeError.insufficientBalance
            }
            throw TradeError.invalidAmount
        }
    }

    private static func convert(_ lm: LiveMarket) -> Market {
        Market(
            id: lm.id,
            name: lm.name,
            title: lm.title,
            handle: lm.handle,
            xHandle: lm.xHandle,
            imageURL: lm.imageURL,
            avatarURL: lm.avatarURL,
            category: MarketCategory(rawValue: lm.category) ?? .tech,
            believePool: lm.believePool,
            doubtPool: lm.doubtPool,
            volume24h: lm.volume24h,
            totalVolume: lm.totalVolume,
            holders: lm.holders,
            priceHistory: lm.priceHistory.map {
                PricePoint(id: $0.id, date: $0.date,
                           believePrice: $0.believePrice,
                           doubtPrice: $0.doubtPrice)
            },
            createdAt: lm.createdAt
        )
    }

    // MARK: - Trades

    var openLeverage: [LiveLeveragePosition] {
        leveragePositions.filter { $0.status == "open" }
    }

    func openLeveragePosition(marketId: UUID, side: TradeSide, leverage: Double, collateral: Double) async throws {
        guard isLive else { throw TradeError.invalidAmount }
        guard collateral > 0 else { throw TradeError.invalidAmount }
        do {
            let r = try await LiveService.openLeverage(
                wallet: wallet.publicAddress,
                marketId: marketId, side: side.rawValue,
                leverage: leverage, collateral: collateral
            )
            wallet.tradingBalance = r.balance
            await refreshLive()
        } catch let e as LiveServiceError {
            if case .requestFailed(let msg) = e, msg.contains("insufficient_balance") {
                throw TradeError.insufficientBalance
            }
            throw TradeError.invalidAmount
        }
    }

    func closeLeveragePosition(id: UUID) async throws {
        guard isLive else { throw TradeError.invalidAmount }
        let r = try await LiveService.closeLeverage(wallet: wallet.publicAddress, id: id)
        wallet.tradingBalance = r.balance
        await refreshLive()
    }

    func executeBuy(marketId: UUID, side: TradeSide, amount: Double) async throws {
        guard amount > 0 else { throw TradeError.invalidAmount }
        guard isLive else { throw TradeError.invalidAmount }
        do {
            let r = try await LiveService.buy(
                wallet: wallet.publicAddress,
                marketId: marketId, side: side.rawValue, amount: amount
            )
            wallet.tradingBalance = r.balance
            await refreshLive()
            if let m = markets.first(where: { $0.id == marketId }) {
                lastTradeResult = TradeResult(
                    marketName: m.name, side: side,
                    amount: amount, shares: r.shares, avgPrice: r.avgPrice
                )
            }
        } catch let e as LiveServiceError {
            if case .requestFailed(let msg) = e, msg.contains("insufficient_balance") {
                throw TradeError.insufficientBalance
            }
            throw TradeError.invalidAmount
        }
    }

    func executeSell(marketId: UUID, side: TradeSide, shares: Double) async throws {
        guard shares > 0 else { throw TradeError.invalidAmount }
        guard isLive else { throw TradeError.invalidAmount }
        do {
            let r = try await LiveService.sell(
                wallet: wallet.publicAddress,
                marketId: marketId, side: side.rawValue, shares: shares
            )
            wallet.tradingBalance = r.balance
            await refreshLive()
            if let m = markets.first(where: { $0.id == marketId }) {
                lastTradeResult = TradeResult(
                    marketName: m.name, side: side,
                    amount: r.payout ?? 0, shares: shares, avgPrice: r.avgPrice
                )
            }
        } catch let e as LiveServiceError {
            if case .requestFailed(let msg) = e, msg.contains("insufficient_shares") {
                throw TradeError.insufficientShares
            }
            throw TradeError.invalidAmount
        }
    }

    func formatSOL(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fK SOL", value / 1000)
        }
        return String(format: "%.4f SOL", value)
    }

    func formatSOLShort(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM SOL", value / 1_000_000)
        } else if value >= 1000 {
            return String(format: "%.1fK SOL", value / 1000)
        }
        return String(format: "%.2f SOL", value)
    }

    func formatHolders(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000)
        }
        return "\(count)"
    }

    func resetAccount() {
        PersistenceService.resetAll()
        if !isLive {
            markets = SampleData.markets
            account = UserAccount()
            saveState()
        }
        Task {
            await wallet.refreshBalance()
            if isLive { await refreshLive() }
        }
    }

    private func loadState() {
        if let savedMarkets = PersistenceService.loadMarkets() {
            markets = savedMarkets
        } else {
            markets = SampleData.markets
        }

        if let savedAccount = PersistenceService.loadAccount() {
            account = savedAccount
        } else {
            account = UserAccount()
        }

        if !isLive { saveState() }
    }

    private func saveState() {
        guard !isLive else { return }
        PersistenceService.saveMarkets(markets)
        PersistenceService.saveAccount(account)
    }
}
