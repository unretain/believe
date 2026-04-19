import Foundation

nonisolated struct LeveragedPosition: Identifiable, Codable, Sendable {
    let id: UUID
    let marketId: UUID
    let side: TradeSide
    let leverage: Double
    let collateral: Double
    let size: Double
    let entryPrice: Double
    let liquidationPrice: Double
    let openedAt: Date

    func markPrice(in market: Market) -> Double {
        side == .believe ? market.currentBelieve : market.currentDoubt
    }

    func unrealizedPnL(in market: Market) -> Double {
        let p = markPrice(in: market)
        guard entryPrice > 0 else { return 0 }
        return size * (p - entryPrice) / entryPrice
    }

    func unrealizedPnLPct(in market: Market) -> Double {
        guard collateral > 0 else { return 0 }
        return unrealizedPnL(in: market) / collateral * 100
    }

    func equity(in market: Market) -> Double {
        max(0, collateral + unrealizedPnL(in: market))
    }

    func distanceToLiquidation(in market: Market) -> Double {
        let p = markPrice(in: market)
        guard p > 0 else { return 0 }
        return (p - liquidationPrice) / p * 100
    }
}
