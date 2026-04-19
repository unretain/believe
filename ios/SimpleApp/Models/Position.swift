import Foundation

nonisolated struct Position: Identifiable, Codable, Sendable {
    let id: UUID
    let marketId: UUID
    let side: TradeSide
    var shares: Double
    var avgCost: Double
    var totalInvested: Double

    init(id: UUID = UUID(), marketId: UUID, side: TradeSide, shares: Double, avgCost: Double, totalInvested: Double) {
        self.id = id
        self.marketId = marketId
        self.side = side
        self.shares = shares
        self.avgCost = avgCost
        self.totalInvested = totalInvested
    }

    func currentValue(price: Double) -> Double {
        shares * price
    }

    func pnl(price: Double) -> Double {
        currentValue(price: price) - totalInvested
    }

    func pnlPercentage(price: Double) -> Double {
        guard totalInvested > 0 else { return 0 }
        return (pnl(price: price) / totalInvested) * 100
    }
}
