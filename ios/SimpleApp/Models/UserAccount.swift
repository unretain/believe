import Foundation

nonisolated struct UserAccount: Codable, Sendable {
    var positions: [Position]
    var trades: [Trade]

    init(positions: [Position] = [], trades: [Trade] = []) {
        self.positions = positions
        self.trades = trades
    }

    mutating func addPosition(marketId: UUID, side: TradeSide, shares: Double, cost: Double) {
        if let index = positions.firstIndex(where: { $0.marketId == marketId && $0.side == side }) {
            let existing = positions[index]
            let newTotalShares = existing.shares + shares
            let newTotalInvested = existing.totalInvested + cost
            positions[index].shares = newTotalShares
            positions[index].avgCost = newTotalInvested / newTotalShares
            positions[index].totalInvested = newTotalInvested
        } else {
            let position = Position(
                marketId: marketId,
                side: side,
                shares: shares,
                avgCost: cost / shares,
                totalInvested: cost
            )
            positions.append(position)
        }
    }

    mutating func removeShares(marketId: UUID, side: TradeSide, shares: Double) -> Double {
        guard let index = positions.firstIndex(where: { $0.marketId == marketId && $0.side == side }) else { return 0 }
        let costBasis = positions[index].avgCost * shares
        positions[index].shares -= shares
        positions[index].totalInvested -= costBasis
        if positions[index].shares <= 0.001 {
            positions.remove(at: index)
        }
        return costBasis
    }
}
