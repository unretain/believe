import Foundation

nonisolated enum TradeError: Error, Sendable {
    case insufficientBalance
    case insufficientShares
    case invalidAmount
    case marketNotFound
}

struct MarketEngine {
    static let feeRate: Double = 0.01

    static func buyShares(market: inout Market, side: TradeSide, amount: Double) -> (shares: Double, avgPrice: Double, fee: Double) {
        let fee = amount * feeRate
        let amountAfterFee = amount - fee
        let oldK = market.k

        switch side {
        case .believe:
            market.doubtPool += amountAfterFee
            let newBelievePool = oldK / market.doubtPool
            let sharesOut = market.believePool - newBelievePool
            market.believePool = newBelievePool
            let avgPrice = amount / sharesOut
            market.volume24h += amount
            market.totalVolume += amount
            market.recordPrice()
            return (sharesOut, avgPrice, fee)

        case .doubt:
            market.believePool += amountAfterFee
            let newDoubtPool = oldK / market.believePool
            let sharesOut = market.doubtPool - newDoubtPool
            market.doubtPool = newDoubtPool
            let avgPrice = amount / sharesOut
            market.volume24h += amount
            market.totalVolume += amount
            market.recordPrice()
            return (sharesOut, avgPrice, fee)
        }
    }

    static func sellShares(market: inout Market, side: TradeSide, shares: Double) -> (payout: Double, fee: Double) {
        let oldK = market.k

        switch side {
        case .believe:
            market.believePool += shares
            let newDoubtPool = oldK / market.believePool
            let grossPayout = market.doubtPool - newDoubtPool
            market.doubtPool = newDoubtPool
            let fee = grossPayout * feeRate
            let netPayout = grossPayout - fee
            market.volume24h += grossPayout
            market.totalVolume += grossPayout
            market.recordPrice()
            return (netPayout, fee)

        case .doubt:
            market.doubtPool += shares
            let newBelievePool = oldK / market.doubtPool
            let grossPayout = market.believePool - newBelievePool
            market.believePool = newBelievePool
            let fee = grossPayout * feeRate
            let netPayout = grossPayout - fee
            market.volume24h += grossPayout
            market.totalVolume += grossPayout
            market.recordPrice()
            return (netPayout, fee)
        }
    }

    static func estimateBuy(market: Market, side: TradeSide, amount: Double) -> (shares: Double, avgPrice: Double, priceImpact: Double, fee: Double) {
        guard amount > 0 else { return (0, 0, 0, 0) }
        let fee = amount * feeRate
        let amountAfterFee = amount - fee
        let oldK = market.k
        let oldPrice: Double

        switch side {
        case .believe:
            oldPrice = market.currentBelieve
            let newDoubtPool = market.doubtPool + amountAfterFee
            let newBelievePool = oldK / newDoubtPool
            let sharesOut = market.believePool - newBelievePool
            let avgPrice = amount / sharesOut
            let newPrice = newDoubtPool / (newBelievePool + newDoubtPool)
            let impact = ((newPrice - oldPrice) / oldPrice) * 100
            return (sharesOut, avgPrice, impact, fee)

        case .doubt:
            oldPrice = market.currentDoubt
            let newBelievePool = market.believePool + amountAfterFee
            let newDoubtPool = oldK / newBelievePool
            let sharesOut = market.doubtPool - newDoubtPool
            let avgPrice = amount / sharesOut
            let newPrice = newBelievePool / (newBelievePool + newDoubtPool)
            let impact = ((newPrice - oldPrice) / oldPrice) * 100
            return (sharesOut, avgPrice, impact, fee)
        }
    }

    static func estimateSell(market: Market, side: TradeSide, shares: Double) -> (payout: Double, avgPrice: Double, priceImpact: Double, fee: Double) {
        guard shares > 0 else { return (0, 0, 0, 0) }
        let oldK = market.k
        let oldPrice: Double

        switch side {
        case .believe:
            oldPrice = market.currentBelieve
            let newBelievePool = market.believePool + shares
            let newDoubtPool = oldK / newBelievePool
            let grossPayout = market.doubtPool - newDoubtPool
            let fee = grossPayout * feeRate
            let netPayout = grossPayout - fee
            let avgPrice = netPayout / shares
            let newPrice = newDoubtPool / (newBelievePool + newDoubtPool)
            let impact = ((newPrice - oldPrice) / oldPrice) * 100
            return (netPayout, avgPrice, impact, fee)

        case .doubt:
            oldPrice = market.currentDoubt
            let newDoubtPool = market.doubtPool + shares
            let newBelievePool = oldK / newDoubtPool
            let grossPayout = market.believePool - newBelievePool
            let fee = grossPayout * feeRate
            let netPayout = grossPayout - fee
            let avgPrice = netPayout / shares
            let newPrice = newBelievePool / (newBelievePool + newDoubtPool)
            let impact = ((newPrice - oldPrice) / oldPrice) * 100
            return (netPayout, avgPrice, impact, fee)
        }
    }
}
