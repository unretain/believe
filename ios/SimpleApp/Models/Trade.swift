import Foundation

nonisolated struct Trade: Identifiable, Codable, Sendable {
    let id: UUID
    let marketId: UUID
    let side: TradeSide
    let amount: Double
    let shares: Double
    let pricePerShare: Double
    let timestamp: Date

    init(id: UUID = UUID(), marketId: UUID, side: TradeSide, amount: Double, shares: Double, pricePerShare: Double, timestamp: Date = Date()) {
        self.id = id
        self.marketId = marketId
        self.side = side
        self.amount = amount
        self.shares = shares
        self.pricePerShare = pricePerShare
        self.timestamp = timestamp
    }
}
